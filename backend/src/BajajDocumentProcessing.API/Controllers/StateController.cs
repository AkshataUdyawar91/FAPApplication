using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Conversation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// State controller for dealer typeahead within a state.
/// Queries the StateMappings table for active dealers.
/// </summary>
[ApiController]
[Route("api/state")]
[Authorize]
public class StateController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<StateController> _logger;

    public StateController(
        IApplicationDbContext context,
        ILogger<StateController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Dealer typeahead search within a state.
    /// Returns matching dealers from the StateMappings table filtered by state and partial dealer name/code.
    /// </summary>
    /// <param name="state">State to filter dealers by (required)</param>
    /// <param name="q">Partial dealer name or code for LIKE search</param>
    /// <param name="size">Maximum number of results to return (default 10, max 50)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of matching dealers</returns>
    [HttpGet("dealers")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(List<DealerResult>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> SearchDealers(
        [FromQuery] string? state,
        [FromQuery] string? q,
        [FromQuery] int size = 10,
        CancellationToken cancellationToken = default)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(state))
                return BadRequest(new { error = "The 'state' query parameter is required." });

            var agencyId = await GetCurrentUserAgencyIdAsync(cancellationToken);
            if (agencyId == null)
                return Forbid();

            size = Math.Clamp(size, 1, 50);

            var query = _context.StateMappings
                .Where(sm => sm.IsActive && !sm.IsDeleted && sm.State == state)
                .AsQueryable();

            // LIKE search on DealerName or DealerCode
            if (!string.IsNullOrWhiteSpace(q))
            {
                query = query.Where(sm =>
                    sm.DealerName.Contains(q) || sm.DealerCode.Contains(q));
            }

            var results = await query
                .OrderBy(sm => sm.DealerName)
                .Take(size)
                .Select(sm => new DealerResult
                {
                    DealerCode = sm.DealerCode,
                    DealerName = sm.DealerName,
                    City = sm.City ?? string.Empty,
                    State = sm.State
                })
                .ToListAsync(cancellationToken);

            if (results.Count == 0)
            {
                return Ok(new
                {
                    items = Array.Empty<DealerResult>(),
                    message = BuildZeroResultsMessage(state, q)
                });
            }

            return Ok(results);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching dealers for state {State}", state);
            return StatusCode(500, new { error = "An error occurred while searching dealers" });
        }
    }

    /// <summary>
    /// Resolves the AgencyId for the current authenticated user.
    /// </summary>
    private async Task<Guid?> GetCurrentUserAgencyIdAsync(CancellationToken cancellationToken)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("User ID claim not found or invalid in token");
            return null;
        }

        var user = await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId && !u.IsDeleted)
            .Select(u => new { u.AgencyId })
            .FirstOrDefaultAsync(cancellationToken);

        if (user?.AgencyId == null)
        {
            _logger.LogWarning("User {UserId} has no associated agency", userId);
            return null;
        }

        return user.AgencyId;
    }

    /// <summary>
    /// Builds a descriptive message when dealer search returns zero results.
    /// </summary>
    private static string BuildZeroResultsMessage(string state, string? searchTerm)
    {
        if (!string.IsNullOrWhiteSpace(searchTerm))
        {
            return $"No dealers found matching \"{searchTerm}\" in {state}. "
                   + "Try a different search term, or enter the dealer details manually.";
        }

        return $"No dealers found in {state}. "
               + "The dealer list may not be configured for this state yet. You can enter dealer details manually.";
    }
}
