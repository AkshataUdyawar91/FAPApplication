using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Upload document response DTO
/// </summary>
public class UploadDocumentResponse
{
    /// <summary>
    /// Unique identifier of the uploaded document
    /// </summary>
    public Guid DocumentId { get; set; }
    
    /// <summary>
    /// Unique identifier of the package this document belongs to
    /// </summary>
    public Guid PackageId { get; set; }
    
    /// <summary>
    /// Original filename of the uploaded document
    /// </summary>
    public string FileName { get; set; } = string.Empty;
    
    /// <summary>
    /// File size in bytes
    /// </summary>
    public long FileSizeBytes { get; set; }
    
    /// <summary>
    /// Type of document uploaded
    /// </summary>
    public DocumentType DocumentType { get; set; }
    
    /// <summary>
    /// Azure Blob Storage URL where the document is stored
    /// </summary>
    public string BlobUrl { get; set; } = string.Empty;
    
    /// <summary>
    /// UTC timestamp when the document was uploaded
    /// </summary>
    public DateTime UploadedAt { get; set; }
}
