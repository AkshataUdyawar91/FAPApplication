using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Response after creating a draft submission
/// </summary>
public class CreateDraftResponse
{
    [JsonPropertyName("submissionId")]
    public Guid SubmissionId { get; set; }

    [JsonPropertyName("submissionNumber")]
    public string? SubmissionNumber { get; set; }
}
