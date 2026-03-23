using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Bot.Builder;
using Newtonsoft.Json.Linq;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams.Models;

namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams;

/// <summary>
/// Resolves a Teams AAD Object ID to a ClaimsIQ User with role and assigned states.
/// Used to scope all conversational AI queries to the approver's jurisdiction.
/// Supports 3-tier resolution: SSO token → AAD Object ID → Conversation FK.
/// </summary>
public class ApproverResolver
{
    private readonly ApplicationDbContext _dbContext;
    private readonly ILogger<ApproverResolver> _logger;
    private readonly IHostEnvironment _environment;
    private readonly IConfiguration _configuration;

    public ApproverResolver(
        ApplicationDbContext dbContext,
        ILogger<ApproverResolver> logger,
        IHostEnvironment environment,
        IConfiguration configuration)
    {
        _dbContext = dbContext;
        _logger = logger;
        _environment = environment;
        _configuration = configuration;
    }

    /// <summary>
    /// Tier 2: Resolves the AAD Object ID to a ClaimsIQ approver (ASM or RA) with assigned states.
    /// First attempts direct User lookup by AadObjectId, then falls back to TeamsConversation by TeamsUserId.
    /// Returns null if the user cannot be resolved or is not an approver role.
    /// </summary>
    public async Task<ApproverResolvedUser?> ResolveAsync(string aadObjectId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(aadObjectId))
        {
            _logger.LogDebug("ApproverResolver: Empty AAD Object ID — credential login required");
            return null;
        }

        // Step 1: Try direct User lookup by AadObjectId
        var user = await _dbContext.Users
            .AsNoTracking()
            .Where(u => u.AadObjectId == aadObjectId && u.IsActive)
            .Select(u => new { u.Id, u.FullName, u.Role })
            .FirstOrDefaultAsync(ct);

        // Step 2: Fallback to TeamsConversation lookup by TeamsUserId
        if (user == null)
        {
            _logger.LogDebug("User not found by AadObjectId {AadObjectId}, falling back to TeamsConversation lookup", aadObjectId);

            var teamsUser = await _dbContext.TeamsConversations
                .AsNoTracking()
                .Where(tc => tc.TeamsUserId == aadObjectId && tc.IsActive && tc.UserId != null)
                .Select(tc => new { tc.UserId, tc.User!.FullName, tc.User.Role, tc.User.IsActive })
                .FirstOrDefaultAsync(ct);

            if (teamsUser == null || !teamsUser.IsActive)
            {
                _logger.LogInformation("Could not resolve Teams user with AAD Object ID {AadObjectId}", aadObjectId);
                return null;
            }

            user = new { Id = teamsUser.UserId!.Value, teamsUser.FullName, teamsUser.Role };
        }

        // Step 3: Verify the user is an approver role (ASM or RA)
        if (user.Role != UserRole.ASM && user.Role != UserRole.RA)
        {
            _logger.LogInformation("Resolved user {UserId} has role {Role}, not an approver", user.Id, user.Role);
            return null;
        }

        // Step 4: Load assigned states based on role
        var assignedStates = await LoadAssignedStatesAsync(user.Id, user.Role, ct);
        var roleName = user.Role == UserRole.ASM ? "ASM" : "RA";

        _logger.LogInformation(
            "Resolved approver {UserId} as {Role} with {StateCount} assigned state(s)",
            user.Id, roleName, assignedStates.Length);

