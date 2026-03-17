using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Conversation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Controller for the conversational submission chatbot flow.
/// Processes chat actions, returns bot responses, and manages conversation state.
/// </summary>
[ApiController]
[Route("api/conversation")]
[Authorize]
public class ConversationalSubmissionController : ControllerBase
{
    private readonly IConversationalSubmissionService _conversationService;
    private readonly IApplicationDbContext _context;
    private readonly ILogger<ConversationalSubmissionController> _logger;

    public ConversationalSubmissionController(
        IConversationalSubmissionService conversationService,
        IApplicationDbContext context,
        ILogger<ConversationalSubmissionController> logger)
    {
        _conversationService = conversationService;
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Process a chat action and return the next bot response.
    /// Accepts user messages, button taps, and file upload confirmations.
    /// </summary>
    /// <param name="request">The conversation request containing the action and optional payload</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Structured bot response with message, buttons, cards, and progress</returns>
    [HttpPost("message")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(ConversationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ProcessMessage(
        [FromBody] ConversationRequest request,
        CancellationToken cancellationToken = default)
    {
        var (userId, agencyId) = await ResolveUserContextAsync(cancellationToken);
        if (userId == null || agencyId == null)
            return Forbid();

        try
        {
            var response = await _conversationService.ProcessMessageAsync(
                request, userId.Value, agencyId.Value, cancellationToken);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing conversation message for user {UserId}", userId);
            return StatusCode(500, new { error = "An error occurred while processing your message. Please try again." });
        }
    }

    /// <summary>
    /// Get the current conversation state for a submission.
    /// Returns current step, progress percent, and last completed step.
    /// </summary>
    /// <param name="submissionId">The submission identifier</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Current conversation state</returns>
    [HttpGet("{submissionId}/state")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(ConversationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetState(
        Guid submissionId,
        CancellationToken cancellationToken = default)
    {
        var (userId, agencyId) = await ResolveUserContextAsync(cancellationToken);
        if (userId == null || agencyId == null)
            return Forbid();

        // Verify the submission belongs to the user's agency
        var submission = await _context.DocumentPackages
            .AsNoTracking()
            .Where(dp => dp.Id == submissionId && !dp.IsDeleted && dp.AgencyId == agencyId.Value)
            .Select(dp => new { dp.Id })
            .FirstOrDefaultAsync(cancellationToken);

        if (submission == null)
            return NotFound(new { error = "Submission not found or you do not have access to it." });

        try
        {
            var response = await _conversationService.GetStateAsync(submissionId, cancellationToken);
            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting conversation state for submission {SubmissionId}", submissionId);
            return StatusCode(500, new { error = "An error occurred while retrieving the conversation state." });
        }
    }

    /// <summary>
    /// Resume a draft submission from the last completed step.
    /// Loads all previously entered data and returns the appropriate step response.
    /// </summary>
    /// <param name="submissionId">The submission identifier to resume</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Conversation response from the last completed step</returns>
    [HttpPost("{submissionId}/resume")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(ConversationResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Resume(
        Guid submissionId,
        CancellationToken cancellationToken = default)
    {
        var (userId, agencyId) = await ResolveUserContextAsync(cancellationToken);
        if (userId == null || agencyId == null)
            return Forbid();

        // Verify the submission belongs to the user's agency
        var submission = await _context.DocumentPackages
            .AsNoTracking()
            .Where(dp => dp.Id == submissionId && !dp.IsDeleted && dp.AgencyId == agencyId.Value)
            .Select(dp => new { dp.Id })
            .FirstOrDefaultAsync(cancellationToken);

        if (submission == null)
            return NotFound(new { error = "Submission not found or you do not have access to it." });

        try
        {
            var response = await _conversationService.ResumeAsync(
                submissionId, userId.Value, agencyId.Value, cancellationToken);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resuming conversation for submission {SubmissionId}", submissionId);
            return StatusCode(500, new { error = "An error occurred while resuming your submission." });
        }
    }

    /// <summary>
    /// Resolves the UserId and AgencyId for the current authenticated user from JWT claims.
    /// </summary>
    private async Task<(Guid? UserId, Guid? AgencyId)> ResolveUserContextAsync(CancellationToken cancellationToken)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("User ID claim not found or invalid in token");
            return (null, null);
        }

        var user = await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId && !u.IsDeleted)
            .Select(u => new { u.Id, u.AgencyId })
            .FirstOrDefaultAsync(cancellationToken);

        if (user?.AgencyId == null)
        {
            _logger.LogWarning("User {UserId} has no associated agency", userId);
            return (userId, null);
        }

        return (user.Id, user.AgencyId);
    }
}
