using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace BajajDocumentProcessing.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "HQ")]
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
    /// Send a chat message
    /// </summary>
    [HttpPost("message")]
    public async Task<IActionResult> SendMessage(
        [FromBody] SendMessageRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());

            var response = await _chatService.ProcessQueryAsync(
                userId,
                request.Message,
                request.ConversationId,
                cancellationToken);

            return Ok(response);
        }
        catch (System.UnauthorizedAccessException ex)
        {
            _logger.LogWarning(ex, "Unauthorized chat query");
            return Forbid();
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning(ex, "Invalid chat query");
            return BadRequest(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending chat message");
            return StatusCode(500, new { error = "An error occurred while processing your message" });
        }
    }

    /// <summary>
    /// Get conversation history
    /// </summary>
    [HttpGet("history")]
    public async Task<IActionResult> GetHistory(
        [FromQuery] Guid? conversationId = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());

            if (!conversationId.HasValue)
            {
                return BadRequest(new { error = "Conversation ID is required" });
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

public record SendMessageRequest(Guid? ConversationId, string Message);
