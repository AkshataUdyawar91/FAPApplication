using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Notifications controller for managing user notifications
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly INotificationAgent _notificationAgent;
    private readonly ILogger<NotificationsController> _logger;

    public NotificationsController(
        INotificationAgent notificationAgent,
        ILogger<NotificationsController> logger)
    {
        _notificationAgent = notificationAgent;
        _logger = logger;
    }

    /// <summary>
    /// Get notifications for the current user
    /// </summary>
    /// <param name="unreadOnly">If true, returns only unread notifications</param>
    [HttpGet]
    [ProducesResponseType(typeof(NotificationListResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetNotifications([FromQuery] bool unreadOnly = false)
    {
        try
        {
            // Get user ID from claims
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
            {
                return Unauthorized(new { message = "Invalid user" });
            }

            // Get notifications
            var notifications = await _notificationAgent.GetUserNotificationsAsync(
                userId,
                unreadOnly,
                HttpContext.RequestAborted);

            // Get unread count
            var unreadCount = await _notificationAgent.GetUnreadCountAsync(
                userId,
                HttpContext.RequestAborted);

            // Map to DTOs
            var notificationDtos = notifications.Select(n => new NotificationDto
            {
                Id = n.Id,
                UserId = n.UserId,
                Type = n.Type,
                Title = n.Title,
                Message = n.Message,
                IsRead = n.IsRead,
                RelatedEntityId = n.RelatedEntityId,
                CreatedAt = n.CreatedAt,
                ReadAt = n.ReadAt
            }).ToList();

            var response = new NotificationListResponse
            {
                Notifications = notificationDtos,
                UnreadCount = unreadCount
            };

            _logger.LogInformation(
                "Retrieved {Count} notifications for user {UserId}",
                notifications.Count,
                userId);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving notifications");
            return StatusCode(500, new { message = "An error occurred while retrieving notifications" });
        }
    }

    /// <summary>
    /// Get unread notification count for the current user
    /// </summary>
    [HttpGet("unread-count")]
    [ProducesResponseType(typeof(int), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetUnreadCount()
    {
        try
        {
            // Get user ID from claims
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
            {
                return Unauthorized(new { message = "Invalid user" });
            }

            var count = await _notificationAgent.GetUnreadCountAsync(
                userId,
                HttpContext.RequestAborted);

            return Ok(new { unreadCount = count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving unread count");
            return StatusCode(500, new { message = "An error occurred while retrieving unread count" });
        }
    }

    /// <summary>
    /// Mark a notification as read
    /// </summary>
    [HttpPatch("{id}/read")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> MarkAsRead(Guid id)
    {
        try
        {
            // Get user ID from claims
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
            {
                return Unauthorized(new { message = "Invalid user" });
            }

            await _notificationAgent.MarkAsReadAsync(id, HttpContext.RequestAborted);

            _logger.LogInformation(
                "Notification {NotificationId} marked as read by user {UserId}",
                id,
                userId);

            return Ok(new { message = "Notification marked as read" });
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "Notification {NotificationId} not found", id);
            return NotFound(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error marking notification {NotificationId} as read", id);
            return StatusCode(500, new { message = "An error occurred while marking notification as read" });
        }
    }
}
