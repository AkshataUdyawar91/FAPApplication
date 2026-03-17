using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// Request from the frontend to process a conversational submission action
/// </summary>
public class ConversationRequest
{
    /// <summary>
    /// Submission ID for an existing draft. Null when starting a new submission.
    /// </summary>
    [JsonPropertyName("submissionId")]
    public Guid? SubmissionId { get; init; }

    /// <summary>
    /// The user action: "start", "select_po", "confirm", "upload", "skip", "submit", "edit", "resume"
    /// </summary>
    [JsonPropertyName("action")]
    [Required(ErrorMessage = "Action is required")]
    public required string Action { get; init; }

    /// <summary>
    /// Optional free-text input from the user
    /// </summary>
    [JsonPropertyName("message")]
    public string? Message { get; init; }

    /// <summary>
    /// Optional structured data payload (PO id, state name, team details, etc.)
    /// </summary>
    [JsonPropertyName("payloadJson")]
    public string? PayloadJson { get; init; }
}
