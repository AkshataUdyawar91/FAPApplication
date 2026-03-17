using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// Structured bot response returned to the chat UI after processing a conversation action
/// </summary>
public class ConversationResponse
{
    /// <summary>
    /// Submission identifier (created on first action, reused thereafter)
    /// </summary>
    [JsonPropertyName("submissionId")]
    public required Guid SubmissionId { get; init; }

    /// <summary>
    /// Current step in the conversational flow (0-10)
    /// </summary>
    [JsonPropertyName("currentStep")]
    public required int CurrentStep { get; init; }

    /// <summary>
    /// Bot message text displayed in the chat bubble
    /// </summary>
    [JsonPropertyName("botMessage")]
    public required string BotMessage { get; init; }

    /// <summary>
    /// Action buttons rendered below the bot message
    /// </summary>
    [JsonPropertyName("buttons")]
    public required List<ActionButton> Buttons { get; init; }

    /// <summary>
    /// Optional rich card data (PO list, validation results, summary, etc.)
    /// </summary>
    [JsonPropertyName("card")]
    public CardData? Card { get; init; }

    /// <summary>
    /// Whether the current step requires a file upload
    /// </summary>
    [JsonPropertyName("requiresFileUpload")]
    public required bool RequiresFileUpload { get; init; }

    /// <summary>
    /// Document type expected for upload (e.g. "Invoice", "CostSummary")
    /// </summary>
    [JsonPropertyName("fileUploadType")]
    public string? FileUploadType { get; init; }

    /// <summary>
    /// Overall submission progress percentage (0-100)
    /// </summary>
    [JsonPropertyName("progressPercent")]
    public required int ProgressPercent { get; init; }

    /// <summary>
    /// Error message if the action could not be processed
    /// </summary>
    [JsonPropertyName("error")]
    public string? Error { get; init; }
}
