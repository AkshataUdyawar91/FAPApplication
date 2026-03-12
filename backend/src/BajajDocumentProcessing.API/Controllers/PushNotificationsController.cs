using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Controller for push notification management: device tokens, preferences, and history
/// </summary>
[ApiController]
[Route("api/notifications")]
[Authorize]
public class PushNotificationsController : ControllerBase
{
    private readonly IDeviceTokenService _deviceTokenService;
    private readonly INotificationPreferenceService _preferenceService;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICorrelationIdService _correlationIdService;
    private readonly ILogger<PushNotificationsController> _logger;

    /// <summary>
    /// Initializes a new instance of the PushNotificationsController
    /// </summary>
    public PushNotificationsController(
        IDeviceTokenService deviceTokenService,
        INotificationPreferenceService preferenceService,
        IApplicationDbContext dbContext,
        ICorrelationIdService correlationIdService,
        ILogger<PushNotificationsController> logger)
    {
        _deviceTokenService = deviceTokenService;
        _preferenceService = preferenceService;
        _dbContext = dbContext;
        _correlationIdService = correlationIdService;
        _logger = logger;
    }

    // ──────────────────────────────────────────────
    // Device Token Endpoints (Task 4.2)
    // ──────────────────────────────────────────────

    /// <summary>
    /// Register a device token for push notifications
    /// </summary>
    /// <param name="request">Device token and platform information</param>
    /// <returns>Registered device token details</returns>
    /// <response code="201">Device token registered successfully</response>
    /// <response code="400">Invalid request (validation errors)</response>
    /// <response code="401">Unauthorized - authentication required</response>
    [HttpPost("device-tokens")]
    [ProducesResponseType(typeof(DeviceTokenResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> RegisterDeviceTokenAsync(
        [FromBody] RegisterDeviceTokenRequest request)
    {
        var correlationId = _correlationIdService.GetCorrelationId();

        if (!TryGetUserId(out var userId))
        {
            return Unauthorized(new { message = "Invalid user", correlationId });
        }

        try
        {
            _logger.LogInformation(
                "Registering device token for user {UserId}, platform {Platform}, correlationId {CorrelationId}",
                userId, request.Platform, correlationId);

            var response = await _deviceTokenService.RegisterAsync(
                userId, request, HttpContext.RequestAborted);

            _logger.LogInformation(
                "Device token {DeviceTokenId} registered for user {UserId}, platform {Platform}, correlationId {CorrelationId}",
                response.Id, userId, request.Platform, correlationId);

            return StatusCode(StatusCodes.Status201Created, response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error registering device token for user {UserId}, correlationId {CorrelationId}",
                userId, correlationId);

            return StatusCode(500, new { message = "An error occurred while registering device token", correlationId });
        }
    }

    /// <summary>
    /// Deregister a device token (e.g., on logout)
    /// </summary>
    /// <param name="id">Device token identifier</param>
    /// <returns>No content on success</returns>
    /// <response code="204">Device token deregistered successfully</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="404">Device token not found</response>
    [HttpDelete("device-tokens/{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeregisterDeviceTokenAsync([FromRoute] Guid id)
    {
        var correlationId = _correlationIdService.GetCorrelationId();

        if (!TryGetUserId(out var userId))
        {
            return Unauthorized(new { message = "Invalid user", correlationId });
        }

        try
        {
            _logger.LogInformation(
                "Deregistering device token {DeviceTokenId} for user {UserId}, correlationId {CorrelationId}",
                id, userId, correlationId);

            await _deviceTokenService.DeregisterAsync(
                userId, id, HttpContext.RequestAborted);

            _logger.LogInformation(
                "Device token {DeviceTokenId} deregistered for user {UserId}, correlationId {CorrelationId}",
                id, userId, correlationId);

            return NoContent();
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex,
                "Device token {DeviceTokenId} not found for user {UserId}, correlationId {CorrelationId}",
                id, userId, correlationId);

            return NotFound(new { message = "Device token not found", correlationId });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error deregistering device token {DeviceTokenId} for user {UserId}, correlationId {CorrelationId}",
                id, userId, correlationId);

            return StatusCode(500, new { message = "An error occurred while deregistering device token", correlationId });
        }
    }

    // ──────────────────────────────────────────────
    // Preference Endpoints (Task 4.3)
    // ──────────────────────────────────────────────

    /// <summary>
    /// Get notification preferences for the current user
    /// </summary>
    /// <returns>User's notification preferences</returns>
    /// <response code="200">Returns notification preferences</response>
    /// <response code="401">Unauthorized - authentication required</response>
    [HttpGet("preferences")]
    [ProducesResponseType(typeof(NotificationPreferenceResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetPreferencesAsync()
    {
        var correlationId = _correlationIdService.GetCorrelationId();

        if (!TryGetUserId(out var userId))
        {
            return Unauthorized(new { message = "Invalid user", correlationId });
        }

        try
        {
            _logger.LogInformation(
                "Retrieving notification preferences for user {UserId}, correlationId {CorrelationId}",
                userId, correlationId);

            var response = await _preferenceService.GetPreferencesAsync(
                userId, HttpContext.RequestAborted);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error retrieving notification preferences for user {UserId}, correlationId {CorrelationId}",
                userId, correlationId);

            return StatusCode(500, new { message = "An error occurred while retrieving preferences", correlationId });
        }
    }

    /// <summary>
    /// Update notification preferences for the current user
    /// </summary>
    /// <param name="request">Preference update details</param>
    /// <returns>Updated notification preferences</returns>
    /// <response code="200">Preferences updated successfully</response>
    /// <response code="400">Invalid request (validation errors)</response>
    /// <response code="401">Unauthorized - authentication required</response>
    [HttpPut("preferences")]
    [ProducesResponseType(typeof(NotificationPreferenceResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UpdatePreferencesAsync(
        [FromBody] UpdateNotificationPreferenceRequest request)
    {
        var correlationId = _correlationIdService.GetCorrelationId();

        if (!TryGetUserId(out var userId))
        {
            return Unauthorized(new { message = "Invalid user", correlationId });
        }

        try
        {
            _logger.LogInformation(
                "Updating notification preferences for user {UserId}, type {NotificationType}, correlationId {CorrelationId}",
                userId, request.NotificationType, correlationId);

            await _preferenceService.UpdatePreferencesAsync(
                userId, request, HttpContext.RequestAborted);

            // Return the full updated preferences
            var response = await _preferenceService.GetPreferencesAsync(
                userId, HttpContext.RequestAborted);

            _logger.LogInformation(
                "Notification preferences updated for user {UserId}, type {NotificationType}, correlationId {CorrelationId}",
                userId, request.NotificationType, correlationId);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error updating notification preferences for user {UserId}, correlationId {CorrelationId}",
                userId, correlationId);

            return StatusCode(500, new { message = "An error occurred while updating preferences", correlationId });
        }
    }

    // ──────────────────────────────────────────────
    // History Endpoint (Task 4.4)
    // ──────────────────────────────────────────────

    /// <summary>
    /// Get notification history for the current user with filtering and pagination
    /// </summary>
    /// <param name="notificationType">Filter by notification type (optional)</param>
    /// <param name="startDate">Filter by start date (optional)</param>
    /// <param name="endDate">Filter by end date (optional)</param>
    /// <param name="status">Filter by delivery status (optional)</param>
    /// <param name="pageNumber">Page number (default: 1)</param>
    /// <param name="pageSize">Page size (default: 20, max: 100)</param>
    /// <returns>Paginated notification history</returns>
    /// <response code="200">Returns paginated notification history</response>
    /// <response code="400">Invalid query parameters</response>
    /// <response code="401">Unauthorized - authentication required</response>
    [HttpGet("history")]
    [ProducesResponseType(typeof(NotificationHistoryResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetNotificationHistoryAsync(
        [FromQuery] string? notificationType = null,
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        [FromQuery] string? status = null,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 20)
    {
        var correlationId = _correlationIdService.GetCorrelationId();

        if (!TryGetUserId(out var userId))
        {
            return Unauthorized(new { message = "Invalid user", correlationId });
        }

        // Validate pagination parameters
        if (pageNumber < 1)
        {
            return BadRequest(new { message = "Page number must be at least 1", correlationId });
        }

        if (pageSize < 1 || pageSize > 100)
        {
            return BadRequest(new { message = "Page size must be between 1 and 100", correlationId });
        }

        try
        {
            _logger.LogInformation(
                "Retrieving notification history for user {UserId}, page {PageNumber}, correlationId {CorrelationId}",
                userId, pageNumber, correlationId);

            // Build query with filters
            var query = _dbContext.NotificationLogs
                .AsNoTracking()
                .Where(n => n.UserId == userId && !n.IsDeleted);

            if (!string.IsNullOrWhiteSpace(notificationType))
            {
                query = query.Where(n => n.NotificationType == notificationType);
            }

            if (startDate.HasValue)
            {
                query = query.Where(n => n.SentAt >= startDate.Value);
            }

            if (endDate.HasValue)
            {
                query = query.Where(n => n.SentAt <= endDate.Value);
            }

            if (!string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(n => n.Status == status);
            }

            // Get total count for pagination
            var totalCount = await query.CountAsync(HttpContext.RequestAborted);

            // Get paginated results ordered by most recent first
            var items = await query
                .OrderByDescending(n => n.SentAt)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .Select(n => new NotificationHistoryItem(
                    n.Id,
                    n.UserId,
                    n.NotificationType,
                    n.Channel,
                    n.Platform,
                    n.Status,
                    n.ErrorMessage,
                    n.SentAt,
                    n.CorrelationId
                ))
                .ToListAsync(HttpContext.RequestAborted);

            var response = new NotificationHistoryResponse(items, totalCount, pageNumber, pageSize);

            _logger.LogInformation(
                "Retrieved {Count} notification history items (total: {TotalCount}) for user {UserId}, correlationId {CorrelationId}",
                items.Count, totalCount, userId, correlationId);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error retrieving notification history for user {UserId}, correlationId {CorrelationId}",
                userId, correlationId);

            return StatusCode(500, new { message = "An error occurred while retrieving notification history", correlationId });
        }
    }

    // ──────────────────────────────────────────────
    // Helper Methods (Task 4.5)
    // ──────────────────────────────────────────────

    /// <summary>
    /// Extracts and validates the user ID from JWT claims
    /// </summary>
    /// <param name="userId">The parsed user ID if successful</param>
    /// <returns>True if a valid user ID was extracted, false otherwise</returns>
    private bool TryGetUserId(out Guid userId)
    {
        userId = Guid.Empty;
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out userId))
        {
            return false;
        }

        return true;
    }
}
