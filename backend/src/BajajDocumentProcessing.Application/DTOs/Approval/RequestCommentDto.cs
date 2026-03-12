using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Approval;

/// <summary>
/// DTO representing a comment on a document package submission.
/// </summary>
public class RequestCommentDto
{
    /// <summary>
    /// Unique identifier of the comment.
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }

    /// <summary>
    /// Document package ID this comment belongs to.
    /// </summary>
    [JsonPropertyName("packageId")]
    public required Guid PackageId { get; init; }

    /// <summary>
    /// User ID of the commenter.
    /// </summary>
    [JsonPropertyName("userId")]
    public required Guid UserId { get; init; }

    /// <summary>
    /// Display name of the commenter.
    /// </summary>
    [JsonPropertyName("userName")]
    public string? UserName { get; init; }

    /// <summary>
    /// Role of the commenter (Agency, ASM, RA, Admin).
    /// </summary>
    [JsonPropertyName("userRole")]
    public required string UserRole { get; init; }

    /// <summary>
    /// The comment text content.
    /// </summary>
    [JsonPropertyName("commentText")]
    public required string CommentText { get; init; }

    /// <summary>
    /// UTC timestamp when the comment was created.
    /// </summary>
    [JsonPropertyName("commentDate")]
    public required DateTime CommentDate { get; init; }

    /// <summary>
    /// Package version when this comment was made.
    /// </summary>
    [JsonPropertyName("versionNumber")]
    public required int VersionNumber { get; init; }
}
