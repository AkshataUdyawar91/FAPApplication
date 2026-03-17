using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Http;
using System.ComponentModel.DataAnnotations;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Upload document request DTO
/// </summary>
public class UploadDocumentRequest
{
    /// <summary>
    /// Document file to upload
    /// </summary>
    [Required(ErrorMessage = "File is required")]
    public IFormFile File { get; set; } = null!;
    
    /// <summary>
    /// Type of document being uploaded
    /// </summary>
    [Required(ErrorMessage = "Document type is required")]
    public DocumentType DocumentType { get; set; }
    
    /// <summary>
    /// Optional package ID to associate document with existing package
    /// </summary>
    public Guid? PackageId { get; set; }
}
