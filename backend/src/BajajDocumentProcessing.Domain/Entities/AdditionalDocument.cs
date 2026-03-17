using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Represents any additional supporting documents attached to a document package.
/// Supports multiple documents per package with user-defined types.
/// </summary>
public class AdditionalDocument : BaseEntity
{
    /// <summary>
    /// Foreign key to the parent DocumentPackage
    /// </summary>
    public Guid PackageId { get; set; }

    /// <summary>
    /// User-defined document type (e.g., "Supporting Invoice", "Contract", "Agreement")
    /// </summary>
    public string DocumentType { get; set; } = string.Empty;

    /// <summary>
    /// Optional description of the document
    /// </summary>
    public string? Description { get; set; }

    /// <summary>
    /// Original file name
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Azure Blob Storage URL
    /// </summary>
    public string BlobUrl { get; set; } = string.Empty;

    /// <summary>
    /// File size in bytes
    /// </summary>
    public long FileSizeBytes { get; set; }

    /// <summary>
    /// MIME content type (e.g., "application/pdf", "image/jpeg")
    /// </summary>
    public string ContentType { get; set; } = string.Empty;

    /// <summary>
    /// Version number matching the parent package version
    /// Increments on resubmission
    /// </summary>
    public int VersionNumber { get; set; } = 1;

    // Navigation properties

    /// <summary>
    /// Parent document package
    /// </summary>
    public DocumentPackage? DocumentPackage { get; set; }
}
