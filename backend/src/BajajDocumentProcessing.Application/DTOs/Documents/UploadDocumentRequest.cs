using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Http;

namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Upload document request DTO
/// </summary>
public class UploadDocumentRequest
{
    public IFormFile File { get; set; } = null!;
    public DocumentType DocumentType { get; set; }
    public Guid? PackageId { get; set; }
}
