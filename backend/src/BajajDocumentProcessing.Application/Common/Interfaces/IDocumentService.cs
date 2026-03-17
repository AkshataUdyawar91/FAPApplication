using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Http;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Document service interface
/// </summary>
public interface IDocumentService
{
    /// <summary>
    /// Uploads a document to blob storage and creates a document entity
    /// </summary>
    /// <param name="file">File to upload</param>
    /// <param name="documentType">Type of document (PO, Invoice, CostSummary, etc.)</param>
    /// <param name="packageId">Optional package ID to associate the document with</param>
    /// <param name="userId">User ID uploading the document</param>
    /// <returns>Upload response with document ID and blob URL</returns>
    Task<UploadDocumentResponse> UploadDocumentAsync(IFormFile file, DocumentType documentType, Guid? packageId, Guid userId);

    /// <summary>
    /// Validates a file before upload (size, type, malware scan)
    /// </summary>
    /// <param name="file">File to validate</param>
    /// <param name="documentType">Expected document type</param>
    /// <returns>True if file is valid, false otherwise</returns>
    Task<bool> ValidateFileAsync(IFormFile file, DocumentType documentType);

    /// <summary>
    /// Retrieves a document by ID and type from the appropriate dedicated table
    /// </summary>
    /// <param name="documentId">Document's unique identifier</param>
    /// <param name="documentType">Type of document to look up in the correct table</param>
    /// <returns>Document info DTO or null if not found</returns>
    Task<DocumentInfoDto?> GetDocumentAsync(Guid documentId, DocumentType documentType);
}
