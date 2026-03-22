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
    private readonly IServiceScopeFactory _serviceScopeFactory;

    public DocumentsController(
        IDocumentService documentService, 
        ILogger<DocumentsController> logger,
        IApplicationDbContext context,
        IFileStorageService fileStorageService,
        IServiceScopeFactory serviceScopeFactory,
        IProactiveValidationService? proactiveValidationService = null,
        IProactiveValidator proactiveValidator = null!)
    {
        _documentService = documentService;
        _logger = logger;
        _context = context;
        _fileStorageService = fileStorageService;
        _serviceScopeFactory = serviceScopeFactory;
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
        [FromForm] string? activityState = null)
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
                 !string.IsNullOrEmpty(dealershipName) || !string.IsNullOrEmpty(dealershipAddress) || 
                 !string.IsNullOrEmpty(gpsLocation) || !string.IsNullOrEmpty(activityState)))
            {
                var package = await _context.DocumentPackages
                    .Include(p => p.Teams)
                    .FirstOrDefaultAsync(p => p.Id == response.PackageId);
                
                if (package != null)
                {
                    // Update activity state if provided
                    if (!string.IsNullOrEmpty(activityState))
                    {
                        _logger.LogInformation("Setting ActivityState to '{State}' for package {PackageId}", activityState, response.PackageId);
                        package.ActivityState = activityState;
                    }
                    else
                    {
                        _logger.LogWarning("ActivityState parameter is null or empty for package {PackageId}", response.PackageId);
                    }
                    
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

            // Trigger automatic processing for Invoice documents
            if (documentType == DocumentType.Invoice && effectivePackageId.HasValue)
            {
                try
                {
                    // Process invoice immediately in background
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            using var scope = _serviceScopeFactory.CreateScope();
                            var documentAgent = scope.ServiceProvider.GetRequiredService<IDocumentAgent>();
                            var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
                            
                            // Load invoice entity
                            var invoice = await context.Invoices
                                .FirstOrDefaultAsync(i => i.Id == response.DocumentId);
                            
                            if (invoice != null)
                            {
                                _logger.LogInformation("Starting automatic processing for invoice {InvoiceId}", invoice.Id);
                                
                                // Extract data using DocumentAgent
                                var extractionResult = await documentAgent.ExtractInvoiceDataAsync(
                                    invoice.BlobUrl, invoice.FileName);
                                
                                // Update invoice with extracted data
                                invoice.InvoiceNumber = extractionResult.InvoiceNumber;
                                invoice.InvoiceDate = extractionResult.InvoiceDate;
                                invoice.VendorName = extractionResult.VendorName;
                                invoice.GSTNumber = extractionResult.GSTNumber;
                                invoice.SubTotal = extractionResult.SubTotal;
                                invoice.TaxAmount = extractionResult.TaxAmount;
                                invoice.TotalAmount = extractionResult.TotalAmount;
                                
                                // Serialize extracted data to JSON
                                invoice.ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(extractionResult);
                                
                                // Get overall confidence from FieldConfidences dictionary
                                invoice.ExtractionConfidence = extractionResult.FieldConfidences?.GetValueOrDefault("Overall", 0.0) ?? 0.0;
                                invoice.UpdatedAt = DateTime.UtcNow;
                                
                                await context.SaveChangesAsync(default);
                                
                                _logger.LogInformation(
                                    "Invoice {InvoiceId} processed successfully. Confidence: {Confidence}",
                                    invoice.Id, invoice.ExtractionConfidence);
                            }
                        }
                        catch (Exception procEx)
                        {
                            _logger.LogError(procEx, "Automatic processing failed for invoice {DocumentId}", response.DocumentId);
                        }
                    });
                    
                    _logger.LogInformation("Automatic processing triggered for invoice {DocumentId}", response.DocumentId);
                }
                catch (Exception triggerEx)
                {
                    _logger.LogError(triggerEx, "Failed to trigger automatic processing for invoice {DocumentId}", response.DocumentId);
                    // Don't fail the upload if processing trigger fails
                }
            }

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
    /// Extract data from a document without creating any DB entities.
    /// Uploads the file to a temp blob, runs AI extraction, and returns the extracted fields.
    /// Used by the upload form to auto-populate fields before the submission is created.
    /// </summary>
    /// <param name="file">Document file to extract data from</param>
    /// <param name="documentType">Type of document (Invoice, CostSummary, etc.)</param>
    /// <param name="documentAgent">Document agent for AI extraction</param>
    /// <returns>Extracted data as JSON</returns>
    /// <response code="200">Extraction successful</response>
    /// <response code="400">Bad request - no file or unsupported type</response>
    /// <response code="500">Extraction failed</response>
    [HttpPost("extract")]
    [Authorize]
    [RequestSizeLimit(52428800)]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ExtractDocument(
        [FromForm] IFormFile file,
        [FromForm] string documentType,
        [FromForm] Guid? packageId,
        [FromServices] IDocumentAgent documentAgent,
        CancellationToken cancellationToken)
    {
        var totalStopwatch = System.Diagnostics.Stopwatch.StartNew();
        _logger.LogInformation("=== EXTRACTION STARTED === Document Type: {DocType}, File: {FileName}, Size: {FileSize} bytes, PackageId: {PackageId}", 
            documentType, file?.FileName, file?.Length, packageId);

        if (file == null || file.Length == 0)
            return BadRequest(new { error = "No file provided" });

        // Get user ID from claims
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "User ID not found in token" });
        }

        string? blobUrl = null;
        bool isPermanentUpload = packageId.HasValue && packageId.Value != Guid.Empty;
        
        try
        {
            // Step 1: Upload to blob storage (permanent if packageId provided, temp otherwise)
            var uploadStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var ext = Path.GetExtension(file.FileName);
            string fileName;
            
            if (isPermanentUpload)
            {
                // Permanent upload with unique name
                fileName = $"{Guid.NewGuid()}{ext}";
            }
            else
            {
                // Temp upload for extraction only
                fileName = $"temp-extract/{Guid.NewGuid()}{ext}";
            }
            
            blobUrl = await _fileStorageService.UploadFileAsync(file, "documents", fileName);
            uploadStopwatch.Stop();
            _logger.LogInformation("⏱️ [STEP 1] File Upload ({UploadType}): {ElapsedMs}ms", 
                isPermanentUpload ? "Permanent" : "Temp", uploadStopwatch.ElapsedMilliseconds);
            _logger.LogInformation("📤 [STEP 1 OUTPUT] Blob URL: {BlobUrl}", blobUrl);

            // Step 2: Extract data using AI
            var extractionStopwatch = System.Diagnostics.Stopwatch.StartNew();
            object? extracted = null;
            var docTypeLower = documentType.Trim().ToLowerInvariant();

            _logger.LogInformation("📥 [STEP 2 INPUT] Starting {DocType} extraction from blob: {BlobUrl}", documentType, blobUrl);

            if (docTypeLower == "invoice")
            {
                extracted = await documentAgent.ExtractInvoiceAsync(blobUrl, cancellationToken);
            }
            else if (docTypeLower == "costsummary")
            {
                extracted = await documentAgent.ExtractCostSummaryAsync(blobUrl, cancellationToken);
            }
            else if (docTypeLower == "activitysummary")
            {
                extracted = await documentAgent.ExtractActivityAsync(blobUrl, cancellationToken);
            }
            else if (docTypeLower == "po")
            {
                extracted = await documentAgent.ExtractPOAsync(blobUrl, cancellationToken);
            }
            else
            {
                return BadRequest(new { error = $"Extraction not supported for document type: {documentType}" });
            }
            extractionStopwatch.Stop();
            _logger.LogInformation("⏱️ [STEP 2] AI Extraction: {ElapsedMs}ms - {DocType} data extracted", 
                extractionStopwatch.ElapsedMilliseconds, documentType);

            // Step 3: Save to database if packageId provided
            Guid? documentId = null;
            if (isPermanentUpload && extracted != null)
            {
                var saveStopwatch = System.Diagnostics.Stopwatch.StartNew();
                _logger.LogInformation("📥 [STEP 3 INPUT] Saving to database - PackageId: {PackageId}, DocType: {DocType}", 
                    packageId, documentType);

                // Verify package exists and load it with all needed data
                var package = await _context.DocumentPackages
                    .FirstOrDefaultAsync(p => p.Id == packageId.Value && !p.IsDeleted, cancellationToken);
                
                if (package == null)
                {
                    return BadRequest(new { error = "Package not found" });
                }

                var now = DateTime.UtcNow;
                var createdBy = userId.ToString();

                // Create invoice entity with extracted data
                if (docTypeLower == "invoice" && extracted is InvoiceData invoiceData)
                {
                    // CRITICAL: Validate PO exists (same as upload API)
                    // First try: PO linked via package's SelectedPOId (assistant/dropdown flow)
                    // Second try: PO uploaded directly to this package (file upload flow)
                    var existingPo = package.SelectedPOId.HasValue
                        ? await _context.POs.FirstOrDefaultAsync(p => p.Id == package.SelectedPOId.Value, cancellationToken)
                        : await _context.POs.FirstOrDefaultAsync(p => p.PackageId == packageId.Value, cancellationToken);

                    if (existingPo == null)
                    {
                        _logger.LogWarning("No PO found for invoice upload — package {PkgId}, SelectedPOId: {SelPO}. Invoice will be rejected.",
                            packageId, package.SelectedPOId);
                        return BadRequest(new { error = "Cannot upload invoice: no Purchase Order is linked to this submission. Please select a PO first." });
                    }

                    _logger.LogInformation("=== INVOICE: PO found === POId: {POId}, PONumber: {PONum}", existingPo.Id, existingPo.PONumber);

                    var invoice = new Domain.Entities.Invoice
                    {
                        Id = Guid.NewGuid(),
                        PackageId = packageId.Value,
                        POId = existingPo.Id,  // Link to existing PO
                        VersionNumber = package.VersionNumber,  // Match package version
                        InvoiceNumber = invoiceData.InvoiceNumber,
                        InvoiceDate = invoiceData.InvoiceDate,
                        VendorName = invoiceData.VendorName,
                        GSTNumber = invoiceData.GSTNumber,
                        SubTotal = invoiceData.SubTotal,
                        TaxAmount = invoiceData.TaxAmount,
                        TotalAmount = invoiceData.TotalAmount,
                        FileName = file.FileName,
                        BlobUrl = blobUrl,
                        FileSizeBytes = file.Length,
                        ContentType = file.ContentType,
                        ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(invoiceData),
                        ExtractionConfidence = invoiceData.FieldConfidences?.GetValueOrDefault("Overall", 0.0) ?? 0.0,
                        IsFlaggedForReview = invoiceData.IsFlaggedForReview,
                        CreatedAt = now,
                        UpdatedAt = now,
                        CreatedBy = createdBy,
                        UpdatedBy = createdBy
                    };
                    
                    _context.Invoices.Add(invoice);
                    await _context.SaveChangesAsync(cancellationToken);
                    documentId = invoice.Id;
                    
                    _logger.LogInformation("✅ Invoice saved to database: {InvoiceId}, POId: {POId}, InvoiceNumber: {InvoiceNumber}, Total: {Total}", 
                        invoice.Id, invoice.POId, invoice.InvoiceNumber, invoice.TotalAmount);
                    
                    // Step 3.5: Trigger proactive validation for the invoice
                    if (_proactiveValidationService != null)
                    {
                        try
                        {
                            _ = Task.Run(async () =>
                            {
                                try
                                {
                                    using var scope = _serviceScopeFactory.CreateScope();
                                    var validationService = scope.ServiceProvider.GetRequiredService<IProactiveValidationService>();
                                    
                                    _logger.LogInformation("🔍 [STEP 3.5] Starting proactive validation for invoice {InvoiceId}", invoice.Id);
                                    
                                    await validationService.ValidateDocumentAsync(
                                        invoice.Id,
                                        DocumentType.Invoice,
                                        packageId.Value,
                                        default);
                                    
                                    _logger.LogInformation("✅ [STEP 3.5] Proactive validation completed for invoice {InvoiceId}", invoice.Id);
                                }
                                catch (Exception valEx)
                                {
                                    _logger.LogError(valEx, "❌ [STEP 3.5] Proactive validation failed for invoice {InvoiceId}", invoice.Id);
                                }
                            });
                        }
                        catch (Exception triggerEx)
                        {
                            _logger.LogError(triggerEx, "Failed to trigger proactive validation for invoice {InvoiceId}", invoice.Id);
                            // Don't fail the extraction if validation trigger fails
                        }
                    }
                }
                
                saveStopwatch.Stop();
                _logger.LogInformation("⏱️ [STEP 3] Database Save: {ElapsedMs}ms", saveStopwatch.ElapsedMilliseconds);
            }

            totalStopwatch.Stop();
            _logger.LogInformation("=== EXTRACTION COMPLETED === Total Time: {TotalMs}ms", 
                totalStopwatch.ElapsedMilliseconds);

            var response = new 
            { 
                extractedData = extracted,
                documentId = documentId,
                packageId = packageId,
                blobUrl = isPermanentUpload ? blobUrl : null
            };
            
            return Ok(response);
        }
        catch (Exception ex)
        {
            totalStopwatch.Stop();
            _logger.LogError(ex, "=== EXTRACTION FAILED === Total Time: {TotalMs}ms, DocType: {DocType}, Error: {Error}", 
                totalStopwatch.ElapsedMilliseconds, documentType, ex.Message);
            return StatusCode(500, new { error = "Extraction failed. You can enter details manually." });
        }
        finally
        {
            // Step 4: Clean up temp blob (only if not permanent upload)
            if (blobUrl != null && !isPermanentUpload)
            {
                var cleanupStopwatch = System.Diagnostics.Stopwatch.StartNew();
                try 
                { 
                    await _fileStorageService.DeleteFileAsync(blobUrl); 
                    cleanupStopwatch.Stop();
                    _logger.LogInformation("⏱️ [STEP 4] Cleanup: {ElapsedMs}ms - Temp blob deleted", 
                        cleanupStopwatch.ElapsedMilliseconds);
                }
                catch (Exception delEx) 
                { 
                    cleanupStopwatch.Stop();
                    _logger.LogWarning(delEx, "⏱️ [STEP 4] Cleanup: {ElapsedMs}ms - Failed to delete temp blob {BlobUrl}", 
                        cleanupStopwatch.ElapsedMilliseconds, blobUrl); 
                }
            }
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
