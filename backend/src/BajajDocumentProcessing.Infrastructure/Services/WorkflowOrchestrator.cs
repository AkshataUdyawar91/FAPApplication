using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Orchestrates the document processing workflow using saga pattern
/// </summary>
public class WorkflowOrchestrator : IWorkflowOrchestrator
{
    private readonly IApplicationDbContext _context;
    private readonly IDocumentAgent _documentAgent;
    private readonly IValidationAgent _validationAgent;
    private readonly IConfidenceScoreService _confidenceScoreService;
    private readonly IRecommendationAgent _recommendationAgent;
    private readonly INotificationAgent _notificationAgent;
    private readonly IEmailAgent _emailAgent;
    private readonly ILogger<WorkflowOrchestrator> _logger;
    private readonly ICorrelationIdService _correlationIdService;

    public WorkflowOrchestrator(
        IApplicationDbContext context,
        IDocumentAgent documentAgent,
        IValidationAgent validationAgent,
        IConfidenceScoreService confidenceScoreService,
        IRecommendationAgent recommendationAgent,
        INotificationAgent notificationAgent,
        IEmailAgent emailAgent,
        ILogger<WorkflowOrchestrator> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _documentAgent = documentAgent;
        _validationAgent = validationAgent;
        _confidenceScoreService = confidenceScoreService;
        _recommendationAgent = recommendationAgent;
        _notificationAgent = notificationAgent;
        _emailAgent = emailAgent;
        _logger = logger;
        _correlationIdService = correlationIdService;
    }

