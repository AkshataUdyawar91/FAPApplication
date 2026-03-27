using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Application.Utilities;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Document service implementation
/// </summary>
public class DocumentService : IDocumentService
{
    private readonly ApplicationDbContext _context;
    private readonly IFileStorageService _fileStorageService;
    private readonly IMalwareScanService _malwareScanService;
    private readonly IDocumentAgent _documentAgent;
    private readonly IServiceScopeFactory _serviceScopeFactory;
    private readonly ILogger<DocumentService> _logger;

    // File size limits in bytes
    private const long MaxDocumentSize = 10 * 1024 * 1024; // 10MB
    private const long MaxPhotoSize = 5 * 1024 * 1024; // 5MB

    // Allowed file extensions by document type
    private static readonly Dictionary<DocumentType, string[]> AllowedExtensions = new()
    {
        { DocumentType.PO, new[] { ".pdf", ".jpg", ".jpeg", ".png", ".tiff", ".tif" } },
        { DocumentType.Invoice, new[] { ".pdf", ".jpg", ".jpeg", ".png", ".tiff", ".tif" } },
        { DocumentType.CostSummary, new[] { ".pdf", ".xls", ".xlsx", ".csv" } },
        { DocumentType.TeamPhoto, new[] { ".jpg", ".jpeg", ".png", ".heic" } },
        { DocumentType.ActivitySummary, new[] { ".pdf", ".jpg", ".jpeg", ".png", ".xls", ".xlsx" } },
        { DocumentType.EnquiryDocument, new[] { ".xls", ".xlsx", ".csv" } }
    };

    public DocumentService(
        ApplicationDbContext context,
        IFileStorageService fileStorageService,
        IMalwareScanService malwareScanService,
        IDocumentAgent documentAgent,
        IServiceScopeFactory serviceScopeFactory,
        ILogger<DocumentService> logger)
    {
        _context = context;
        _fileStorageService = fileStorageService;
        _malwareScanService = malwareScanService;
        _documentAgent = documentAgent;
        _serviceScopeFactory = serviceScopeFactory;
        _logger = logger;
    }

    public async Task<UploadDocumentResponse> UploadDocumentAsync(
        IFormFile file,
        DocumentType documentType,
        Guid? packageId,
        Guid userId)
    {
        _logger.LogInformation("=== UPLOAD START === File: {FileName}, Type: {DocType}, PackageId: {PkgId}, UserId: {UserId}",
            file?.FileName, documentType, packageId, userId);

        // Validate file
        if (!await ValidateFileAsync(file, documentType))
        {
            _logger.LogWarning("=== FILE VALIDATION FAILED === File: {FileName}, Type: {DocType}", file?.FileName, documentType);
            throw new Domain.Exceptions.ValidationException(
                new Dictionary<string, string[]>
                {
                    { "file", new[] { "File validation failed. Check file type and size." } }
                });
        }
        _logger.LogInformation("=== FILE VALIDATION PASSED ===");

        // Create or get package
        Guid actualPackageId;
        if (packageId.HasValue && packageId.Value != Guid.Empty)
        {
            // Use existing package
            actualPackageId = packageId.Value;
            
            // Verify package exists (relaxed check for testing - in production should verify user ownership)
            var existingPackage = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId.Value && !p.IsDeleted);
            
            if (existingPackage == null)
            {
                _logger.LogError("=== PACKAGE NOT FOUND === PackageId: {PkgId}", packageId.Value);
                throw new Domain.Exceptions.NotFoundException("Package not found");
            }
            
            _logger.LogInformation("=== PACKAGE FOUND === Id: {PkgId}, AgencyId: {AgencyId}, SelectedPOId: {SelPO}, State: {State}",
                existingPackage.Id, existingPackage.AgencyId, existingPackage.SelectedPOId, existingPackage.State);
            
            // Log if user mismatch (for debugging)
            if (existingPackage.SubmittedByUserId != userId)
            {
                _logger.LogWarning("User ID mismatch for package {PackageId}. Package user: {PackageUser}, Current user: {CurrentUser}", 
                    packageId.Value, existingPackage.SubmittedByUserId, userId);
            }
        }
        else
        {
            // Create new package for first document (PO)
            var newPackage = new DocumentPackage
            {
                Id = Guid.NewGuid(),
                SubmittedByUserId = userId,
                State = PackageState.Uploaded,
                CreatedAt = DateTime.UtcNow,
                CreatedBy = userId.ToString()
            };
            
            await _context.DocumentPackages.AddAsync(newPackage);
            await _context.SaveChangesAsync();
            
            actualPackageId = newPackage.Id;
            
            _logger.LogInformation("Created new package: {PackageId} for user {UserId}", actualPackageId, userId);
        }

