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
    private readonly IProactiveValidationService? _proactiveValidationService;
    private readonly IProactiveValidator _proactiveValidator;

    public DocumentsController(
        IDocumentService documentService, 
        ILogger<DocumentsController> logger,
        IApplicationDbContext context,
        IFileStorageService fileStorageService,
        IProactiveValidationService? proactiveValidationService = null,
        IProactiveValidator proactiveValidator = null!)
    {
        _documentService = documentService;
        _logger = logger;
        _context = context;
        _fileStorageService = fileStorageService;
        _proactiveValidationService = proactiveValidationService;
        _proactiveValidator = proactiveValidator;
    }

    /// <summary>
    /// Upload a document file to Azure Blob Storage and associate with a package
    /// </summary>
    /// <param name="file">Document file to upload (PDF, JPG, PNG)</param>
    /// <param name="documentType">Type of document (PO, Invoice, CostSummary, Activity, Photo)</param>
    /// <param name="packageId">Optional package ID to associate document with existing package</param>
    /// <param name="submissionId">Optional submission ID (alias for packageId, used in conversational flow)</param>
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
        [FromForm] Guid? submissionId = null,
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
            _logger.LogInformation("=== DOCUMENTS UPLOAD === File: {FileName}, Size: {Size}, DocType: {DocType}, PackageId: {PkgId}, SubmissionId: {SubId}",
                file?.FileName, file?.Length, documentType, packageId, submissionId);

            if (file == null || file.Length == 0)
            {
                return BadRequest(new { message = "No file provided" });
            }

            // submissionId is an alias for packageId (conversational flow)
            var effectivePackageId = packageId ?? submissionId;

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
            var response = await _documentService.UploadDocumentAsync(file, documentType, effectivePackageId, userId);

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

            // Trigger proactive validation for conversational flow documents
            if (effectivePackageId.HasValue && _proactiveValidationService != null &&
                (documentType == DocumentType.Invoice || documentType == DocumentType.CostSummary || documentType == DocumentType.ActivitySummary))
            {
                try
                {
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            await _proactiveValidationService.ValidateDocumentAsync(
                                response.DocumentId, documentType, effectivePackageId.Value);
                        }
                        catch (Exception valEx)
                        {
                            _logger.LogError(valEx, "Proactive validation failed for document {DocumentId}", response.DocumentId);
                        }
                    });
                    _logger.LogInformation("Proactive validation triggered for document {DocumentId}", response.DocumentId);
                }
                catch (Exception valEx)
                {
                    _logger.LogError(valEx, "Failed to trigger proactive validation for document {DocumentId}", response.DocumentId);
                    // Don't fail the upload if validation trigger fails
                }
            }

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

            // Verify resource ownership for Agency users — scoped to agency, not individual user
            if (userRole == "Agency")
            {
                var package = await _context.DocumentPackages
                    .AsNoTracking()
                    .FirstOrDefaultAsync(p => p.Id == document.PackageId);

                if (package == null)
                {
                    return NotFound(new { message = "Document not found" });
                }

                // Look up the user's agency from the Users table
                var userAgencyId = await _context.Users
                    .AsNoTracking()
                    .Where(u => u.Id == userId && !u.IsDeleted)
                    .Select(u => u.AgencyId)
                    .FirstOrDefaultAsync();

                if (userAgencyId == null || package.AgencyId != userAgencyId.Value)
                {
                    _logger.LogWarning(
                        "User {UserId} (Agency {UserAgencyId}) attempted to access document {DocumentId} owned by Agency {PackageAgencyId}",
                        userId, userAgencyId, id, package.AgencyId);
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
    /// Get extraction status for a document (polling endpoint for conversational flow)
    /// </summary>
    /// <param name="id">Document ID</param>
    /// <param name="documentType">Optional document type hint</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Extraction status (Pending, Processing, Completed, Failed)</returns>
    /// <response code="200">Returns extraction status</response>
    /// <response code="404">Document not found</response>
    [HttpGet("{id}/status")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetDocumentStatus(
        Guid id,
        [FromQuery] DocumentType? documentType = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
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
                return NotFound(new { message = "Document not found" });
            }

            // Determine extraction status based on extracted data
            string status;
            string? error = null;

            if (!string.IsNullOrEmpty(document.ExtractedDataJson) && document.ExtractedDataJson != "{}")
            {
                status = "Completed";
            }
            else if (document.ExtractionConfidence.HasValue && document.ExtractionConfidence < 0)
            {
                status = "Failed";
                error = "Extraction failed";
            }
            else
            {
                status = "Processing";
            }

            return Ok(new
            {
                documentId = id,
                status,
                error
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting document status {DocumentId}", id);
            return StatusCode(500, new { message = "An error occurred while retrieving document status" });
        }
    }

    /// <summary>
    /// Get proactive validation results for a document (conversational flow)
    /// </summary>
    /// <param name="id">Document ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Per-rule validation results</returns>
    /// <response code="200">Returns validation results</response>
    /// <response code="404">Document or validation results not found</response>
    [HttpGet("{id}/validation-results")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetDocumentValidationResults(
        Guid id,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Look for validation results by DocumentId
            var validationResult = await _context.ValidationResults
                .AsNoTracking()
                .FirstOrDefaultAsync(vr => vr.DocumentId == id, cancellationToken);

            if (validationResult == null)
            {
                return NotFound(new { message = "Validation results not found for this document" });
            }

            // Parse RuleResultsJson if available
            List<object>? rules = null;
            if (!string.IsNullOrEmpty(validationResult.RuleResultsJson))
            {
                try
                {
                    rules = System.Text.Json.JsonSerializer.Deserialize<List<object>>(validationResult.RuleResultsJson);
                }
                catch
                {
                    _logger.LogWarning("Failed to parse RuleResultsJson for document {DocumentId}", id);
                }
            }

            return Ok(new
            {
                documentId = id,
                documentType = validationResult.DocumentType.ToString(),
                allPassed = validationResult.AllValidationsPassed,
                rules = rules ?? new List<object>(),
                failureReason = validationResult.FailureReason
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting validation results for document {DocumentId}", id);
            return StatusCode(500, new { message = "An error occurred while retrieving validation results" });
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

    /// <summary>
    /// Run proactive field presence validation on an uploaded document.
    /// Returns missing fields immediately so the user can correct before submitting.
    /// </summary>
    /// <param name="id">Document ID to validate</param>
    /// <param name="documentType">Type of the document</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <response code="200">Validation result with pass/fail and missing fields</response>
    /// <response code="401">Unauthorized</response>
    /// <response code="403">Forbidden - user does not own this document</response>
    /// <response code="404">Document not found</response>
    [HttpPost("{id}/validate")]
    [ProducesResponseType(typeof(ProactiveValidationResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ValidateDocument(
        [FromRoute] Guid id,
        [FromQuery] DocumentType documentType,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? throw new System.UnauthorizedAccessException("User ID not found in token");

            if (!Guid.TryParse(userIdClaim, out var userId))
            {
                throw new System.UnauthorizedAccessException("Invalid user ID format");
            }

            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

            // Find the document to verify it exists and check ownership
            var document = await _documentService.GetDocumentAsync(id, documentType);
            if (document == null)
            {
                return NotFound(new { message = "Document not found" });
            }

            // Verify resource ownership for Agency users
            if (userRole == "Agency")
            {
                var package = await _context.DocumentPackages
                    .AsNoTracking()
                    .FirstOrDefaultAsync(p => p.Id == document.PackageId, cancellationToken);

                if (package == null || package.SubmittedByUserId != userId)
                {
                    return StatusCode(403, new { message = "You do not have permission to validate this document" });
                }
            }

            var result = await _proactiveValidator.ValidateDocumentOnUploadAsync(
                id, documentType, cancellationToken);

            return Ok(result);
        }
        catch (System.UnauthorizedAccessException ex)
        {
            _logger.LogError(ex, "Unauthorized proactive validation attempt");
            return Unauthorized(new { message = "Authentication failed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during proactive validation for document {DocumentId}", id);
            return StatusCode(500, new { message = "An error occurred during validation" });
        }
    }
}
