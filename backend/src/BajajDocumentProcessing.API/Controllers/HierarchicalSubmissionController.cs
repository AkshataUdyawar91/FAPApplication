using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Domain.Exceptions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Controller for hierarchical document submission
/// New Structure: FAP → PO → Campaigns (Teams) → Invoices/Photos
/// Each Campaign has: multiple Invoices, multiple Photos, 1 Cost Summary, 1 Activity Summary
/// </summary>
[ApiController]
[Route("api/hierarchical")]
[Authorize]
public class HierarchicalSubmissionController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly IFileStorageService _fileStorage;
    private readonly IDocumentAgent _documentAgent;
    private readonly IDocumentService _documentService;
    private readonly IServiceScopeFactory _serviceScopeFactory;
    private readonly ILogger<HierarchicalSubmissionController> _logger;

    public HierarchicalSubmissionController(
        IApplicationDbContext context,
        IFileStorageService fileStorage,
        IDocumentAgent documentAgent,
        IDocumentService documentService,
        IServiceScopeFactory serviceScopeFactory,
        ILogger<HierarchicalSubmissionController> logger)
    {
        _context = context;
        _fileStorage = fileStorage;
        _documentAgent = documentAgent;
        _documentService = documentService;
        _serviceScopeFactory = serviceScopeFactory;
        _logger = logger;
    }

    /// <summary>
    /// Add a campaign (team) to a package
    /// </summary>
    [HttpPost("{packageId}/campaigns")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddCampaign(
        Guid packageId,
        [FromBody] AddCampaignRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            // Auto-assign TeamNumber based on existing teams in this package
            var existingTeamCount = await _context.Campaigns
                .CountAsync(t => t.PackageId == packageId && !t.IsDeleted, cancellationToken);

            var campaign = new Teams
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                CampaignName = request.CampaignName,
                TeamCode = request.TeamCode,
                StartDate = request.StartDate,
                EndDate = request.EndDate,
                WorkingDays = request.WorkingDays,
                DealershipName = request.DealershipName,
                DealershipAddress = request.DealershipAddress,
                GPSLocation = request.GPSLocation,
                State = request.State,
                TeamNumber = existingTeamCount + 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Campaigns.Add(campaign);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Campaign {CampaignId} added to package {PackageId}", campaign.Id, packageId);

            return Ok(new { campaignId = campaign.Id, message = "Campaign added successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding campaign to package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to add campaign" });
        }
    }

    /// <summary>
    /// Add an invoice to a package (linked to PO). Invoices are uploaded from the PO step.
    /// </summary>
    [HttpPost("{packageId}/invoices")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddInvoiceToPackage(
        Guid packageId,
        [FromForm] AddInvoiceRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .Include(p => p.PO)
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            if (package.PO == null)
                return BadRequest(new { error = "PO must be uploaded before adding invoices" });

            // Upload file
            string blobUrl = "";
            if (request.File != null)
            {
                blobUrl = await _fileStorage.UploadFileAsync(request.File, "invoices", $"{Guid.NewGuid()}_{request.File.FileName}");
            }

            var invoice = new Invoice
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                POId = package.PO.Id,
                InvoiceNumber = request.InvoiceNumber,
                InvoiceDate = request.InvoiceDate,
                VendorName = request.VendorName,
                GSTNumber = request.GSTNumber,
                TotalAmount = request.TotalAmount,
                FileName = request.File?.FileName ?? "",
                BlobUrl = blobUrl,
                FileSizeBytes = request.File?.Length ?? 0,
                ContentType = request.File?.ContentType ?? "",
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Invoices.Add(invoice);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Invoice {InvoiceId} added to package {PackageId} (PO: {POId})", invoice.Id, packageId, package.PO.Id);

            // IMMEDIATE EXTRACTION: Extract invoice fields synchronously for instant feedback
            string? extractedInvoiceNumber = invoice.InvoiceNumber;
            DateTime? extractedInvoiceDate = invoice.InvoiceDate;
            string? extractedVendorName = invoice.VendorName;
            string? extractedGSTNumber = invoice.GSTNumber;
            decimal? extractedTotalAmount = invoice.TotalAmount;

            if (!string.IsNullOrEmpty(blobUrl))
            {
                try
                {
                    _logger.LogInformation("Starting immediate extraction for invoice {InvoiceId}", invoice.Id);
                    var invoiceData = await _documentAgent.ExtractInvoiceAsync(blobUrl, cancellationToken);
                    
                    // Update invoice with extracted data immediately
                    if (string.IsNullOrEmpty(invoice.InvoiceNumber) && !string.IsNullOrEmpty(invoiceData.InvoiceNumber))
                    {
                        invoice.InvoiceNumber = invoiceData.InvoiceNumber;
                        extractedInvoiceNumber = invoiceData.InvoiceNumber;
                    }
                    
                    if (invoice.InvoiceDate == null && invoiceData.InvoiceDate != default)
                    {
                        invoice.InvoiceDate = invoiceData.InvoiceDate;
                        extractedInvoiceDate = invoiceData.InvoiceDate;
                    }
                    
                    if (string.IsNullOrEmpty(invoice.VendorName) && !string.IsNullOrEmpty(invoiceData.VendorName))
                    {
                        invoice.VendorName = invoiceData.VendorName;
                        extractedVendorName = invoiceData.VendorName;
                    }
                    
                    if (string.IsNullOrEmpty(invoice.GSTNumber) && !string.IsNullOrEmpty(invoiceData.GSTNumber))
                    {
                        invoice.GSTNumber = invoiceData.GSTNumber;
                        extractedGSTNumber = invoiceData.GSTNumber;
                    }
                    
                    if ((invoice.TotalAmount == null || invoice.TotalAmount == 0) && invoiceData.TotalAmount > 0)
                    {
                        invoice.TotalAmount = invoiceData.TotalAmount;
                        extractedTotalAmount = invoiceData.TotalAmount;
                    }
                    
                    invoice.UpdatedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync(cancellationToken);
                    
                    _logger.LogInformation("Immediate invoice extraction completed: Number={Number}, Amount={Amount}", 
                        invoiceData.InvoiceNumber, invoiceData.TotalAmount);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Immediate extraction failed for invoice {InvoiceId}", invoice.Id);
                    // Continue - return what we have
                }
            }

            return Ok(new { 
                invoiceId = invoice.Id, 
                message = "Invoice added successfully",
                // Return immediately extracted data for instant UI update
                extractedData = new {
                    invoiceNumber = extractedInvoiceNumber,
                    invoiceDate = extractedInvoiceDate,
                    vendorName = extractedVendorName,
                    gstNumber = extractedGSTNumber,
                    totalAmount = extractedTotalAmount
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding invoice to package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to add invoice" });
        }
    }

    /// <summary>
    /// Add photos to a campaign
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/photos")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddPhotos(
        Guid packageId,
        Guid campaignId,
        [FromForm] List<IFormFile> files,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var campaign = await _context.Campaigns
                .Include(c => c.Package)
                .FirstOrDefaultAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);

            if (campaign == null || campaign.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Campaign not found" });

            var photoIds = new List<Guid>();
            var displayOrder = await _context.TeamPhotos
                .Where(p => p.TeamId == campaignId)
                .CountAsync(cancellationToken);

            foreach (var file in files)
            {
                // Route through DocumentService for blob upload + background EXIF/AI extraction
                var uploadResult = await _documentService.UploadDocumentAsync(
                    file, DocumentType.TeamPhoto, packageId, userId);

                // Link to the correct team and set display order
                var photo = await _context.TeamPhotos.FindAsync(uploadResult.DocumentId);
                if (photo != null)
                {
                    photo.TeamId = campaignId;
                    photo.DisplayOrder = displayOrder++;
                    photo.UpdatedAt = DateTime.UtcNow;
                }

                photoIds.Add(uploadResult.DocumentId);
            }

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("{Count} photos added to campaign {CampaignId} via DocumentService", files.Count, campaignId);

            return Ok(new { photoIds, message = $"{files.Count} photos added successfully" });
        }
        catch (ValidationException vex)
        {
            _logger.LogWarning(vex, "Validation error adding photos to campaign {CampaignId}: {Message}", campaignId, vex.Message);
            return BadRequest(new { error = vex.Message, details = vex.Errors });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding photos to campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to add photos" });
        }
    }

    /// <summary>
    /// Backfill EXIF + AI metadata for photos that were uploaded without extraction.
    /// Finds all TeamPhotos in the given package with NULL ExtractedMetadataJson and triggers extraction.
    /// </summary>
    [HttpPost("{packageId}/photos/backfill-extraction")]
    [Authorize(Roles = "Agency,ASM,HQ")]
    public async Task<IActionResult> BackfillPhotoExtraction(
        Guid packageId,
        CancellationToken cancellationToken)
    {
        try
        {
            var photos = await _context.TeamPhotos
                .Where(p => p.PackageId == packageId && !p.IsDeleted && p.ExtractedMetadataJson == null)
                .Select(p => new { p.Id, p.BlobUrl })
                .ToListAsync(cancellationToken);

            if (photos.Count == 0)
                return Ok(new { message = "No photos need extraction backfill.", count = 0 });

            foreach (var photo in photos)
            {
                await _documentService.TriggerPhotoExtractionAsync(photo.Id, photo.BlobUrl);
            }

            _logger.LogInformation("Triggered extraction backfill for {Count} photos in package {PackageId}", photos.Count, packageId);

            return Ok(new { message = $"Extraction triggered for {photos.Count} photos.", count = photos.Count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error backfilling photo extraction for package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to trigger photo extraction backfill." });
        }
    }

    /// <summary>
    /// Upload cost summary for a package (1 per package, stored as separate CostSummary entity)
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/cost-summary")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> UploadCostSummary(
        Guid packageId,
        Guid campaignId,
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .Include(p => p.CostSummary)
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            // Verify campaign belongs to this package
            var campaignExists = await _context.Teams
                .AnyAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);
            if (!campaignExists)
                return NotFound(new { error = "Campaign not found" });

            var blobUrl = await _fileStorage.UploadFileAsync(file, "cost-summaries", $"{Guid.NewGuid()}_{file.FileName}");

            if (package.CostSummary == null)
            {
                var costSummary = new Domain.Entities.CostSummary
                {
                    Id = Guid.NewGuid(),
                    PackageId = packageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    ContentType = file.ContentType,
                    FileSizeBytes = file.Length,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };
                _context.CostSummaries.Add(costSummary);
            }
            else
            {
                package.CostSummary.FileName = file.FileName;
                package.CostSummary.BlobUrl = blobUrl;
                package.CostSummary.ContentType = file.ContentType;
                package.CostSummary.FileSizeBytes = file.Length;
                package.CostSummary.UpdatedAt = DateTime.UtcNow;
            }

            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Cost summary uploaded for package {PackageId}", packageId);

            // Trigger background extraction so extracted fields are populated
            var csEntity = package.CostSummary!;
            var csBlobUrl = csEntity.BlobUrl;
            var csDocId = csEntity.Id;
            _ = Task.Run(async () =>
            {
                try
                {
                    using var scope = _serviceScopeFactory.CreateScope();
                    var agent = scope.ServiceProvider.GetRequiredService<IDocumentAgent>();
                    var ctx = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

                    var costData = await agent.ExtractCostSummaryAsync(csBlobUrl);
                    var json = System.Text.Json.JsonSerializer.Serialize(costData);
                    var confidence = costData.FieldConfidences.Values.Any()
                        ? costData.FieldConfidences.Values.Average() : 0.5;

                    var entity = await ctx.CostSummaries.FindAsync(csDocId);
                    if (entity != null)
                    {
                        entity.ExtractedDataJson = json;
                        entity.ExtractionConfidence = confidence;
                        entity.UpdatedAt = DateTime.UtcNow;

                        var opts = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                        var parsed = System.Text.Json.JsonSerializer.Deserialize<Application.DTOs.Documents.CostSummaryData>(json, opts);
                        if (parsed != null)
                        {
                            entity.PlaceOfSupply = parsed.PlaceOfSupply ?? parsed.State;
                            entity.NumberOfDays = parsed.NumberOfDays;
                            entity.NumberOfActivations = parsed.NumberOfActivations;
                            entity.NumberOfTeams = parsed.NumberOfTeams;
                            if (parsed.TotalCost > 0) entity.TotalCost = parsed.TotalCost;
                            if (parsed.CostBreakdowns?.Count > 0)
                            {
                                entity.ElementWiseCostsJson = System.Text.Json.JsonSerializer.Serialize(
                                    parsed.CostBreakdowns.Select(b => new { b.Category, b.ElementName, b.Amount }));
                                entity.ElementWiseQuantityJson = System.Text.Json.JsonSerializer.Serialize(
                                    parsed.CostBreakdowns.Select(b => new { b.Category, b.Quantity, b.Unit }));
                                // Full breakdown with all fields (cost type flags included)
                                entity.CostBreakdownJson = System.Text.Json.JsonSerializer.Serialize(
                                    parsed.CostBreakdowns.Select(b => new { b.Category, b.ElementName, b.Amount, b.Quantity, b.Unit, b.IsFixedCost, b.IsVariableCost }));
                            }
                        }
                        await ctx.SaveChangesAsync(CancellationToken.None);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Background cost summary extraction failed for {DocId}", csDocId);
                }
            });

            return Ok(new { message = "Cost summary uploaded successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading cost summary for package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to upload cost summary" });
        }
    }

    /// <summary>
    /// Upload activity summary for a package (1 per package, stored as separate ActivitySummary entity)
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/activity-summary")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> UploadActivitySummary(
        Guid packageId,
        Guid campaignId,
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .Include(p => p.ActivitySummary)
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            // Verify campaign belongs to this package
            var campaignExists = await _context.Teams
                .AnyAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);
            if (!campaignExists)
                return NotFound(new { error = "Campaign not found" });

            var blobUrl = await _fileStorage.UploadFileAsync(file, "activity-summaries", $"{Guid.NewGuid()}_{file.FileName}");

            if (package.ActivitySummary == null)
            {
                var activitySummary = new Domain.Entities.ActivitySummary
                {
                    Id = Guid.NewGuid(),
                    PackageId = packageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    ContentType = file.ContentType,
                    FileSizeBytes = file.Length,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                    CreatedBy = userId.ToString(),
                    UpdatedBy = userId.ToString()
                };
                _context.ActivitySummaries.Add(activitySummary);
            }
            else
            {
                package.ActivitySummary.FileName = file.FileName;
                package.ActivitySummary.BlobUrl = blobUrl;
                package.ActivitySummary.ContentType = file.ContentType;
                package.ActivitySummary.FileSizeBytes = file.Length;
                package.ActivitySummary.UpdatedAt = DateTime.UtcNow;
                package.ActivitySummary.UpdatedBy = userId.ToString();
            }

            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Activity summary uploaded for package {PackageId}", packageId);

            // Trigger background extraction so extracted fields are populated
            var actEntity = package.ActivitySummary!;
            var actBlobUrl = actEntity.BlobUrl;
            var actDocId = actEntity.Id;
            _ = Task.Run(async () =>
            {
                try
                {
                    using var scope = _serviceScopeFactory.CreateScope();
                    var agent = scope.ServiceProvider.GetRequiredService<IDocumentAgent>();
                    var ctx = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

                    var activityData = await agent.ExtractActivityAsync(actBlobUrl);
                    var json = System.Text.Json.JsonSerializer.Serialize(activityData);
                    var confidence = activityData.FieldConfidences.Values.Any()
                        ? activityData.FieldConfidences.Values.Average() : 0.5;

                    var entity = await ctx.ActivitySummaries.FindAsync(actDocId);
                    if (entity != null)
                    {
                        entity.ExtractedDataJson = json;
                        entity.ExtractionConfidence = confidence;
                        entity.IsFlaggedForReview = activityData.IsFlaggedForReview;
                        entity.UpdatedAt = DateTime.UtcNow;

                        var opts = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                        var parsed = System.Text.Json.JsonSerializer.Deserialize<Application.DTOs.Documents.ActivityData>(json, opts);
                        if (parsed?.Rows != null && parsed.Rows.Count > 0)
                        {
                            entity.DealerName = parsed.Rows[0].DealerName;
                            entity.TotalDays = parsed.Rows.Sum(r => r.Day);
                            entity.TotalWorkingDays = parsed.Rows.Sum(r => r.WorkingDay);
                            // Build a brief activity description from extracted locations
                            var locations = parsed.Rows
                                .Where(r => !string.IsNullOrWhiteSpace(r.Location))
                                .Select(r => r.Location)
                                .Distinct()
                                .ToList();
                            if (locations.Any())
                            {
                                entity.ActivityDescription = $"Activity across {locations.Count} location(s): {string.Join(", ", locations)}";
                            }
                        }
                        await ctx.SaveChangesAsync(CancellationToken.None);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Background activity summary extraction failed for {DocId}", actDocId);
                }
            });

            return Ok(new { message = "Activity summary uploaded successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading activity summary for package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to upload activity summary" });
        }
    }

    /// <summary>
    /// Upload enquiry document for a package (1 per package - Additional docs at PO level)
    /// </summary>
    [HttpPost("{packageId}/enquiry-doc")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> UploadEnquiryDoc(
        Guid packageId,
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .Include(p => p.EnquiryDocument)
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            var blobUrl = await _fileStorage.UploadFileAsync(file, "enquiry-docs", $"{Guid.NewGuid()}_{file.FileName}");

            // Create or update EnquiryDocument entity
            if (package.EnquiryDocument == null)
            {
                var enquiryDoc = new Domain.Entities.EnquiryDocument
                {
                    Id = Guid.NewGuid(),
                    PackageId = packageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    ContentType = file.ContentType,
                    FileSizeBytes = file.Length,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                    CreatedBy = userId.ToString(),
                    UpdatedBy = userId.ToString()
                };
                _context.EnquiryDocuments.Add(enquiryDoc);
            }
            else
            {
                package.EnquiryDocument.FileName = file.FileName;
                package.EnquiryDocument.BlobUrl = blobUrl;
                package.EnquiryDocument.ContentType = file.ContentType;
                package.EnquiryDocument.FileSizeBytes = file.Length;
                package.EnquiryDocument.UpdatedAt = DateTime.UtcNow;
                package.EnquiryDocument.UpdatedBy = userId.ToString();
            }

            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Enquiry document uploaded for package {PackageId}", packageId);

            // Trigger background extraction
            var enqEntity = package.EnquiryDocument!;
            var enqBlobUrl = enqEntity.BlobUrl;
            var enqDocId = enqEntity.Id;
            _ = Task.Run(async () =>
            {
                try
                {
                    using var scope = _serviceScopeFactory.CreateScope();
                    var agent = scope.ServiceProvider.GetRequiredService<IDocumentAgent>();
                    var ctx = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

                    var enquiryData = await agent.ExtractEnquiryDumpAsync(enqBlobUrl);
                    var json = System.Text.Json.JsonSerializer.Serialize(enquiryData);
                    var confidence = enquiryData.FieldConfidences.Values.Any()
                        ? enquiryData.FieldConfidences.Values.Average() : 0.5;

                    var entity = await ctx.EnquiryDocuments.FindAsync(enqDocId);
                    if (entity != null)
                    {
                        entity.ExtractedDataJson = json;
                        entity.ExtractionConfidence = confidence;
                        entity.IsFlaggedForReview = enquiryData.IsFlaggedForReview;
                        entity.UpdatedAt = DateTime.UtcNow;
                        await ctx.SaveChangesAsync(CancellationToken.None);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Background enquiry doc extraction failed for {DocId}", enqDocId);
                }
            });

            return Ok(new { message = "Enquiry document uploaded successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading enquiry document for package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to upload enquiry document" });
        }
    }

    /// <summary>
    /// Get hierarchical structure for a package
    /// </summary>
    [HttpGet("{packageId}/structure")]
    public async Task<IActionResult> GetHierarchicalStructure(Guid packageId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

            var package = await _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices.Where(i => !i.IsDeleted))
                .Include(p => p.EnquiryDocument)
                .Include(p => p.CostSummary)
                .Include(p => p.ActivitySummary)
                .Include(p => p.Teams)
                    .ThenInclude(c => c.Photos)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            if (userRole == "Agency" && package.SubmittedByUserId != userId)
                return NotFound(new { error = "Package not found" });

            var response = new HierarchicalStructureResponse
            {
                PackageId = package.Id,
                State = package.State.ToString(),
                CreatedAt = package.CreatedAt,
                PO = package.PO != null ? new POInfo
                {
                    DocumentId = package.PO.Id,
                    FileName = package.PO.FileName,
                    ExtractedData = package.PO.ExtractedDataJson
                } : null,
                EnquiryDoc = package.EnquiryDocument != null ? new EnquiryDocInfo
                {
                    FileName = package.EnquiryDocument.FileName,
                    BlobUrl = package.EnquiryDocument.BlobUrl
                } : null,
                Invoices = package.Invoices.Where(i => !i.IsDeleted).Select(i => new InvoiceInfo
                {
                    InvoiceId = i.Id,
                    InvoiceNumber = i.InvoiceNumber,
                    InvoiceDate = i.InvoiceDate,
                    TotalAmount = i.TotalAmount,
                    FileName = i.FileName
                }).ToList(),
                Campaigns = package.Teams.Select(c => new CampaignInfo
                {
                    CampaignId = c.Id,
                    CampaignName = c.CampaignName,
                    TeamCode = c.TeamCode,
                    StartDate = c.StartDate,
                    EndDate = c.EndDate,
                    WorkingDays = c.WorkingDays,
                    DealershipName = c.DealershipName,
                    TotalCost = package.CostSummary?.TotalCost,
                    CostSummaryFileName = package.CostSummary?.FileName,
                    ActivitySummaryFileName = package.ActivitySummary?.FileName,
                    Photos = c.Photos.OrderBy(p => p.DisplayOrder).Select(p => new PhotoInfo
                    {
                        PhotoId = p.Id,
                        FileName = p.FileName,
                        BlobUrl = p.BlobUrl,
                        PhotoTimestamp = p.PhotoTimestamp
                    }).ToList()
                }).ToList()
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting hierarchical structure for package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to get package structure" });
        }
    }

    /// <summary>
    /// Delete a campaign and all its invoices/photos
    /// </summary>
    [HttpDelete("{packageId}/campaigns/{campaignId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeleteCampaign(Guid packageId, Guid campaignId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var campaign = await _context.Campaigns
                .Include(c => c.Package)
                .FirstOrDefaultAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);

            if (campaign == null || campaign.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Campaign not found" });

            campaign.IsDeleted = true;
            campaign.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Campaign {CampaignId} deleted from package {PackageId}", campaignId, packageId);

            return Ok(new { message = "Campaign deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to delete campaign" });
        }
    }

    /// <summary>
    /// Delete an invoice from a package
    /// </summary>
    [HttpDelete("{packageId}/invoices/{invoiceId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeleteInvoice(Guid packageId, Guid invoiceId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var invoice = await _context.Invoices
                .Include(i => i.Package)
                .FirstOrDefaultAsync(i => i.Id == invoiceId && i.PackageId == packageId, cancellationToken);

            if (invoice == null || invoice.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Invoice not found" });

            invoice.IsDeleted = true;
            invoice.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Invoice {InvoiceId} deleted from package {PackageId}", invoiceId, packageId);

            return Ok(new { message = "Invoice deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting invoice {InvoiceId}", invoiceId);
            return StatusCode(500, new { error = "Failed to delete invoice" });
        }
    }

    /// <summary>
    /// Delete a photo from a campaign
    /// </summary>
    [HttpDelete("{packageId}/campaigns/{campaignId}/photos/{photoId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeletePhoto(Guid packageId, Guid campaignId, Guid photoId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var photo = await _context.TeamPhotos
                .Include(p => p.Package)
                .FirstOrDefaultAsync(p => p.Id == photoId && p.TeamId == campaignId && p.PackageId == packageId, cancellationToken);

            if (photo == null || photo.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Photo not found" });

            photo.IsDeleted = true;
            photo.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Photo {PhotoId} deleted from campaign {CampaignId}", photoId, campaignId);

            return Ok(new { message = "Photo deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting photo {PhotoId}", photoId);
            return StatusCode(500, new { error = "Failed to delete photo" });
        }
    }

    /// <summary>
    /// Batch delete photos from a campaign (multi-select)
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/photos/batch-delete")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> BatchDeletePhotos(
        Guid packageId,
        Guid campaignId,
        [FromBody] BatchDeleteRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();

            var campaign = await _context.Campaigns
                .Include(c => c.Package)
                .FirstOrDefaultAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);

            if (campaign == null || campaign.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Campaign not found" });

            if (request.Ids == null || request.Ids.Count == 0)
                return BadRequest(new { error = "No photo IDs provided" });

            var photos = await _context.TeamPhotos
                .Where(p => request.Ids.Contains(p.Id) && p.TeamId == campaignId && p.PackageId == packageId && !p.IsDeleted)
                .ToListAsync(cancellationToken);

            foreach (var photo in photos)
            {
                photo.IsDeleted = true;
                photo.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("{Count} photos batch-deleted from campaign {CampaignId}", photos.Count, campaignId);

            return Ok(new { deletedCount = photos.Count, message = $"{photos.Count} photo(s) deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error batch-deleting photos from campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to delete photos" });
        }
    }

    /// <summary>
    /// Batch delete invoices from a package (multi-select)
    /// </summary>
    [HttpPost("{packageId}/invoices/batch-delete")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> BatchDeleteInvoices(
        Guid packageId,
        [FromBody] BatchDeleteRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();

            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            if (request.Ids == null || request.Ids.Count == 0)
                return BadRequest(new { error = "No invoice IDs provided" });

            var invoices = await _context.Invoices
                .Where(i => request.Ids.Contains(i.Id) && i.PackageId == packageId && !i.IsDeleted)
                .ToListAsync(cancellationToken);

            foreach (var invoice in invoices)
            {
                invoice.IsDeleted = true;
                invoice.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("{Count} invoices batch-deleted from package {PackageId}", invoices.Count, packageId);

            return Ok(new { deletedCount = invoices.Count, message = $"{invoices.Count} invoice(s) deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error batch-deleting invoices from package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to delete invoices" });
        }
    }

    /// <summary>
    /// Remove cost summary or activity summary from a campaign
    /// </summary>
    [HttpDelete("{packageId}/campaigns/{campaignId}/{docType}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> RemoveCampaignDocument(
        Guid packageId,
        Guid campaignId,
        string docType,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();

            var package = await _context.DocumentPackages
                .Include(p => p.CostSummary)
                .Include(p => p.ActivitySummary)
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            // Verify campaign belongs to this package
            var campaignExists = await _context.Teams
                .AnyAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);
            if (!campaignExists)
                return NotFound(new { error = "Campaign not found" });

            if (docType.Equals("cost-summary", StringComparison.OrdinalIgnoreCase))
            {
                if (package.CostSummary != null)
                {
                    package.CostSummary.IsDeleted = true;
                    package.CostSummary.UpdatedAt = DateTime.UtcNow;
                }
            }
            else if (docType.Equals("activity-summary", StringComparison.OrdinalIgnoreCase))
            {
                if (package.ActivitySummary != null)
                {
                    package.ActivitySummary.IsDeleted = true;
                    package.ActivitySummary.UpdatedAt = DateTime.UtcNow;
                }
            }
            else
            {
                return BadRequest(new { error = "Invalid document type. Use 'cost-summary' or 'activity-summary'." });
            }

            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("{DocType} removed from campaign {CampaignId}", docType, campaignId);

            return Ok(new { message = $"{docType} removed successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing {DocType} from campaign {CampaignId}", docType, campaignId);
            return StatusCode(500, new { error = $"Failed to remove {docType}" });
        }
    }

    /// <summary>
    /// Download an invoice file
    /// </summary>
    [HttpGet("invoices/{invoiceId}/download")]
    public async Task<IActionResult> DownloadInvoice(Guid invoiceId, CancellationToken cancellationToken)
    {
        try
        {
            var invoice = await _context.Invoices
                .AsNoTracking()
                .FirstOrDefaultAsync(i => i.Id == invoiceId, cancellationToken);

            if (invoice == null || string.IsNullOrEmpty(invoice.BlobUrl))
                return NotFound(new { message = "Invoice not found" });

            var fileBytes = await _fileStorage.GetFileBytesAsync(invoice.BlobUrl);
            var base64Content = Convert.ToBase64String(fileBytes);

            return Ok(new
            {
                base64Content,
                filename = invoice.FileName,
                contentType = !string.IsNullOrEmpty(invoice.ContentType) ? invoice.ContentType : "application/octet-stream",
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading invoice {InvoiceId}", invoiceId);
            return StatusCode(500, new { message = "Failed to download invoice" });
        }
    }

    /// <summary>
    /// Download a campaign photo file
    /// </summary>
    [HttpGet("photos/{photoId}/download")]
    public async Task<IActionResult> DownloadPhoto(Guid photoId, CancellationToken cancellationToken)
    {
        try
        {
            var photo = await _context.TeamPhotos
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == photoId, cancellationToken);

            if (photo == null || string.IsNullOrEmpty(photo.BlobUrl))
                return NotFound(new { message = "Photo not found" });

            var fileBytes = await _fileStorage.GetFileBytesAsync(photo.BlobUrl);
            var base64Content = Convert.ToBase64String(fileBytes);

            return Ok(new
            {
                base64Content,
                filename = photo.FileName,
                contentType = !string.IsNullOrEmpty(photo.ContentType) ? photo.ContentType : "application/octet-stream",
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading photo {PhotoId}", photoId);
            return StatusCode(500, new { message = "Failed to download photo" });
        }
    }

    /// <summary>
    /// Download cost summary or activity summary for a package
    /// </summary>
    [HttpGet("campaigns/{campaignId}/download/{docType}")]
    public async Task<IActionResult> DownloadCampaignSummary(
        Guid campaignId,
        string docType,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get the package via the campaign/team
            var team = await _context.Teams
                .AsNoTracking()
                .FirstOrDefaultAsync(c => c.Id == campaignId, cancellationToken);

            if (team == null)
                return NotFound(new { message = "Campaign not found" });

            string? blobUrl;
            string? fileName;
            string? contentType;

            if (docType.Equals("cost-summary", StringComparison.OrdinalIgnoreCase))
            {
                var costSummary = await _context.CostSummaries
                    .AsNoTracking()
                    .FirstOrDefaultAsync(cs => cs.PackageId == team.PackageId && !cs.IsDeleted, cancellationToken);
                blobUrl = costSummary?.BlobUrl;
                fileName = costSummary?.FileName;
                contentType = costSummary?.ContentType;
            }
            else if (docType.Equals("activity-summary", StringComparison.OrdinalIgnoreCase))
            {
                var activitySummary = await _context.ActivitySummaries
                    .AsNoTracking()
                    .FirstOrDefaultAsync(a => a.PackageId == team.PackageId && !a.IsDeleted, cancellationToken);
                blobUrl = activitySummary?.BlobUrl;
                fileName = activitySummary?.FileName;
                contentType = activitySummary?.ContentType;
            }
            else
            {
                return BadRequest(new { message = "Invalid document type. Use 'cost-summary' or 'activity-summary'." });
            }

            if (string.IsNullOrEmpty(blobUrl))
                return NotFound(new { message = $"{docType} not found for this campaign" });

            var fileBytes = await _fileStorage.GetFileBytesAsync(blobUrl);
            var base64Content = Convert.ToBase64String(fileBytes);

            return Ok(new
            {
                base64Content,
                filename = fileName ?? "document",
                contentType = !string.IsNullOrEmpty(contentType) ? contentType : "application/octet-stream",
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading {DocType} for campaign {CampaignId}", docType, campaignId);
            return StatusCode(500, new { message = $"Failed to download {docType}" });
        }
    }

    /// <summary>
    /// Get invoice details by ID (for polling after upload to check extraction status)
    /// </summary>
    [HttpGet("invoices/{invoiceId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> GetInvoiceDetails(Guid invoiceId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var invoice = await _context.Invoices
                .Include(i => i.Package)
                .FirstOrDefaultAsync(i => i.Id == invoiceId && !i.IsDeleted, cancellationToken);

            if (invoice == null || invoice.Package?.SubmittedByUserId != userId)
                return NotFound(new { error = "Invoice not found" });

            return Ok(new
            {
                id = invoice.Id,
                invoiceNumber = invoice.InvoiceNumber,
                invoiceDate = invoice.InvoiceDate,
                vendorName = invoice.VendorName,
                gstNumber = invoice.GSTNumber,
                totalAmount = invoice.TotalAmount,
                fileName = invoice.FileName,
                blobUrl = invoice.BlobUrl,
                // Extraction status: if all fields are filled, extraction is complete
                extractionComplete = !string.IsNullOrEmpty(invoice.InvoiceNumber) && 
                                   invoice.TotalAmount != null && 
                                   invoice.TotalAmount > 0
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting invoice details {InvoiceId}", invoiceId);
            return StatusCode(500, new { error = "Failed to get invoice details" });
        }
    }


    private Guid GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(userIdClaim))
            throw new System.UnauthorizedAccessException("User ID not found in token");
        return Guid.Parse(userIdClaim);
    }
}

// Request DTOs
public class BatchDeleteRequest
{
    public List<Guid> Ids { get; set; } = new();
}

public class AddInvoiceRequest
{
    public IFormFile? File { get; set; }
    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public string? VendorName { get; set; }
    public string? GSTNumber { get; set; }
    public decimal? TotalAmount { get; set; }
}

public class AddCampaignRequest
{
    public string? CampaignName { get; set; }
    public string? TeamCode { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? WorkingDays { get; set; }
    public string? DealershipName { get; set; }
    public string? DealershipAddress { get; set; }
    public string? GPSLocation { get; set; }
    public string? State { get; set; }
    public decimal? TotalCost { get; set; }
}

// Response DTOs
public class HierarchicalStructureResponse
{
    public Guid PackageId { get; set; }
    public string State { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public POInfo? PO { get; set; }
    public EnquiryDocInfo? EnquiryDoc { get; set; }
    public List<InvoiceInfo> Invoices { get; set; } = new();
    public List<CampaignInfo> Campaigns { get; set; } = new();
}

public class POInfo
{
    public Guid DocumentId { get; set; }
    public string FileName { get; set; } = "";
    public string? ExtractedData { get; set; }
}

public class EnquiryDocInfo
{
    public string? FileName { get; set; }
    public string? BlobUrl { get; set; }
}

public class CampaignInfo
{
    public Guid CampaignId { get; set; }
    public string? CampaignName { get; set; }
    public string? TeamCode { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? WorkingDays { get; set; }
    public string? DealershipName { get; set; }
    public decimal? TotalCost { get; set; }
    public string? CostSummaryFileName { get; set; }
    public string? ActivitySummaryFileName { get; set; }
    public List<PhotoInfo> Photos { get; set; } = new();
}

public class InvoiceInfo
{
    public Guid InvoiceId { get; set; }
    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public decimal? TotalAmount { get; set; }
    public string FileName { get; set; } = "";
}

public class PhotoInfo
{
    public Guid PhotoId { get; set; }
    public string FileName { get; set; } = "";
    public string BlobUrl { get; set; } = "";
    public DateTime? PhotoTimestamp { get; set; }
}
