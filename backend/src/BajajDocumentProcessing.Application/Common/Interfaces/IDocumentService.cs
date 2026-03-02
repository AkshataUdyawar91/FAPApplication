using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Http;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Document service interface
/// </summary>
public interface IDocumentService
{
    Task<UploadDocumentResponse> UploadDocumentAsync(IFormFile file, DocumentType documentType, Guid? packageId, Guid userId);
    Task<bool> ValidateFileAsync(IFormFile file, DocumentType documentType);
    Task<Domain.Entities.Document?> GetDocumentAsync(Guid documentId);
}
