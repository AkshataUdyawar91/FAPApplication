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
    /// Upload a document file to Azure Blob Storage and associate with a package
    /// </summary>
    /// <param name="file">Document file to upload (PDF, JPG, PNG)</param>
    /// <param name="documentType">Type of document (PO, Invoice, CostSummary, Activity, Photo)</param>
    /// <param name="packageId">Optional package ID to associate document with existing package</param>
    /// <returns>Upload response with document ID and blob URL</returns>
    /// <response code="200">Document uploaded successfully</response>
    /// <response code="400">Bad request - no file provided or validation failed</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="500">Internal server error</response>
    [HttpPost("upload")]
    [ProducesResponseType(typeof(UploadDocumentResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [RequestSizeLimit(52428800)] // 50MB limit
    public async Task<IActionResult> UploadDocument(
        [FromForm] IFormFile file,
        [FromForm] DocumentType documentType,
        [FromForm] Guid? packageId,
        [FromForm] DateTime? campaignStartDate = null,
        [FromForm] DateTime? campaignEndDate = null,
        [FromForm] int? campaignWorkingDays = null,
        [FromForm] string? dealershipName = null,
        [FromForm] string? dealershipAddress = null,
        [FromForm] string? gpsLocation = null,
        [FromForm] string? teamsJson = null)
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

            // Update package with campaign and dealership data if provided
            if (response.PackageId != Guid.Empty && 
                (campaignStartDate.HasValue || campaignEndDate.HasValue || campaignWorkingDays.HasValue ||
                 !string.IsNullOrEmpty(dealershipName) || !string.IsNullOrEmpty(dealershipAddress) || !string.IsNullOrEmpty(gpsLocation)))
            {
                var package = await _context.DocumentPackages
                    .Include(p => p.Teams)
                    .FirstOrDefaultAsync(p => p.Id == response.PackageId);
                
                if (package != null)
                {
                    // Update first team's fields (or create a team if none exists)
                    var team = package.Teams.FirstOrDefault();
                    if (team == null)
                    {
                        team = new Domain.Entities.Teams
                        {
                            Id = Guid.NewGuid(),
                            PackageId = response.PackageId,
                            CreatedAt = DateTime.UtcNow
                        };
                        _context.Teams.Add(team);
                    }

                    // Campaign fields
                    if (campaignStartDate.HasValue) team.StartDate = campaignStartDate.Value;
                    if (campaignEndDate.HasValue) team.EndDate = campaignEndDate.Value;
                    if (campaignWorkingDays.HasValue) team.WorkingDays = campaignWorkingDays.Value;
                    
                    // Dealership fields
                    if (!string.IsNullOrEmpty(dealershipName)) team.DealershipName = dealershipName;
                    if (!string.IsNullOrEmpty(dealershipAddress)) team.DealershipAddress = dealershipAddress;
                    if (!string.IsNullOrEmpty(gpsLocation)) team.GPSLocation = gpsLocation;
                    
                    // Note: TeamsJson is now stored at Team level
                    if (!string.IsNullOrEmpty(teamsJson)) team.TeamsJson = teamsJson;
                    
                    team.UpdatedAt = DateTime.UtcNow;
                    package.UpdatedAt = DateTime.UtcNow;
                    
                    await _context.SaveChangesAsync(default);
                    
                    _logger.LogInformation(
                        "Team data updated for {PackageId}: StartDate={StartDate}, EndDate={EndDate}, WorkingDays={WorkingDays}, Dealership={Dealership}",
                        response.PackageId, campaignStartDate, campaignEndDate, campaignWorkingDays, dealershipName);
                }
            }

            _logger.LogInformation(
                "Document uploaded by user {UserId}: {DocumentId}",
                userId, response.DocumentId);

            return Ok(response);
        }
        catch (System.UnauthorizedAccessException ex)
        {
            _logger.LogError(ex, "Unauthorized document upload attempt");
            return Unauthorized(new { message = "Authentication failed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading document");
            return StatusCode(500, new { message = "An error occurred while uploading the document" });
        }
    }

    /// <summary>
    /// Get document metadata by ID with resource ownership verification
    /// </summary>
    /// <param name="id">Unique identifier of the document</param>
    /// <returns>Document metadata including filename, type, size, and blob URL</returns>
    /// <response code="200">Returns document metadata</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - user does not own this document</response>
    /// <response code="404">Not found - document does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetDocument(Guid id, [FromQuery] DocumentType? documentType = null)
    {
        try
        {
            // Get user ID and role from claims
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                ?? throw new System.UnauthorizedAccessException("User ID not found in token");
            
            if (!Guid.TryParse(userIdClaim, out var userId))
            {
                throw new System.UnauthorizedAccessException("Invalid user ID format");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

            // If documentType is provided, query that specific table; otherwise try each table
            DocumentInfoDto? document = null;
            if (documentType.HasValue)
            {
                document = await _documentService.GetDocumentAsync(id, documentType.Value);
            }
            else
            {
                // Try each dedicated table until found
                var typesToTry = new[] 
                { 
                    DocumentType.PO, DocumentType.Invoice, DocumentType.CostSummary,
                    DocumentType.ActivitySummary, DocumentType.EnquiryDocument, DocumentType.TeamPhoto 
                };
                foreach (var type in typesToTry)
                {
                    document = await _documentService.GetDocumentAsync(id, type);
                    if (document != null) break;
                }
            }

            if (document == null)
            {
                return NotFound(new { message = "Document not found" });
            }

            // Verify resource ownership for Agency users
            if (userRole == "Agency")
            {
                var package = await _context.DocumentPackages
                    .AsNoTracking()
                    .FirstOrDefaultAsync(p => p.Id == document.PackageId);

                if (package == null)
                {
                    return NotFound(new { message = "Document not found" });
                }

                if (package.SubmittedByUserId != userId)
                {
                    _logger.LogWarning(
                        "User {UserId} attempted to access document {DocumentId} owned by {OwnerId}",
                        userId, id, package.SubmittedByUserId);
                    return StatusCode(403, new { message = "You do not have permission to access this document" });
                }
            }

            return Ok(new
            {
                document.Id,
                document.FileName,
                document.FileSizeBytes,
                type = document.Type,
                document.BlobUrl,
                document.ExtractedDataJson,
                document.ExtractionConfidence,
                extractionComplete = !string.IsNullOrEmpty(document.ExtractedDataJson) && 
                                   document.ExtractedDataJson != "{}"
            });
        }
        catch (System.UnauthorizedAccessException ex)
        {
            _logger.LogError(ex, "Unauthorized document access attempt");
            return Unauthorized(new { message = "Authentication failed" });
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
        [FromQuery] DocumentType? documentType = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Find the document across dedicated tables
            DocumentInfoDto? document = null;
            if (documentType.HasValue)
            {
                document = await _documentService.GetDocumentAsync(id, documentType.Value);
            }
            else
            {
                var typesToTry = new[] 
                { 
                    DocumentType.PO, DocumentType.Invoice, DocumentType.CostSummary,
                    DocumentType.ActivitySummary, DocumentType.EnquiryDocument, DocumentType.TeamPhoto 
                };
                foreach (var type in typesToTry)
                {
                    document = await _documentService.GetDocumentAsync(id, type);
                    if (document != null) break;
                }
            }

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