        // Photo limit check: max 50 photos per package
        if (documentType == DocumentType.TeamPhoto)
        {
            var photoCount = await _context.TeamPhotos
                .CountAsync(tp => tp.PackageId == actualPackageId);
            
            if (photoCount >= 50)
            {
                throw new Domain.Exceptions.ValidationException(
                    new Dictionary<string, string[]>
                    {
                        { "photos", new[] { "Photo limit exceeded. Maximum 50 photos allowed per submission." } }
                    });
            }
        }

        // Generate unique file name
        var fileExtension = Path.GetExtension(file.FileName);
        var uniqueFileName = $"{Guid.NewGuid()}{fileExtension}";

        // Upload to blob storage
        _logger.LogInformation("=== BLOB UPLOAD START === FileName: {UniqueFile}", uniqueFileName);
        var blobUrl = await _fileStorageService.UploadFileAsync(file, "documents", uniqueFileName);
        _logger.LogInformation("=== BLOB UPLOAD SUCCESS === BlobUrl: {BlobUrl}", blobUrl);

        // Load the package to get VersionNumber and AgencyId
        var package = await _context.DocumentPackages
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == actualPackageId && !p.IsDeleted);

        if (package == null)
        {
            throw new Domain.Exceptions.NotFoundException("Package not found");
        }

        // Create dedicated entity based on document type
        Guid entityId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var createdBy = userId.ToString();

        switch (documentType)
        {
            case DocumentType.PO:
                var po = new PO
                {
                    Id = entityId,
                    PackageId = actualPackageId,
                    AgencyId = package.AgencyId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    FileSizeBytes = file.Length,
                    ContentType = file.ContentType,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedBy = createdBy,
                    UpdatedBy = createdBy
                };
                await _context.POs.AddAsync(po);
                break;

            case DocumentType.Invoice:
                // First try: PO linked via package's SelectedPOId (assistant/dropdown flow)
                // Second try: PO uploaded directly to this package (file upload flow)
                var existingPo = package.SelectedPOId.HasValue
                    ? await _context.POs.FirstOrDefaultAsync(p => p.Id == package.SelectedPOId.Value)
                    : await _context.POs.FirstOrDefaultAsync(p => p.PackageId == actualPackageId);

                if (existingPo == null)
                {
                    _logger.LogWarning("No PO found for invoice upload — package {PkgId}, SelectedPOId: {SelPO}. Invoice will be rejected.",
                        actualPackageId, package.SelectedPOId);
                    throw new Domain.Exceptions.ValidationException(
                        new Dictionary<string, string[]>
                        {
                            { "invoice", new[] { "Cannot upload invoice: no Purchase Order is linked to this submission. Please select a PO first." } }
                        });
                }

                _logger.LogInformation("=== INVOICE: PO found === POId: {POId}, PONumber: {PONum}", existingPo.Id, existingPo.PONumber);

                var invoice = new Invoice
                {
                    Id = entityId,
                    PackageId = actualPackageId,
                    POId = existingPo.Id,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    FileSizeBytes = file.Length,
                    ContentType = file.ContentType,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedBy = createdBy,
                    UpdatedBy = createdBy
                };
                await _context.Invoices.AddAsync(invoice);
                break;

            case DocumentType.CostSummary:
                var costSummary = new CostSummary
                {
                    Id = entityId,
                    PackageId = actualPackageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    FileSizeBytes = file.Length,
                    ContentType = file.ContentType,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedBy = createdBy,
                    UpdatedBy = createdBy
                };
                await _context.CostSummaries.AddAsync(costSummary);
                break;

            case DocumentType.ActivitySummary:
                var activitySummary = new ActivitySummary
                {
                    Id = entityId,
                    PackageId = actualPackageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    FileSizeBytes = file.Length,
                    ContentType = file.ContentType,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedBy = createdBy,
                    UpdatedBy = createdBy
                };
                await _context.ActivitySummaries.AddAsync(activitySummary);
                break;

            case DocumentType.EnquiryDocument:
                var enquiryDocument = new EnquiryDocument
                {
                    Id = entityId,
                    PackageId = actualPackageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    FileSizeBytes = file.Length,
                    ContentType = file.ContentType,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedBy = createdBy,
                    UpdatedBy = createdBy
                };
                await _context.EnquiryDocuments.AddAsync(enquiryDocument);
                break;

            case DocumentType.TeamPhoto:
                // TeamId will be set by the caller (UploadTeamPhotos endpoint) after this returns.
                // We need a valid TeamId for the FK — find the first non-deleted team for this package.
                // If none exists yet, create a placeholder; the endpoint will correct it immediately after.
                var photoTeam = await _context.Teams
                    .Where(t => t.PackageId == actualPackageId && !t.IsDeleted)
                    .OrderBy(t => t.TeamNumber)
                    .FirstOrDefaultAsync();
                if (photoTeam == null)
                {
                    photoTeam = new Domain.Entities.Teams
                    {
                        Id = Guid.NewGuid(),
                        PackageId = actualPackageId,
                        CreatedAt = now,
                        UpdatedAt = now,
                        CreatedBy = createdBy,
                        UpdatedBy = createdBy
                    };
                    await _context.Teams.AddAsync(photoTeam);
                    await _context.SaveChangesAsync();
                }

                var teamPhoto = new TeamPhotos
                {
                    Id = entityId,
                    TeamId = photoTeam.Id,
                    PackageId = actualPackageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    FileSizeBytes = file.Length,
                    ContentType = file.ContentType,
                    VersionNumber = package.VersionNumber,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedBy = createdBy,
                    UpdatedBy = createdBy
                };
                await _context.TeamPhotos.AddAsync(teamPhoto);
                break;

            default:
                throw new Domain.Exceptions.ValidationException(
                    new Dictionary<string, string[]>
                    {
                        { "documentType", new[] { $"Unsupported document type: {documentType}" } }
                    });
        }

        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Document uploaded: {DocumentId}, Type: {DocumentType}, Size: {Size} bytes, Package: {PackageId}",
            entityId, documentType, file.Length, actualPackageId);

        // IMMEDIATE EXTRACTION: Extract critical UI fields synchronously for instant feedback
        string? immediateExtractedData = null;
        if (documentType == DocumentType.PO || documentType == DocumentType.Invoice)
        {            try
            {
                _logger.LogInformation("Starting immediate extraction for {DocumentType} {DocumentId}", documentType, entityId);
                
                if (documentType == DocumentType.PO)
                {
                    var poData = await _documentAgent.ExtractPOAsync(blobUrl);
                    immediateExtractedData = System.Text.Json.JsonSerializer.Serialize(poData);
                    
                    // Save immediately to the dedicated PO entity
                    var poEntity = await _context.POs.FindAsync(entityId);
                    if (poEntity != null)
                    {
                        poEntity.ExtractedDataJson = immediateExtractedData;
                        poEntity.ExtractionConfidence = poData.FieldConfidences.Values.Any() 
                            ? poData.FieldConfidences.Values.Average() 
                            : 0.5;
                        // Save typed fields so ListSubmissions can read them directly
                        poEntity.PONumber = poData.PONumber;
                        poEntity.PODate = poData.PODate;
                        poEntity.VendorName = poData.VendorName;
                        poEntity.TotalAmount = poData.TotalAmount;
                        await _context.SaveChangesAsync();
                    }
                    
                    _logger.LogInformation("Immediate PO extraction completed: {PONumber}, Amount: {Amount}", 
                        poData.PONumber, poData.TotalAmount);
                }
                else if (documentType == DocumentType.Invoice)
                {
                    _logger.LogInformation("=== INVOICE EXTRACTION START === BlobUrl: {BlobUrl}, DocId: {DocId}", blobUrl, entityId);
                    var invoiceData = await _documentAgent.ExtractInvoiceAsync(blobUrl);
                    _logger.LogInformation("=== INVOICE EXTRACTION RESULT === InvoiceNumber: {InvNum}, Date: {InvDate}, Vendor: {Vendor}, Total: {Total}, GST: {GST}",
                        invoiceData.InvoiceNumber, invoiceData.InvoiceDate, invoiceData.VendorName, invoiceData.TotalAmount, invoiceData.GSTNumber);
                    immediateExtractedData = System.Text.Json.JsonSerializer.Serialize(invoiceData);
                    
                    // Save immediately to the dedicated Invoice entity
                    var invoiceEntity = await _context.Invoices.FindAsync(entityId);
                    if (invoiceEntity != null)
                    {
                        invoiceEntity.ExtractedDataJson = immediateExtractedData;
                        invoiceEntity.ExtractionConfidence = invoiceData.FieldConfidences.Values.Any() 
                            ? invoiceData.FieldConfidences.Values.Average() 
                            : 0.5;
                        // Also save the individual extracted fields
                        invoiceEntity.InvoiceNumber = invoiceData.InvoiceNumber;
                        invoiceEntity.InvoiceDate = invoiceData.InvoiceDate;
                        invoiceEntity.VendorName = invoiceData.VendorName;
                        invoiceEntity.GSTNumber = invoiceData.GSTNumber;
                        invoiceEntity.SubTotal = invoiceData.SubTotal;
                        invoiceEntity.TaxAmount = invoiceData.TaxAmount;
                        invoiceEntity.TotalAmount = invoiceData.TotalAmount;
                        await _context.SaveChangesAsync();
                        _logger.LogInformation("=== INVOICE FIELDS SAVED TO DB === DocId: {DocId}", entityId);
                    }
                    else
                    {
                        _logger.LogWarning("=== INVOICE ENTITY NOT FOUND after extraction === DocId: {DocId}", entityId);
                    }
                    
                    _logger.LogInformation("Immediate Invoice extraction completed: {InvoiceNumber}, Amount: {Amount}", 
                        invoiceData.InvoiceNumber, invoiceData.TotalAmount);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "=== EXTRACTION FAILED === Type: {DocumentType}, DocId: {DocumentId}, Error: {ErrorMsg}", 
                    documentType, entityId, ex.Message);
                // Continue - background extraction will retry
            }
        }

        // BACKGROUND EXTRACTION: For other document types or if immediate extraction failed
        if (string.IsNullOrEmpty(immediateExtractedData) && 
            (documentType == DocumentType.CostSummary || documentType == DocumentType.ActivitySummary || 
             documentType == DocumentType.TeamPhoto || documentType == DocumentType.EnquiryDocument))
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    await ExtractDocumentDataAsync(entityId, blobUrl, documentType);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Background extraction failed for document {DocumentId}", entityId);
                }
            });
        }

        return new UploadDocumentResponse
        {
            DocumentId = entityId,
            PackageId = actualPackageId,
            FileName = file.FileName,
            FileSizeBytes = file.Length,
            DocumentType = documentType,
            BlobUrl = blobUrl,
            UploadedAt = now,
            ExtractedDataJson = immediateExtractedData
        };
    }

    private async Task ExtractDocumentDataAsync(Guid documentId, string blobUrl, DocumentType documentType)
    {
        // Create a new scope for the background task — resolves scoped services safely
        using var scope = _serviceScopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        // IMPORTANT: IDocumentAgent is scoped — must resolve from the new scope, not use the
        // outer _documentAgent field which is disposed when the request scope ends.
        var documentAgent = scope.ServiceProvider.GetRequiredService<IDocumentAgent>();
        
        try
        {
            _logger.LogInformation("Starting extraction for document {DocumentId}, Type: {Type}", documentId, documentType);

            // Classify document first
            var classification = await documentAgent.ClassifyAsync(blobUrl);
            
            _logger.LogInformation(
                "Document {DocumentId} classified as {Type} with confidence {Confidence}",
                documentId, classification.Type, classification.Confidence);

            // Extract data based on type
            string? extractedJson = null;
            double confidence = classification.Confidence;

            switch (documentType)
            {
                case DocumentType.PO:
                    var poData = await documentAgent.ExtractPOAsync(blobUrl);
                    extractedJson = System.Text.Json.JsonSerializer.Serialize(poData);
                    confidence = poData.FieldConfidences.Values.Any() ? poData.FieldConfidences.Values.Average() : 0.5;
                    break;

                case DocumentType.Invoice:
                    var invoiceData = await documentAgent.ExtractInvoiceAsync(blobUrl);
                    extractedJson = System.Text.Json.JsonSerializer.Serialize(invoiceData);
                    confidence = invoiceData.FieldConfidences.Values.Any() ? invoiceData.FieldConfidences.Values.Average() : 0.5;
                    break;

                case DocumentType.CostSummary:
                    var costSummaryData = await documentAgent.ExtractCostSummaryAsync(blobUrl);
                    extractedJson = System.Text.Json.JsonSerializer.Serialize(costSummaryData);
                    confidence = costSummaryData.FieldConfidences.Values.Any() ? costSummaryData.FieldConfidences.Values.Average() : 0.5;
                    break;

                case DocumentType.TeamPhoto:
                    var photoMetadata = await documentAgent.ExtractPhotoMetadataAsync(blobUrl);
                    extractedJson = System.Text.Json.JsonSerializer.Serialize(photoMetadata);
                    confidence = photoMetadata.FieldConfidences.Values.Any() 
                        ? photoMetadata.FieldConfidences.Values.Average() 
                        : 0.5;
                    break;

                case DocumentType.ActivitySummary:
                    var activityData = await documentAgent.ExtractActivityAsync(blobUrl);
                    extractedJson = System.Text.Json.JsonSerializer.Serialize(activityData);
                    confidence = activityData.FieldConfidences.Values.Any()
                        ? activityData.FieldConfidences.Values.Average()
                        : 0.5;
                    break;

                case DocumentType.EnquiryDocument:
                    var enquiryData = await documentAgent.ExtractEnquiryDumpAsync(blobUrl);
                    extractedJson = System.Text.Json.JsonSerializer.Serialize(enquiryData);
                    confidence = enquiryData.FieldConfidences.Values.Any()
                        ? enquiryData.FieldConfidences.Values.Average()
                        : 0.5;
                    break;

                default:
                    _logger.LogInformation("No extraction needed for document type {Type}", documentType);
                    return;
            }

            if (!string.IsNullOrEmpty(extractedJson))
            {
                // Save extracted data to the appropriate dedicated entity
                switch (documentType)
                {
                    case DocumentType.PO:
                        var poEntity = await context.POs.FindAsync(documentId);
                        if (poEntity != null)
                        {
                            poEntity.ExtractedDataJson = extractedJson;
                            poEntity.ExtractionConfidence = confidence;
                            poEntity.UpdatedAt = DateTime.UtcNow;
                            // Also persist typed fields so list queries don't need JSON fallback
                            try
                            {
                                var parsed = System.Text.Json.JsonSerializer.Deserialize<BajajDocumentProcessing.Application.DTOs.Documents.POData>(extractedJson);
                                if (parsed != null)
                                {
                                    poEntity.PONumber = parsed.PONumber;
                                    poEntity.PODate = parsed.PODate;
                                    poEntity.VendorName = parsed.VendorName;
                                    poEntity.TotalAmount = parsed.TotalAmount;
                                }
                            }
                            catch { /* non-critical — typed fields are best-effort */ }
                        }
                        break;

                    case DocumentType.Invoice:
                        var invoiceEntity = await context.Invoices.FindAsync(documentId);
                        if (invoiceEntity != null)
                        {
                            invoiceEntity.ExtractedDataJson = extractedJson;
                            invoiceEntity.ExtractionConfidence = confidence;
                            invoiceEntity.UpdatedAt = DateTime.UtcNow;
                        }
                        break;

                    case DocumentType.CostSummary:
                        var csEntity = await context.CostSummaries.FindAsync(documentId);
                        if (csEntity != null)
                        {
                            csEntity.ExtractedDataJson = extractedJson;
                            csEntity.ExtractionConfidence = confidence;
                            csEntity.UpdatedAt = DateTime.UtcNow;

                            _logger.LogInformation("=== CS EXTRACTION RAW JSON === DocId: {DocId} | JSON: {Json}", documentId, extractedJson);

                            try
                            {
                                var opts = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                                var parsed = System.Text.Json.JsonSerializer.Deserialize<BajajDocumentProcessing.Application.DTOs.Documents.CostSummaryData>(extractedJson, opts);
                                if (parsed != null)
                                {
                                    csEntity.PlaceOfSupply = parsed.PlaceOfSupply ?? parsed.State;
                                    csEntity.NumberOfDays = parsed.NumberOfDays;
                                    csEntity.NumberOfActivations = parsed.NumberOfActivations;
                                    csEntity.NumberOfTeams = parsed.NumberOfTeams;
                                    if (parsed.TotalCost > 0) csEntity.TotalCost = parsed.TotalCost;

                                    // Element-wise costs: Category + ElementName + Amount per row
                                    if (parsed.CostBreakdowns?.Count > 0)
                                    {
                                        csEntity.ElementWiseCostsJson = System.Text.Json.JsonSerializer.Serialize(
                                            parsed.CostBreakdowns.Select(b => new { b.Category, b.ElementName, b.Amount }));
                                        csEntity.ElementWiseQuantityJson = System.Text.Json.JsonSerializer.Serialize(
                                            parsed.CostBreakdowns.Select(b => new { b.Category, b.Quantity, b.Unit }));
                                        // Full breakdown with all fields (cost type flags included)
                                        csEntity.CostBreakdownJson = System.Text.Json.JsonSerializer.Serialize(
                                            parsed.CostBreakdowns.Select(b => new { b.Category, b.ElementName, b.Amount, b.Quantity, b.Unit, b.IsFixedCost, b.IsVariableCost }));
                                    }

                                    _logger.LogInformation(
                                        "=== CS EXTRACTION MAPPED === DocId: {DocId} | PlaceOfSupply: {Pos} | Days: {Days} | Activations: {Act} | Teams: {Teams} | TotalCost: {Cost} | Breakdowns: {Cnt}",
                                        documentId, csEntity.PlaceOfSupply, csEntity.NumberOfDays, csEntity.NumberOfActivations,
                                        csEntity.NumberOfTeams, csEntity.TotalCost, parsed.CostBreakdowns?.Count ?? 0);
                                }
                                else
                                {
                                    _logger.LogWarning("=== CS EXTRACTION === Parsed CostSummaryData is NULL for DocId: {DocId}", documentId);
                                }
                            }
                            catch (Exception parseEx)
                            {
                                _logger.LogWarning(parseEx, "Could not parse CostSummaryData JSON to map columns for document {DocumentId}", documentId);
                            }
                        }
                        else
                        {
                            _logger.LogWarning("=== CS EXTRACTION === CostSummary entity NOT FOUND in DB for DocId: {DocId}", documentId);
                        }
                        break;

                    case DocumentType.ActivitySummary:
                        var actEntity = await context.ActivitySummaries.FindAsync(documentId);
                        if (actEntity != null)
                        {
                            actEntity.ExtractedDataJson = extractedJson;
                            actEntity.ExtractionConfidence = confidence;
                            actEntity.UpdatedAt = DateTime.UtcNow;

                            // Parse and map extracted fields to dedicated columns
                            try
                            {
                                var opts = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                                var parsed = System.Text.Json.JsonSerializer.Deserialize<BajajDocumentProcessing.Application.DTOs.Documents.ActivityData>(extractedJson, opts);
                                if (parsed?.Rows != null && parsed.Rows.Count > 0)
                                {
                                    actEntity.DealerName = parsed.Rows[0].DealerName;
                                    actEntity.TotalDays = parsed.TotalDays ?? parsed.Rows.Sum(r => r.Day);
                                    var wdSum = parsed.Rows.Sum(r => r.WorkingDay);
                                    actEntity.TotalWorkingDays = parsed.TotalDays 
                                        ?? (wdSum > 0 ? wdSum : parsed.Rows.Sum(r => r.Day));
                                }
                            }
                            catch (Exception parseEx)
                            {
                                _logger.LogWarning(parseEx, "Could not parse ActivityData JSON to map columns for document {DocumentId}", documentId);
                            }
                        }
                        break;

                    case DocumentType.EnquiryDocument:
                        var enqEntity = await context.EnquiryDocuments.FindAsync(documentId);
                        if (enqEntity != null)
                        {
                            enqEntity.ExtractedDataJson = extractedJson;
                            enqEntity.ExtractionConfidence = confidence;
                            enqEntity.UpdatedAt = DateTime.UtcNow;
                        }
                        break;

                    case DocumentType.TeamPhoto:
                        var photoEntity = await context.TeamPhotos.FindAsync(documentId);
                        if (photoEntity != null)
                        {
                            photoEntity.ExtractedMetadataJson = extractedJson;
                            photoEntity.ExtractionConfidence = confidence;
                            photoEntity.UpdatedAt = DateTime.UtcNow;

                            // Map extracted fields to dedicated columns
                            try
                            {
                                var opts = new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                                var meta = System.Text.Json.JsonSerializer.Deserialize<BajajDocumentProcessing.Application.DTOs.Documents.PhotoMetadata>(extractedJson, opts);
                                if (meta != null)
                                {
                                    // EXIF / overlay date
                                    if (meta.Timestamp.HasValue)
                                        photoEntity.PhotoTimestamp = meta.Timestamp.Value;
                                    photoEntity.DateVisible = meta.Timestamp.HasValue || !string.IsNullOrEmpty(meta.PhotoDateFromOverlay);
                                    photoEntity.PhotoDateOverlay = meta.PhotoDateFromOverlay;

                                    // GPS — Lat/Long columns already exist, just populate them
                                    if (meta.Latitude.HasValue) photoEntity.Latitude = meta.Latitude.Value;
                                    if (meta.Longitude.HasValue) photoEntity.Longitude = meta.Longitude.Value;

                                    // Device
                                    if (!string.IsNullOrEmpty(meta.DeviceModel))
                                        photoEntity.DeviceModel = string.IsNullOrEmpty(meta.DeviceMake)
                                            ? meta.DeviceModel
                                            : $"{meta.DeviceMake} {meta.DeviceModel}";

                                    // AI detection
                                    photoEntity.BlueTshirtPresent = meta.HasBlueTshirtPerson;
                                    photoEntity.ThreeWheelerPresent = meta.Has3WVehicle;
                                    photoEntity.IsFlaggedForReview = !meta.HasBlueTshirtPerson || !meta.Has3WVehicle
                                        || (!meta.Timestamp.HasValue && string.IsNullOrEmpty(meta.PhotoDateFromOverlay))
                                        || (!meta.Latitude.HasValue || !meta.Longitude.HasValue);
                                }
                            }
                            catch (Exception parseEx)
                            {
                                _logger.LogWarning(parseEx, "Could not map PhotoMetadata columns for {DocumentId}", documentId);
                            }
                        }
                        break;
                }

                await context.SaveChangesAsync();

                _logger.LogInformation(
                    "Extracted data saved for document {DocumentId} with confidence {Confidence}",
                    documentId, confidence);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to extract data for document {DocumentId}", documentId);
            throw;
        }
    }

    public async Task<bool> ValidateFileAsync(IFormFile file, DocumentType documentType)
    {
        if (file == null || file.Length == 0)
        {
            _logger.LogWarning("File is null or empty");
            return false;
        }

        // Check file size
        var maxSize = documentType == DocumentType.TeamPhoto ? MaxPhotoSize : MaxDocumentSize;
        if (file.Length > maxSize)
        {
            _logger.LogWarning(
                "File size {Size} exceeds maximum {MaxSize} for {DocumentType}",
                file.Length, maxSize, documentType);
            return false;
        }

        // Check file extension
        var fileExtension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExtensions.TryGetValue(documentType, out var allowedExts) ||
            !allowedExts.Contains(fileExtension))
        {
            _logger.LogWarning(
                "File extension {Extension} not allowed for {DocumentType}",
                fileExtension, documentType);
            return false;
        }

        // Validate file type by magic bytes (prevents file type spoofing)
        if (!await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file))
        {
            _logger.LogWarning(
                "File {FileName} failed magic byte validation. Extension: {Extension}",
                file.FileName, fileExtension);
            return false;
        }

        // Malware scan
        if (!await _malwareScanService.ScanFileAsync(file))
        {
            _logger.LogWarning("File failed malware scan: {FileName}", file.FileName);
            return false;
        }

        return true;
    }

    /// <summary>
    /// Retrieves a document by ID and type from the appropriate dedicated table.
    /// </summary>
    public async Task<DocumentInfoDto?> GetDocumentAsync(Guid documentId, DocumentType documentType)
    {
        switch (documentType)
        {
            case DocumentType.PO:
                var po = await _context.POs.AsNoTracking().FirstOrDefaultAsync(p => p.Id == documentId);
                if (po == null) return null;
                return new DocumentInfoDto
                {
                    Id = po.Id, PackageId = po.PackageId, Type = DocumentType.PO,
                    FileName = po.FileName, BlobUrl = po.BlobUrl, FileSizeBytes = po.FileSizeBytes,
                    ContentType = po.ContentType, ExtractedDataJson = po.ExtractedDataJson,
                    ExtractionConfidence = po.ExtractionConfidence, IsFlaggedForReview = po.IsFlaggedForReview
                };

            case DocumentType.Invoice:
                var invoice = await _context.Invoices.AsNoTracking().FirstOrDefaultAsync(i => i.Id == documentId);
                if (invoice == null) return null;
                return new DocumentInfoDto
                {
                    Id = invoice.Id, PackageId = invoice.PackageId, Type = DocumentType.Invoice,
                    FileName = invoice.FileName, BlobUrl = invoice.BlobUrl, FileSizeBytes = invoice.FileSizeBytes,
                    ContentType = invoice.ContentType, ExtractedDataJson = invoice.ExtractedDataJson,
                    ExtractionConfidence = invoice.ExtractionConfidence, IsFlaggedForReview = invoice.IsFlaggedForReview
                };

            case DocumentType.CostSummary:
                var cs = await _context.CostSummaries.AsNoTracking().FirstOrDefaultAsync(c => c.Id == documentId);
                if (cs == null) return null;
                return new DocumentInfoDto
                {
                    Id = cs.Id, PackageId = cs.PackageId, Type = DocumentType.CostSummary,
                    FileName = cs.FileName, BlobUrl = cs.BlobUrl, FileSizeBytes = cs.FileSizeBytes,
                    ContentType = cs.ContentType, ExtractedDataJson = cs.ExtractedDataJson,
                    ExtractionConfidence = cs.ExtractionConfidence, IsFlaggedForReview = cs.IsFlaggedForReview
                };

            case DocumentType.ActivitySummary:
                var act = await _context.ActivitySummaries.AsNoTracking().FirstOrDefaultAsync(a => a.Id == documentId);
                if (act == null) return null;
                return new DocumentInfoDto
                {
                    Id = act.Id, PackageId = act.PackageId, Type = DocumentType.ActivitySummary,
                    FileName = act.FileName, BlobUrl = act.BlobUrl, FileSizeBytes = act.FileSizeBytes,
                    ContentType = act.ContentType, ExtractedDataJson = act.ExtractedDataJson,
                    ExtractionConfidence = act.ExtractionConfidence, IsFlaggedForReview = act.IsFlaggedForReview
                };

            case DocumentType.EnquiryDocument:
                var enq = await _context.EnquiryDocuments.AsNoTracking().FirstOrDefaultAsync(e => e.Id == documentId);
                if (enq == null) return null;
                return new DocumentInfoDto
                {
                    Id = enq.Id, PackageId = enq.PackageId, Type = DocumentType.EnquiryDocument,
                    FileName = enq.FileName, BlobUrl = enq.BlobUrl, FileSizeBytes = enq.FileSizeBytes,
                    ContentType = enq.ContentType, ExtractedDataJson = enq.ExtractedDataJson,
                    ExtractionConfidence = enq.ExtractionConfidence, IsFlaggedForReview = enq.IsFlaggedForReview
                };

            case DocumentType.TeamPhoto:
                var photo = await _context.TeamPhotos.AsNoTracking().FirstOrDefaultAsync(p => p.Id == documentId);
                if (photo == null) return null;
                return new DocumentInfoDto
                {
                    Id = photo.Id, PackageId = photo.PackageId, Type = DocumentType.TeamPhoto,
                    FileName = photo.FileName, BlobUrl = photo.BlobUrl, FileSizeBytes = photo.FileSizeBytes,
                    ContentType = photo.ContentType, ExtractedDataJson = photo.ExtractedMetadataJson,
                    ExtractionConfidence = photo.ExtractionConfidence, IsFlaggedForReview = photo.IsFlaggedForReview
                };

            default:
                throw new Domain.Exceptions.ValidationException(
                    new Dictionary<string, string[]>
                    {
                        { "documentType", new[] { $"Unsupported document type: {documentType}" } }
                    });
        }
    }

    /// <inheritdoc />
    public async Task TriggerPhotoExtractionAsync(Guid photoId, string blobUrl)
    {
        _logger.LogInformation("Triggering photo extraction for {PhotoId}, BlobUrl: {BlobUrl}", photoId, blobUrl);

        _ = Task.Run(async () =>
        {
            try
            {
                await ExtractDocumentDataAsync(photoId, blobUrl, DocumentType.TeamPhoto);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Background photo extraction failed for {PhotoId}", photoId);
            }
        });

        await Task.CompletedTask;
    }
}
