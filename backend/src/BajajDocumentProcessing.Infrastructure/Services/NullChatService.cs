using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Null implementation of IChatService when Azure AI Search is not configured
/// </summary>
public class NullChatService : IChatService
{
    private readonly ILogger<NullChatService> _logger;

    public NullChatService(ILogger<NullChatService> logger)
    {
        _logger = logger;
        _logger.LogWarning("Azure OpenAI is not configured. Chat features are disabled.");
    }

    public Task<ChatResponse> ProcessQueryAsync(Guid userId, string query, Guid? conversationId = null, CancellationToken cancellationToken = default)
    {
        _logger.LogWarning("Chat service called but Azure OpenAI is not configured");
        throw new InvalidOperationException("Chat service is not available. Azure OpenAI must be configured to use chat features.");
    }

    public Task<List<ChatMessage>> GetConversationHistoryAsync(Guid conversationId, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Get conversation history skipped - Azure OpenAI not configured");
        return Task.FromResult(new List<ChatMessage>());
    }

    public Task ClearConversationAsync(Guid conversationId, CancellationToken cancellationToken = default)
    {
        _logger.LogDebug("Clear conversation skipped - Azure OpenAI not configured");
        return Task.CompletedTask;
    }
}
