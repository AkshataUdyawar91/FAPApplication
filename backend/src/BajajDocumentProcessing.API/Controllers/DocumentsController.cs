using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
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
// [Authorize] // DISABLED FOR TESTING
public class DocumentsController : ControllerBase
{
    private readonly IDocumentService _documentService;
    private readonly ILogger<DocumentsController> _logger;

    public DocumentsController(IDocumentService documentService, ILogger<DocumentsController> logger)
    {
        _documentService = documentService;
        _logger = logger;
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

            // Get user ID from claims (or use default for testing)
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            Guid userId;
            
            if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out userId))
            {
                // For testing without authentication, use the agency user's ID
                _logger.LogWarning("No authenticated user found, using default agency user for testing");
                userId = Guid.Parse("3690062E-CA9C-46B9-AF75-8EFE403A18E7"); // agency@bajaj.com
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
}
