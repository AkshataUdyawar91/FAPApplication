using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for conversational AI chat with semantic search over analytics data
/// </summary>
public interface IChatService
{
    /// <summary>
    /// Processes a user query and generates a response with data citations
    /// </summary>
    /// <param name="userId">User's unique identifier</param>
    /// <param name="query">User's natural language query</param>
    /// <param name="conversationId">Optional conversation ID to continue an existing conversation</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Chat response with AI-generated message and data citations</returns>
    Task<ChatResponse> ProcessQueryAsync(Guid userId, string query, Guid? conversationId = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves the message history for a conversation
    /// </summary>
    /// <param name="conversationId">Conversation's unique identifier</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>List of chat messages in chronological order</returns>
    Task<List<ChatMessage>> GetConversationHistoryAsync(Guid conversationId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a conversation by ID
    /// </summary>
    /// <param name="conversationId">Conversation's unique identifier</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Conversation entity or null if not found</returns>
    Task<Conversation?> GetConversationAsync(Guid conversationId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Clears all messages from a conversation
    /// </summary>
    /// <param name="conversationId">Conversation's unique identifier</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async operation</returns>
    Task ClearConversationAsync(Guid conversationId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Response from the chat service containing AI-generated message and citations
/// </summary>
public class ChatResponse
{
    /// <summary>
    /// AI-generated response message
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// List of data citations supporting the response
    /// </summary>
    public List<DataCitation> Citations { get; set; } = new();

    /// <summary>
    /// Conversation ID for this exchange
    /// </summary>
    public Guid ConversationId { get; set; }
}

/// <summary>
/// Individual chat message in a conversation
/// </summary>
public class ChatMessage
{
    /// <summary>
    /// Message's unique identifier
    /// </summary>
    public Guid Id { get; set; }

    /// <summary>
    /// Conversation ID this message belongs to
    /// </summary>
    public Guid ConversationId { get; set; }

    /// <summary>
    /// Role of the message sender ("user" or "assistant")
    /// </summary>
    public string Role { get; set; } = string.Empty;

    /// <summary>
    /// Message content
    /// </summary>
    public string Content { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when the message was created
    /// </summary>
    public DateTime CreatedAt { get; set; }
}

/// <summary>
/// Data citation linking AI response to source analytics data
/// </summary>
public class DataCitation
{
    /// <summary>
    /// Source description (e.g., "Maharashtra submissions Q1 2024")
    /// </summary>
    public string Source { get; set; } = string.Empty;

    /// <summary>
    /// Time range of the cited data
    /// </summary>
    public string TimeRange { get; set; } = string.Empty;

    /// <summary>
    /// Key metrics from the cited data
    /// </summary>
    public Dictionary<string, object> Metrics { get; set; } = new();
}
