using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Upload document response DTO
/// </summary>
public class UploadDocumentResponse
{
    public Guid DocumentId { get; set; }
    public Guid PackageId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
    public DocumentType DocumentType { get; set; }
    public string BlobUrl { get; set; } = string.Empty;
    public DateTime UploadedAt { get; set; }
}