        return new ApproverResolvedUser
        {
            UserId = user.Id,
            Role = roleName,
            DisplayName = user.FullName,
            AssignedStates = assignedStates
        };
    }

    /// <summary>
    /// Tier 1: Attempts to resolve the approver via Teams SSO token.
    /// Teams sends an SSO token when webApplicationInfo is configured in the bot manifest.
    /// Extracts email/oid claims from the JWT and matches to a system user.
    /// Auto-populates AadObjectId if matched by email but OID not yet stored.
    /// Returns null if SSO is not configured, token is absent, or no user match.
    /// </summary>
    public async Task<ApproverResolvedUser?> ResolveBySsoTokenAsync(
        ITurnContext turnContext, CancellationToken ct = default)
    {
        try
        {
            // Teams SSO token can appear in Activity.Value or ChannelData
            var ssoToken = (turnContext.Activity?.Value as JObject)?["token"]?.ToString();
            if (string.IsNullOrEmpty(ssoToken))
            {
                ssoToken = (turnContext.Activity?.ChannelData as JObject)?["ssoToken"]?.ToString();
            }

            if (string.IsNullOrEmpty(ssoToken))
            {
                _logger.LogDebug("ResolveBySsoTokenAsync: No SSO token present in activity");
                return null;
            }

            // Decode JWT claims (Bot Framework already validated the token)
            var claims = DecodeJwtClaims(ssoToken);
            if (claims == null)
            {
                _logger.LogDebug("ResolveBySsoTokenAsync: Failed to decode SSO token claims");
                return null;
            }

            var email = claims.GetValueOrDefault("preferred_username")
                        ?? claims.GetValueOrDefault("upn")
                        ?? claims.GetValueOrDefault("email");
            var oid = claims.GetValueOrDefault("oid");

            if (string.IsNullOrEmpty(email) && string.IsNullOrEmpty(oid))
            {
                _logger.LogDebug("ResolveBySsoTokenAsync: Token has no email or oid claim");
                return null;
            }

            // Try matching by OID first (most reliable), then by email
            Domain.Entities.User? user = null;
            if (!string.IsNullOrEmpty(oid))
            {
                user = await _dbContext.Users
                    .FirstOrDefaultAsync(u => u.AadObjectId == oid && u.IsActive && !u.IsDeleted, ct);
            }

            if (user == null && !string.IsNullOrEmpty(email))
            {
                user = await _dbContext.Users
                    .FirstOrDefaultAsync(
                        u => u.Email.ToLower() == email.ToLower() && u.IsActive && !u.IsDeleted, ct);

                // Auto-populate AadObjectId for future Tier 2 resolution
                if (user != null && string.IsNullOrEmpty(user.AadObjectId) && !string.IsNullOrEmpty(oid))
                {
                    user.AadObjectId = oid;
                    user.UpdatedAt = DateTime.UtcNow;
                    await _dbContext.SaveChangesAsync(ct);
                    _logger.LogInformation(
                        "SSO: Auto-populated AadObjectId {Oid} for user {Email}",
                        oid, user.Email);
                }
            }

            if (user == null)
            {
                _logger.LogDebug("ResolveBySsoTokenAsync: No user matched SSO claims (oid={Oid}, email={Email})", oid, email);
                return null;
            }

            // Verify approver role
            if (user.Role != UserRole.ASM && user.Role != UserRole.RA)
            {
                _logger.LogInformation("SSO: User {UserId} has role {Role}, not an approver", user.Id, user.Role);
                return null;
            }

            var assignedStates = await LoadAssignedStatesAsync(user.Id, user.Role, ct);
            var roleName = user.Role == UserRole.ASM ? "ASM" : "RA";

            _logger.LogInformation(
                "SSO: Resolved approver {UserId} as {Role} with {StateCount} state(s)",
                user.Id, roleName, assignedStates.Length);

            // Also auto-populate AadObjectId from activity if not set
            var activityAadOid = turnContext.Activity?.From?.AadObjectId;
            if (!string.IsNullOrEmpty(activityAadOid) && string.IsNullOrEmpty(user.AadObjectId))
            {
                user.AadObjectId = activityAadOid;
                user.UpdatedAt = DateTime.UtcNow;
                await _dbContext.SaveChangesAsync(ct);
            }

            return new ApproverResolvedUser
            {
                UserId = user.Id,
                Role = roleName,
                DisplayName = user.FullName,
                AssignedStates = assignedStates
            };
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "ResolveBySsoTokenAsync: Failed — falling through to next tier");
            return null;
        }
    }

    /// <summary>
    /// Resolves a user by email and password credentials (Tier 3 fallback).
    /// Validates BCrypt password hash, verifies approver role, and loads assigned states.
    /// Returns null if credentials are invalid or user is not an approver.
    /// </summary>
    public async Task<ApproverResolvedUser?> ResolveByCredentialsAsync(
        string email, string password, CancellationToken ct = default)
    {
        var user = await _dbContext.Users
            .Where(u => u.Email == email && u.IsActive)
            .Select(u => new { u.Id, u.FullName, u.Role, u.PasswordHash })
            .FirstOrDefaultAsync(ct);

        if (user == null)
        {
            _logger.LogInformation("Credential login failed: user not found for email");
            return null;
        }

        // Verify password using BCrypt
        try
        {
            if (!BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
            {
                _logger.LogInformation("Credential login failed: invalid password for user {UserId}", user.Id);
                return null;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "BCrypt verification error during credential login");
            return null;
        }

        // Verify approver role
        if (user.Role != UserRole.ASM && user.Role != UserRole.RA)
        {
            _logger.LogInformation("Credential login: user {UserId} has role {Role}, not an approver", user.Id, user.Role);
            return null;
        }

        var assignedStates = await LoadAssignedStatesAsync(user.Id, user.Role, ct);
        var roleName = user.Role == UserRole.ASM ? "ASM" : "RA";

        _logger.LogInformation(
            "Credential login successful: {UserId} as {Role} with {StateCount} state(s)",
            user.Id, roleName, assignedStates.Length);

        return new ApproverResolvedUser
        {
            UserId = user.Id,
            Role = roleName,
            DisplayName = user.FullName,
            AssignedStates = assignedStates
        };
    }

    /// <summary>
    /// Loads the states assigned to an approver from StateMapping.
    /// ASM: states where CircleHeadUserId matches. RA: states where RAUserId matches.
    /// </summary>
    private async Task<string[]> LoadAssignedStatesAsync(Guid userId, UserRole role, CancellationToken ct)
    {
        var query = _dbContext.StateMappings
            .AsNoTracking()
            .Where(sm => sm.IsActive);

        if (role == UserRole.ASM)
        {
            query = query.Where(sm => sm.CircleHeadUserId == userId);
        }
        else
        {
            query = query.Where(sm => sm.RAUserId == userId);
        }

        var states = await query
            .Select(sm => sm.State)
            .Distinct()
            .ToArrayAsync(ct);

        return states;
    }

    /// <summary>
    /// Decodes JWT claims from a token without signature validation.
    /// The Bot Framework has already validated the token — we just need the claims.
    /// </summary>
    private static Dictionary<string, string>? DecodeJwtClaims(string token)
    {
        try
        {
            var parts = token.Split('.');
            if (parts.Length < 2) return null;

            var payload = parts[1];
            switch (payload.Length % 4)
            {
                case 2: payload += "=="; break;
                case 3: payload += "="; break;
            }

            var bytes = Convert.FromBase64String(
                payload.Replace('-', '+').Replace('_', '/'));
            var json = System.Text.Encoding.UTF8.GetString(bytes);

            using var doc = System.Text.Json.JsonDocument.Parse(json);
            var claims = new Dictionary<string, string>();
            foreach (var prop in doc.RootElement.EnumerateObject())
            {
                claims[prop.Name] = prop.Value.ToString();
            }
            return claims;
        }
        catch
        {
            return null;
        }
    }
}
