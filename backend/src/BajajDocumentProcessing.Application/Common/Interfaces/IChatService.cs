namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IChatService
{
    Task<ChatResponse> ProcessQueryAsync(Guid userId, string query, Guid? conversationId = null, CancellationToken cancellationToken = default);
    Task<List<ChatMessage>> GetConversationHistoryAsync(Guid conversationId, CancellationToken cancellationToken = default);
    Task ClearConversationAsync(Guid conversationId, CancellationToken cancellationToken = default);
}

public class ChatResponse
{
    public string Message { get; set; } = string.Empty;
    public List<DataCitation> Citations { get; set; } = new();
    public Guid ConversationId { get; set; }
}

public class ChatMessage
{
    public Guid Id { get; set; }
    public Guid ConversationId { get; set; }
    public string Role { get; set; } = string.Empty; // "user" or "assistant"
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class DataCitation
{
    public string Source { get; set; } = string.Empty;
    public string TimeRange { get; set; } = string.Empty;
    public Dictionary<string, object> Metrics { get; set; } = new();
}
