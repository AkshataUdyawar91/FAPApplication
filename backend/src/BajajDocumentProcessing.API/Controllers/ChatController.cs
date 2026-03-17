using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Chat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Chat controller for conversational AI assistant with semantic search over analytics data
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize] // Changed from [Authorize(Roles = "HQ")] to allow all authenticated users
public class ChatController : ControllerBase
{
    private readonly IChatService _chatService;
    private readonly ILogger<ChatController> _logger;

    public ChatController(
        IChatService chatService,
        ILogger<ChatController> logger)
    {
        _chatService = chatService;
        _logger = logger;
    }

    /// <summary>
    /// Send a chat message and receive AI-generated response with data citations
    /// </summary>
    /// <param name="request">Chat message request containing message text and optional conversation ID</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>AI response with message text and data citations from analytics</returns>
    /// <response code="200">Returns AI response with citations</response>
    /// <response code="400">Bad request - invalid query format</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - user not authorized for this query</response>
    /// <response code="503">Service unavailable - Azure OpenAI not configured</response>
    [HttpPost("message")]
    public async Task<IActionResult> SendMessage(
        [FromBody] SendMessageRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Try both claim types for compatibility
            var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
            {
                _logger.LogWarning("User ID claim not found in token");
                return Unauthorized(new { error = "User ID not found in token" });
            }
            

            var userId = Guid.Parse(userIdClaim);

            var response = await _chatService.ProcessQueryAsync(
                userId,
                request.Message,
                request.ConversationId,
                cancellationToken);

            // Map service response to API DTO
            var chatMessageResponse = new ChatMessageResponse
            {
                MessageId = Guid.NewGuid(), // Generate new message ID
                ConversationId = response.ConversationId,
                Message = response.Message,
                Citations = response.Citations.Select(c => new DataCitationDto
                {
                    Source = c.Source,
                    TimeRange = string.IsNullOrEmpty(c.TimeRange) ? null : c.TimeRange,
                    DataPoint = c.Metrics.Keys.FirstOrDefault() ?? "N/A",
                    Value = c.Metrics.Values.FirstOrDefault()?.ToString() ?? "N/A"
                }).ToList(),
                Timestamp = DateTime.UtcNow,
                IsAuthorized = true,
                ErrorMessage = null
            };

            return Ok(chatMessageResponse);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("not available"))
        {
            _logger.LogWarning("Chat service not available: {Message}", ex.Message);
            
            var errorResponse = new ChatMessageResponse
            {
                MessageId = Guid.NewGuid(),
                ConversationId = request.ConversationId ?? Guid.Empty,
                Message = string.Empty,
                Citations = new List<DataCitationDto>(),
                Timestamp = DateTime.UtcNow,
                IsAuthorized = false,
                ErrorMessage = "Chat service is not available. Azure OpenAI must be configured to use this feature."
            };
            
            return StatusCode(503, errorResponse);
        }
        catch (System.UnauthorizedAccessException ex)
        {
            _logger.LogWarning(ex, "Unauthorized chat query");
            
            var errorResponse = new ChatMessageResponse
            {
                MessageId = Guid.NewGuid(),
                ConversationId = request.ConversationId ?? Guid.Empty,
                Message = string.Empty,
                Citations = new List<DataCitationDto>(),
                Timestamp = DateTime.UtcNow,
                IsAuthorized = false,
                ErrorMessage = "You are not authorized to perform this query."
            };
            
            return StatusCode(403, errorResponse);
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning(ex, "Invalid chat query");
            
            var errorResponse = new ChatMessageResponse
            {
                MessageId = Guid.NewGuid(),
                ConversationId = request.ConversationId ?? Guid.Empty,
                Message = string.Empty,
                Citations = new List<DataCitationDto>(),
                Timestamp = DateTime.UtcNow,
                IsAuthorized = false,
                ErrorMessage = "Invalid query format"
            };
            
            return BadRequest(errorResponse);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending chat message");
            
            var errorResponse = new ChatMessageResponse
            {
                MessageId = Guid.NewGuid(),
                ConversationId = request.ConversationId ?? Guid.Empty,
                Message = string.Empty,
                Citations = new List<DataCitationDto>(),
                Timestamp = DateTime.UtcNow,
                IsAuthorized = false,
                ErrorMessage = "An error occurred while processing your message"
            };
            
            return StatusCode(500, errorResponse);
        }
    }

    /// <summary>
    /// Get conversation history for a specific conversation
    /// </summary>
    /// <param name="conversationId">Unique identifier of the conversation</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of messages in the conversation</returns>
    /// <response code="200">Returns conversation history</response>
    /// <response code="400">Bad request - conversation ID is required</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - user does not own this conversation</response>
    /// <response code="404">Not found - conversation does not exist</response>
    [HttpGet("history")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetHistory(
        [FromQuery] Guid? conversationId = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Try both claim types for compatibility
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
            {
                _logger.LogWarning("User ID claim not found in token");
                return Unauthorized(new { error = "User ID not found in token" });
            }

            var userId = Guid.Parse(userIdClaim);

            if (!conversationId.HasValue)
            {
                return BadRequest(new { error = "Conversation ID is required" });
            }

            // Verify resource ownership - get the conversation first
            var conversation = await _chatService.GetConversationAsync(conversationId.Value, cancellationToken);
            
            if (conversation == null)
            {
                return NotFound(new { error = "Conversation not found" });
            }

            // Verify the conversation belongs to the current user
            if (conversation.UserId != userId)
            {
                _logger.LogWarning(
                    "User {UserId} attempted to access conversation {ConversationId} owned by {OwnerId}",
                    userId, conversationId.Value, conversation.UserId);
                return StatusCode(403, new { error = "You do not have permission to access this conversation" });
            }

            var history = await _chatService.GetConversationHistoryAsync(
                conversationId.Value,
                cancellationToken);

            return Ok(history);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting conversation history");
            return StatusCode(500, new { error = "An error occurred while retrieving conversation history" });
        }
    }
}

/// <summary>
/// Request to send a chat message
/// </summary>
/// <param name="ConversationId">Optional conversation ID to continue existing conversation</param>
/// <param name="Message">Chat message text</param>
public record SendMessageRequest(Guid? ConversationId, string Message);