    /// <summary>
    /// Processes a document submission through the complete workflow pipeline
    /// </summary>
    /// <param name="packageId">The ID of the package to process</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if processing succeeded, false if it failed</returns>
    /// <remarks>
    /// Orchestrates the following steps:
    /// 1. Document classification and data extraction
    /// 2. Cross-document validation
    /// 3. Confidence score calculation
    /// 4. AI recommendation generation
    /// 5. State transition to PendingASMApproval
    /// If any step fails, compensation logic is triggered to notify the user
    /// </remarks>
    public async Task<bool> ProcessSubmissionAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting workflow orchestration for package {PackageId}. CorrelationId: {CorrelationId}",
            packageId, correlationId);

        try
        {
            // Load package with hierarchical structure (Campaigns → Invoices, Photos)
            var package = await _context.DocumentPackages
                .Include(p => p.Documents)  // Keep for backward compatibility with old submissions
                .Include(p => p.Campaigns)
                    .ThenInclude(c => c.Invoices.Where(i => !i.IsDeleted))
                .Include(p => p.Campaigns)
                    .ThenInclude(c => c.Photos.Where(p => !p.IsDeleted))
                .Include(p => p.SubmittedBy)
                .AsSplitQuery()
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                return false;
            }

            // Check for idempotency - allow reprocessing of failed packages
            // Skip only if already in final states or approval states
            if (package.State == PackageState.PendingASMApproval || 
                package.State == PackageState.ASMApproved ||
                package.State == PackageState.PendingHQApproval ||
                package.State == PackageState.Approved || 
                package.State == PackageState.RejectedByASM ||
                package.State == PackageState.RejectedByRA)
            {
                _logger.LogWarning("Package {PackageId} is in final/approval state {State}, skipping processing", packageId, package.State);
                return true;
            }
            
            // Allow reprocessing of packages in intermediate states (Uploaded, Extracting, Validating, Scoring, Recommending)
            _logger.LogInformation("Package {PackageId} is in state {State}, will process/reprocess", packageId, package.State);

            // Step 1: Document Classification and Extraction
            if (!await ExecuteExtractionStepAsync(package, cancellationToken))
            {
                await CompensateAsync(package, "Extraction failed", cancellationToken);
                return false;
            }

            // Step 2: Validation
            if (!await ExecuteValidationStepAsync(package, cancellationToken))
            {
                await CompensateAsync(package, "Validation failed", cancellationToken);
                return false;
            }

            // Step 3: Confidence Scoring
            if (!await ExecuteScoringStepAsync(package, cancellationToken))
            {
                await CompensateAsync(package, "Scoring failed", cancellationToken);
                return false;
            }

            // Step 4: Recommendation
            if (!await ExecuteRecommendationStepAsync(package, cancellationToken))
            {
                await CompensateAsync(package, "Recommendation failed", cancellationToken);
                return false;
            }

            // Step 5: Final state transition
            package.State = PackageState.PendingASMApproval;  // Changed from PendingApproval
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Send notification
            await _notificationAgent.NotifySubmissionReceivedAsync(package.SubmittedByUserId, package.Id, cancellationToken);

            // Send PO details email to vendor (Agency submissions only — fire and forget, never blocks workflow)
            try
            {
                await SendVendorPOEmailAsync(package, cancellationToken);
            }
            catch (Exception vendorEx)
            {
                _logger.LogError(vendorEx, "Vendor email failed for package {PackageId}, continuing workflow", packageId);
            }

            _logger.LogInformation("Workflow orchestration completed successfully for package {PackageId}", packageId);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during workflow orchestration for package {PackageId}", packageId);
            
            // Load package for compensation
            var package = await _context.DocumentPackages
                .Include(p => p.SubmittedBy)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
            
            if (package != null)
            {
                await CompensateAsync(package, $"Unexpected error: {ex.Message}", cancellationToken);
            }
            
            return false;
        }
    }

    /// <summary>
    /// Executes the document extraction step: classifies documents and extracts structured data
    /// </summary>
    /// <param name="package">The document package to process</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if extraction succeeded, false otherwise</returns>
    // CHANGE: Photo batch size for parallel processing — process 5 photos at a time to respect OpenAI rate limits
    private const int PhotoBatchSize = 5;

    private async Task<bool> ExecuteExtractionStepAsync(
        Domain.Entities.DocumentPackage package,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Starting extraction step for package {PackageId}", package.Id);
            
            package.State = PackageState.Extracting;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // HIERARCHICAL MODEL: Extract from Campaigns → Invoices and Photos
            if (package.Campaigns != null && package.Campaigns.Any())
            {
                _logger.LogInformation("Processing hierarchical structure: {CampaignCount} campaigns for package {PackageId}", 
                    package.Campaigns.Count, package.Id);

                foreach (var campaign in package.Campaigns.Where(c => !c.IsDeleted))
                {
                    // Extract invoices
                    foreach (var invoice in campaign.Invoices.Where(i => !i.IsDeleted && !string.IsNullOrEmpty(i.BlobUrl)))
                    {
                        try
                        {
                            _logger.LogInformation("Extracting invoice {InvoiceId} from campaign {CampaignId}", 
                                invoice.Id, campaign.Id);
                            
                            var invoiceData = await _documentAgent.ExtractInvoiceAsync(invoice.BlobUrl, cancellationToken);
                            
                            // Update invoice with extracted data (only if fields are empty)
                            if (string.IsNullOrEmpty(invoice.InvoiceNumber) && !string.IsNullOrEmpty(invoiceData.InvoiceNumber))
                                invoice.InvoiceNumber = invoiceData.InvoiceNumber;
                            
                            if (invoice.InvoiceDate == null && invoiceData.InvoiceDate != default)
                                invoice.InvoiceDate = invoiceData.InvoiceDate;
                            
                            if (string.IsNullOrEmpty(invoice.VendorName) && !string.IsNullOrEmpty(invoiceData.VendorName))
                                invoice.VendorName = invoiceData.VendorName;
                            
                            if (string.IsNullOrEmpty(invoice.GSTNumber) && !string.IsNullOrEmpty(invoiceData.GSTNumber))
                                invoice.GSTNumber = invoiceData.GSTNumber;
                            
                            if ((invoice.TotalAmount == null || invoice.TotalAmount == 0) && invoiceData.TotalAmount > 0)
                                invoice.TotalAmount = invoiceData.TotalAmount;
                            
                            invoice.UpdatedAt = DateTime.UtcNow;
                            
                            _logger.LogInformation("Invoice {InvoiceId} extracted: Number={Number}, Amount={Amount}", 
                                invoice.Id, invoiceData.InvoiceNumber, invoiceData.TotalAmount);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Error extracting invoice {InvoiceId}, continuing with next", invoice.Id);
                        }
                    }

                    // Extract photos in batches
                    var photos = campaign.Photos.Where(p => !p.IsDeleted && !string.IsNullOrEmpty(p.BlobUrl)).ToList();
                    if (photos.Any())
                    {
                        _logger.LogInformation("Processing {Count} photos in batches of {BatchSize} for campaign {CampaignId}",
                            photos.Count, PhotoBatchSize, campaign.Id);

                        var batches = photos
                            .Select((photo, index) => new { photo, index })
                            .GroupBy(x => x.index / PhotoBatchSize)
                            .Select(g => g.Select(x => x.photo).ToList())
                            .ToList();

                        for (int batchNum = 0; batchNum < batches.Count; batchNum++)
                        {
                            var batch = batches[batchNum];
                            _logger.LogInformation("Processing photo batch {BatchNum}/{TotalBatches} ({Count} photos)",
                                batchNum + 1, batches.Count, batch.Count);

                            var tasks = batch.Select(async photo =>
                            {
                                try
                                {
                                    var metadata = await _documentAgent.ExtractPhotoMetadataAsync(photo.BlobUrl, cancellationToken);
                                    // Store metadata in Caption field as JSON for now
                                    if (string.IsNullOrEmpty(photo.Caption))
                                    {
                                        photo.Caption = System.Text.Json.JsonSerializer.Serialize(metadata);
                                    }
                                    photo.UpdatedAt = DateTime.UtcNow;
                                    _logger.LogInformation("Photo {FileName} extraction completed", photo.FileName);
                                }
                                catch (Exception ex)
                                {
                                    _logger.LogError(ex, "Error extracting photo {FileName}", photo.FileName);
                                }
                            });

                            await Task.WhenAll(tasks);
                        }
                    }
                }

                await _context.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Hierarchical extraction completed for package {PackageId}", package.Id);
                return true;
            }

            // OLD MODEL: Extract from Documents table (backward compatibility)
            if (package.Documents != null && package.Documents.Any())
            {
                _logger.LogInformation("Processing old document model: {DocumentCount} documents for package {PackageId}", 
                    package.Documents.Count, package.Id);

                var nonPhotoDocuments = package.Documents.Where(d => d.Type != Domain.Enums.DocumentType.Photo).ToList();
                var photoDocuments = package.Documents.Where(d => d.Type == Domain.Enums.DocumentType.Photo).ToList();

                // Process non-photo documents sequentially
                foreach (var document in nonPhotoDocuments)
                {
                    if (document.Type == Domain.Enums.DocumentType.AdditionalDocument)
                    {
                        var classification = await _documentAgent.ClassifyAsync(
                            document.BlobUrl,
                            cancellationToken);
                        
                        document.Type = classification.Type;
                        document.ExtractionConfidence = classification.Confidence;
                        document.IsFlaggedForReview = classification.IsFlaggedForReview;
                    }

                    string extractedDataJson = document.Type switch
                    {
                        Domain.Enums.DocumentType.PO => 
                            System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractPOAsync(document.BlobUrl, cancellationToken)),
                        Domain.Enums.DocumentType.Invoice => 
                            System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractInvoiceAsync(document.BlobUrl, cancellationToken)),
                        Domain.Enums.DocumentType.CostSummary => 
                            System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractCostSummaryAsync(document.BlobUrl, cancellationToken)),
                        Domain.Enums.DocumentType.Activity => 
                            System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractActivityAsync(document.BlobUrl, cancellationToken)),
                        Domain.Enums.DocumentType.EnquiryDump => 
                            System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractEnquiryDumpAsync(document.BlobUrl, cancellationToken)),
                        _ => "{}"
                    };
                    
                    document.ExtractedDataJson = extractedDataJson;
                    document.UpdatedAt = DateTime.UtcNow;
                }

                // Process photos in batches
                if (photoDocuments.Any())
                {
                    var batches = photoDocuments
                        .Select((doc, index) => new { doc, index })
                        .GroupBy(x => x.index / PhotoBatchSize)
                        .Select(g => g.Select(x => x.doc).ToList())
                        .ToList();

                    foreach (var batch in batches)
                    {
                        var tasks = batch.Select(async photoDoc =>
                        {
                            try
                            {
                                var metadata = await _documentAgent.ExtractPhotoMetadataAsync(photoDoc.BlobUrl, cancellationToken);
                                photoDoc.ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(metadata);
                                photoDoc.UpdatedAt = DateTime.UtcNow;
                            }
                            catch (Exception ex)
                            {
                                _logger.LogError(ex, "Error extracting photo {FileName}", photoDoc.FileName);
                                photoDoc.ExtractedDataJson = "{}";
                            }
                        });

                        await Task.WhenAll(tasks);
                    }
                }

                await _context.SaveChangesAsync(cancellationToken);
                _logger.LogInformation("Old model extraction completed for package {PackageId}", package.Id);
                return true;
            }

            // No documents or campaigns found
            _logger.LogWarning("No documents or campaigns found for package {PackageId}", package.Id);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during extraction step for package {PackageId}", package.Id);
            return false;
        }
    }

    /// <summary>
    /// Executes the validation step: validates package completeness, SAP verification, and cross-document consistency
    /// </summary>
    /// <param name="package">The document package to validate</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if validation succeeded, false otherwise</returns>
    private async Task<bool> ExecuteValidationStepAsync(
        Domain.Entities.DocumentPackage package,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Starting validation step for package {PackageId}", package.Id);
            
            package.State = PackageState.Validating;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Validate package
            var validationResult = await _validationAgent.ValidatePackageAsync(
                package.Id,
                cancellationToken);

            // Check if validation result already exists
            var existingValidation = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.PackageId == package.Id, cancellationToken);

            if (existingValidation != null)
            {
                _logger.LogInformation("Updating existing validation result for package {PackageId}", package.Id);
                
                // Update existing validation result
                existingValidation.SapVerificationPassed = validationResult.SAPVerification?.IsVerified ?? false;
                existingValidation.AmountConsistencyPassed = validationResult.AmountConsistency?.IsConsistent ?? false;
                existingValidation.LineItemMatchingPassed = validationResult.LineItemMatching?.AllItemsMatched ?? false;
                existingValidation.CompletenessCheckPassed = validationResult.Completeness?.IsComplete ?? false;
                existingValidation.DateValidationPassed = validationResult.DateValidation?.IsValid ?? true;
                existingValidation.VendorMatchingPassed = validationResult.VendorMatching?.IsMatched ?? true;
                existingValidation.AllValidationsPassed = validationResult.AllPassed;
                existingValidation.ValidationDetailsJson = System.Text.Json.JsonSerializer.Serialize(validationResult);
                existingValidation.FailureReason = validationResult.AllPassed ? null : string.Join("; ", validationResult.Issues.Select(i => i.Issue));
                existingValidation.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                _logger.LogInformation("Creating new validation result for package {PackageId}", package.Id);
                
                // Convert PackageValidationResult to ValidationResult entity
                var validationEntity = new Domain.Entities.ValidationResult
                {
                    Id = Guid.NewGuid(),
                    PackageId = package.Id,
                    SapVerificationPassed = validationResult.SAPVerification?.IsVerified ?? false,
                    AmountConsistencyPassed = validationResult.AmountConsistency?.IsConsistent ?? false,
                    LineItemMatchingPassed = validationResult.LineItemMatching?.AllItemsMatched ?? false,
                    CompletenessCheckPassed = validationResult.Completeness?.IsComplete ?? false,
                    DateValidationPassed = validationResult.DateValidation?.IsValid ?? true,
                    VendorMatchingPassed = validationResult.VendorMatching?.IsMatched ?? true,
                    AllValidationsPassed = validationResult.AllPassed,
                    ValidationDetailsJson = System.Text.Json.JsonSerializer.Serialize(validationResult),
                    FailureReason = validationResult.AllPassed ? null : string.Join("; ", validationResult.Issues.Select(i => i.Issue)),
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                // Store validation result
                _context.ValidationResults.Add(validationEntity);
            }
            
            await _context.SaveChangesAsync(cancellationToken);
            
            _logger.LogInformation("Validation step completed for package {PackageId}, Passed: {Passed}", 
                package.Id, validationResult.AllPassed);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during validation step for package {PackageId}", package.Id);
            return false;
        }
    }

    /// <summary>
    /// Executes the scoring step: calculates weighted confidence scores for the package
    /// </summary>
    /// <param name="package">The document package to score</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if scoring succeeded, false otherwise</returns>
    private async Task<bool> ExecuteScoringStepAsync(
        Domain.Entities.DocumentPackage package,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Starting scoring step for package {PackageId}", package.Id);
            
            package.State = PackageState.Scoring;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Check if confidence score already exists (idempotency)
            var existingScore = await _context.ConfidenceScores
                .FirstOrDefaultAsync(cs => cs.PackageId == package.Id, cancellationToken);

            Domain.Entities.ConfidenceScore confidenceScore;
            
            if (existingScore == null)
            {
                // Calculate confidence score (this already saves to DB inside the service)
                confidenceScore = await _confidenceScoreService.CalculateConfidenceScoreAsync(
                    package.Id,
                    cancellationToken);
                
                _logger.LogInformation("Scoring step completed for package {PackageId}, Score: {Score}", 
                    package.Id, confidenceScore.OverallConfidence);
            }
            else
            {
                confidenceScore = existingScore;
                _logger.LogInformation("Confidence score already exists for package {PackageId}, skipping", package.Id);
            }
            
            _logger.LogInformation("Scoring step completed for package {PackageId}, Score: {Score}", 
                package.Id, confidenceScore.OverallConfidence);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during scoring step for package {PackageId}", package.Id);
            return false;
        }
    }

    /// <summary>
    /// Executes the recommendation step: generates AI-powered approval/rejection recommendation with evidence
    /// </summary>
    /// <param name="package">The document package to generate recommendation for</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>True if recommendation generation succeeded, false otherwise</returns>
    private async Task<bool> ExecuteRecommendationStepAsync(
        Domain.Entities.DocumentPackage package,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Starting recommendation step for package {PackageId}", package.Id);
            
            package.State = PackageState.Recommending;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Generate recommendation (service handles create/update internally)
            var recommendation = await _recommendationAgent.GenerateRecommendationAsync(
                package.Id,
                cancellationToken);
            
            _logger.LogInformation("Recommendation step completed for package {PackageId}, Type: {Type}", 
                package.Id, recommendation.Type);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during recommendation step for package {PackageId}", package.Id);
            return false;
        }
    }

    /// <summary>
    /// Compensates for workflow failure by setting package to rejected state and notifying the user
    /// </summary>
    /// <param name="package">The document package that failed processing</param>
    /// <param name="reason">The reason for failure</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A task representing the asynchronous operation</returns>
    private async Task CompensateAsync(
        Domain.Entities.DocumentPackage package,
        string reason,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogWarning("Compensating workflow for package {PackageId}, Reason: {Reason}", 
                package.Id, reason);

            // Set package to processing failed state (NOT Rejected — that's for ASM rejection)
            package.State = PackageState.ProcessingFailed;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Notify user of failure
            await _notificationAgent.NotifyRejectedAsync(
                package.SubmittedByUserId,
                package.Id,
                reason,
                cancellationToken);

            _logger.LogInformation("Compensation completed for package {PackageId}", package.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during compensation for package {PackageId}", package.Id);
        }
    }

    /// <summary>
    /// Looks up vendor from extracted PO data and sends PO details email to vendor contacts.
    /// This only runs for Agency submissions. Never blocks the main workflow.
    /// </summary>
    private async Task SendVendorPOEmailAsync(
        Domain.Entities.DocumentPackage package,
        CancellationToken cancellationToken)
    {
        // Find the PO document with extracted data
        var poDocument = package.Documents?.FirstOrDefault(d => d.Type == Domain.Enums.DocumentType.PO);
        if (poDocument?.ExtractedDataJson == null)
        {
            _logger.LogWarning("No PO document found for package {PackageId}, skipping vendor email", package.Id);
            return;
        }

        // Deserialize PO data to get vendor info
        POData? poData;
        try
        {
            poData = JsonSerializer.Deserialize<POData>(poDocument.ExtractedDataJson);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to deserialize PO data for package {PackageId}", package.Id);
            return;
        }

        if (poData == null)
        {
            _logger.LogWarning("PO data is null for package {PackageId}", package.Id);
            return;
        }

        // Lookup vendor by VendorCode first, then fallback to VendorName
        var vendor = await _context.Vendors
            .Include(v => v.Contacts.Where(c => c.IsActive && !c.IsDeleted))
            .FirstOrDefaultAsync(v =>
                !v.IsDeleted && v.IsActive &&
                (!string.IsNullOrEmpty(poData.VendorCode)
                    ? v.VendorCode == poData.VendorCode
                    : v.VendorName.ToLower() == poData.VendorName.ToLower()),
                cancellationToken);

        if (vendor == null)
        {
            _logger.LogWarning(
                "No vendor found for VendorCode={VendorCode}, VendorName={VendorName} (Package {PackageId}). Skipping vendor email.",
                poData.VendorCode, poData.VendorName, package.Id);
            return;
        }

        if (!vendor.Contacts.Any())
        {
            _logger.LogWarning("Vendor {VendorCode} ({VendorName}) has no active contacts. Skipping vendor email.",
                vendor.VendorCode, vendor.VendorName);
            return;
        }

        // Build email content
        var subject = $"Purchase Order Details - {poData.PONumber}";
        var body = GenerateVendorPOEmailBody(poData, vendor.VendorName);

        _logger.LogInformation(
            "Vendor PO email body for Package {PackageId}: Dear {VendorName}, PO Number: {PONumber}, PO Amount: {POAmount}",
            package.Id, vendor.VendorName, poData.PONumber, poData.TotalAmount);

        // Send to each active vendor contact
        foreach (var contact in vendor.Contacts)
        {
            try
            {
                var result = await _emailAgent.SendVendorPOEmailAsync(
                    contact.Email, subject, body, cancellationToken);

                _logger.LogInformation(
                    "Vendor PO email {Status} for {Email} (Vendor: {VendorName}, PO: {PONumber}, Package: {PackageId}). Attempts: {Attempts}",
                    result.Success ? "sent" : "failed",
                    contact.Email, vendor.VendorName, poData.PONumber, package.Id, result.AttemptsCount);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send vendor PO email to {Email} for package {PackageId}",
                    contact.Email, package.Id);
            }
        }
    }

    /// <summary>
    /// Generates HTML email body with PO Number and Amount for vendor notification
    /// </summary>
    private static string GenerateVendorPOEmailBody(POData poData, string vendorName)
    {
        return $@"
<html>
<body style='font-family:Arial,sans-serif;color:#333'>
    <h2 style='color:#1a5276'>Purchase Order Notification</h2>
    <p>Dear {vendorName},</p>
    <p>A Purchase Order has been submitted with the following details:</p>
    <table style='border-collapse:collapse;width:100%;margin:16px 0'>
        <tr>
            <td style='padding:12px;font-weight:bold;width:200px;background:#f8f9fa;border:1px solid #ddd'>PO Number</td>
            <td style='padding:12px;border:1px solid #ddd'>{poData.PONumber}</td>
        </tr>
        <tr>
            <td style='padding:12px;font-weight:bold;width:200px;background:#f8f9fa;border:1px solid #ddd'>PO Amount</td>
            <td style='padding:12px;border:1px solid #ddd'>{poData.TotalAmount:N2}</td>
        </tr>
    </table>
    <p style='margin-top:24px;color:#666;font-size:12px'>This is an automated notification from the Bajaj FAP Document Processing System.</p>
</body>
</html>";
    }
}
