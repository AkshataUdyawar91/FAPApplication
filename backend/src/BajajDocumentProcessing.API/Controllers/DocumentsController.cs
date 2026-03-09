using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Documents controller for file upload and management
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize] // Authentication enabled
public class DocumentsController : ControllerBase
{
    private readonly IDocumentService _documentService;
    private readonly ILogger<DocumentsController> _logger;
    private readonly IApplicationDbContext _context;
    private readonly IFileStorageService _fileStorageService;

    public DocumentsController(
        IDocumentService documentService, 
        ILogger<DocumentsController> logger,
        IApplicationDbContext context,
        IFileStorageService fileStorageService)
    {
        _documentService = documentService;
        _logger = logger;
        _context = context;
        _fileStorageService = fileStorageService;
    }

    /// <summary>
    /// Upload a document
    /// </summary>
    [HttpPost("upload")]
    [ProducesResponseType(typeof(UploadDocumentResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [RequestSizeLimit(52428800)] // 50MB limit
    public async Task<IActionResult> UploadDocument(
        [FromForm] IFormFile file,
        [FromForm] DocumentType documentType,
        [FromForm] Guid? packageId)
    {
        try
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest(new { message = "No file provided" });
            }

            // Get user ID from claims
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                ?? throw new System.UnauthorizedAccessException("User ID not found in token");
            
            if (!Guid.TryParse(userIdClaim, out var userId))
            {
                throw new System.UnauthorizedAccessException("Invalid user ID format");
            }

            // Validate file
            if (!await _documentService.ValidateFileAsync(file, documentType))
            {
                return BadRequest(new { message = "File validation failed. Check file type and size." });
            }

            // Upload document
            var response = await _documentService.UploadDocumentAsync(file, documentType, packageId, userId);

            _logger.LogInformation(
                "Document uploaded by user {UserId}: {DocumentId}",
                userId, response.DocumentId);

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading document");
            return StatusCode(500, new { message = "An error occurred while uploading the document" });
        }
    }

    /// <summary>
    /// Get document by ID
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetDocument(Guid id)
    {
        try
        {
            var document = await _documentService.GetDocumentAsync(id);

            if (document == null)
            {
                return NotFound(new { message = "Document not found" });
            }

            return Ok(new
            {
                document.Id,
                document.FileName,
                document.FileSizeBytes,
                document.Type,
                document.BlobUrl,
                document.CreatedAt
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving document {DocumentId}", id);
            return StatusCode(500, new { message = "An error occurred while retrieving the document" });
        }
    }

    /// <summary>
    /// Download a document as base64-encoded content.
    /// Returns the file bytes encoded as base64 along with metadata,
    /// so the frontend can construct a downloadable blob.
    /// </summary>
    [HttpGet("{id}/download")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> DownloadDocument(
        Guid id,
        CancellationToken cancellationToken)
    {
        try
        {
            var document = await _context.Documents
                .AsNoTracking()
                .FirstOrDefaultAsync(d => d.Id == id, cancellationToken);

            if (document == null)
            {
                _logger.LogWarning("Document not found for download: {DocumentId}", id);
                return NotFound(new { message = "Document not found" });
            }

            if (string.IsNullOrEmpty(document.BlobUrl))
            {
                _logger.LogWarning("BlobUrl is empty for document: {DocumentId}", id);
                return NotFound(new { message = "Document file not available" });
            }

            var fileBytes = await _fileStorageService.GetFileBytesAsync(document.BlobUrl);
            var base64Content = Convert.ToBase64String(fileBytes);
            
            var contentType = !string.IsNullOrEmpty(document.ContentType)
                ? document.ContentType
                : "application/octet-stream";

            _logger.LogInformation(
                "Document downloaded: {DocumentId}, {FileName}, {Size} bytes",
                id, document.FileName, fileBytes.Length);

            return Ok(new
            {
                base64Content,
                filename = document.FileName,
                contentType,
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading document {DocumentId}", id);
            return StatusCode(500, new { message = "An error occurred while preparing the download" });
        }
    }
}
