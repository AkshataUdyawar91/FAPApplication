using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

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
    private readonly ISubmissionNotificationService _submissionNotificationService;
    private readonly IFileStorageService _fileStorageService;
    private readonly ILogger<WorkflowOrchestrator> _logger;
    private readonly ICorrelationIdService _correlationIdService;
    private readonly ICircleHeadAssignmentService _circleHeadAssignmentService;
    private readonly ISubmissionNumberService _submissionNumberService;

    public WorkflowOrchestrator(
        IApplicationDbContext context,
        IDocumentAgent documentAgent,
        IValidationAgent validationAgent,
        IConfidenceScoreService confidenceScoreService,
        IRecommendationAgent recommendationAgent,
        INotificationAgent notificationAgent,
        IEmailAgent emailAgent,
        ISubmissionNotificationService submissionNotificationService,
        IFileStorageService fileStorageService,
        ILogger<WorkflowOrchestrator> logger,
        ICorrelationIdService correlationIdService,
        ICircleHeadAssignmentService circleHeadAssignmentService,
        ISubmissionNumberService submissionNumberService)
    {
        _context = context;
        _documentAgent = documentAgent;
        _validationAgent = validationAgent;
        _confidenceScoreService = confidenceScoreService;
        _recommendationAgent = recommendationAgent;
        _notificationAgent = notificationAgent;
        _emailAgent = emailAgent;
        _submissionNotificationService = submissionNotificationService;
        _fileStorageService = fileStorageService;
        _logger = logger;
        _correlationIdService = correlationIdService;
        _circleHeadAssignmentService = circleHeadAssignmentService;
        _submissionNumberService = submissionNumberService;
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
    /// 5. State transition to PendingCH
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
            // Load package with dedicated navigations and hierarchical structure
            var package = await _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices.Where(i => !i.IsDeleted))
                .Include(p => p.CostSummary)
                .Include(p => p.ActivitySummary)
                .Include(p => p.EnquiryDocument)
                .Include(p => p.Teams)
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
            if (package.State == PackageState.PendingCH || 
                package.State == PackageState.PendingRA ||
                package.State == PackageState.Approved || 
                package.State == PackageState.CHRejected ||
                package.State == PackageState.RARejected)
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
            // Only move to PendingCH if the package was explicitly submitted (has a SubmissionNumber).
            // Partial uploads (chatbot in-progress) should stay as Uploaded until the user submits.
            if (string.IsNullOrEmpty(package.SubmissionNumber))
            {
                _logger.LogInformation("Package {PackageId} has no SubmissionNumber — keeping Uploaded state (not yet submitted)", package.Id);
                package.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync(cancellationToken);
                return true;
            }

            // Safety net: ensure CircleHead is assigned before advancing to PendingCH
            if (!package.AssignedCircleHeadUserId.HasValue && !string.IsNullOrEmpty(package.ActivityState))
            {
                var circleHeadUserId = await _circleHeadAssignmentService.AssignAsync(package.ActivityState, cancellationToken);
                package.AssignedCircleHeadUserId = circleHeadUserId;
                _logger.LogInformation("Safety net: assigned CircleHead {UserId} for package {PackageId} (state: {State})", circleHeadUserId, package.Id, package.ActivityState);
            }

            package.State = PackageState.PendingCH;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Push SubmissionStatusChanged event via SignalR
            await _submissionNotificationService.SendSubmissionStatusChangedAsync(
                package.Id,
                new
                {
                    submissionId = package.Id,
                    newStatus = PackageState.PendingCH.ToString(),
                    assignedTo = package.AssignedCircleHeadUserId
                },
                cancellationToken);

            // Send notification
            await _notificationAgent.NotifySubmissionReceivedAsync(package.SubmittedByUserId, package.Id, cancellationToken);

            // Send submission_received email to agency
            var emailResult = await _emailAgent.SendSubmissionReceivedEmailAsync(package.Id, cancellationToken);
            if (!emailResult.Success)
                _logger.LogWarning("submission_received email failed for package {PackageId}: {Error}", package.Id, emailResult.ErrorMessage);

            // Send pending_circle_head email to assigned circle head
            if (package.AssignedCircleHeadUserId.HasValue)
            {
                var circleHeadEmail = await _context.Users
                    .Where(u => u.Id == package.AssignedCircleHeadUserId.Value)
                    .Select(u => u.Email)
                    .FirstOrDefaultAsync(cancellationToken);

                if (!string.IsNullOrEmpty(circleHeadEmail))
                {
                    var chEmailResult = await _emailAgent.SendPendingCircleHeadEmailAsync(package.Id, circleHeadEmail, cancellationToken);
                    if (!chEmailResult.Success)
                        _logger.LogWarning("pending_circle_head email failed for package {PackageId}: {Error}", package.Id, chEmailResult.ErrorMessage);
                }
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

            // Extract package-level dedicated entities (PO, CostSummary, ActivitySummary, EnquiryDocument)
            var hasPackageLevelDocs = false;

            if (package.PO != null && !string.IsNullOrEmpty(package.PO.BlobUrl))
            {
                if (!await _fileStorageService.IsBlobAccessibleAsync(package.PO.BlobUrl))
                {
                    _logger.LogWarning("PO blob not accessible for package {PackageId}, URL: {BlobUrl} — skipping extraction",
                        package.Id, package.PO.BlobUrl);
                }
                else
                {
                    try
                    {
                        _logger.LogInformation("Extracting PO for package {PackageId}", package.Id);
                        var poData = await _documentAgent.ExtractPOAsync(package.PO.BlobUrl, cancellationToken);
                        package.PO.ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(poData);
                        package.PO.UpdatedAt = DateTime.UtcNow;
                        hasPackageLevelDocs = true;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error extracting PO for package {PackageId}", package.Id);
                    }
                }
            }

            if (package.CostSummary != null && !string.IsNullOrEmpty(package.CostSummary.BlobUrl))
            {
                if (!await _fileStorageService.IsBlobAccessibleAsync(package.CostSummary.BlobUrl))
                {
                    _logger.LogWarning("CostSummary blob not accessible for package {PackageId}, URL: {BlobUrl} — skipping extraction",
                        package.Id, package.CostSummary.BlobUrl);
                }
                else
                {
                    try
                    {
                        _logger.LogInformation("Extracting CostSummary for package {PackageId}", package.Id);
                        var costData = await _documentAgent.ExtractCostSummaryAsync(package.CostSummary.BlobUrl, cancellationToken);
                        package.CostSummary.ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(costData);
                        package.CostSummary.UpdatedAt = DateTime.UtcNow;
                        hasPackageLevelDocs = true;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error extracting CostSummary for package {PackageId}", package.Id);
                    }
                }
            }

            if (package.ActivitySummary != null && !string.IsNullOrEmpty(package.ActivitySummary.BlobUrl))
            {
                if (!await _fileStorageService.IsBlobAccessibleAsync(package.ActivitySummary.BlobUrl))
                {
                    _logger.LogWarning("ActivitySummary blob not accessible for package {PackageId}, URL: {BlobUrl} — skipping extraction",
                        package.Id, package.ActivitySummary.BlobUrl);
                }
                else
                {
                    try
                    {
                        _logger.LogInformation("Extracting ActivitySummary for package {PackageId}", package.Id);
                        var activityData = await _documentAgent.ExtractActivityAsync(package.ActivitySummary.BlobUrl, cancellationToken);
                        package.ActivitySummary.ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(activityData);
                        package.ActivitySummary.ExtractionConfidence = activityData.FieldConfidences.Values.Any()
                            ? activityData.FieldConfidences.Values.Average() : 0.5;
                        package.ActivitySummary.IsFlaggedForReview = activityData.IsFlaggedForReview;
                        package.ActivitySummary.UpdatedAt = DateTime.UtcNow;

                        // Populate summary fields from extracted rows
                        if (activityData.Rows != null && activityData.Rows.Count > 0)
                        {
                            package.ActivitySummary.DealerName = activityData.Rows[0].DealerName;
                            package.ActivitySummary.TotalDays = activityData.Rows.Sum(r => r.Day);
                            package.ActivitySummary.TotalWorkingDays = activityData.Rows.Sum(r => r.WorkingDay);
                            var locations = activityData.Rows
                                .Where(r => !string.IsNullOrWhiteSpace(r.Location))
                                .Select(r => r.Location)
                                .Distinct()
                                .ToList();
                            if (locations.Any())
                            {
                                package.ActivitySummary.ActivityDescription = $"Activity across {locations.Count} location(s): {string.Join(", ", locations)}";
                            }
                        }

                        hasPackageLevelDocs = true;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error extracting ActivitySummary for package {PackageId}", package.Id);
                    }
                }
            }

            if (package.EnquiryDocument != null && !string.IsNullOrEmpty(package.EnquiryDocument.BlobUrl))
            {
                if (!await _fileStorageService.IsBlobAccessibleAsync(package.EnquiryDocument.BlobUrl))
                {
                    _logger.LogWarning("EnquiryDocument blob not accessible for package {PackageId}, URL: {BlobUrl} — skipping extraction",
                        package.Id, package.EnquiryDocument.BlobUrl);
                }
                else
                {
                    try
                    {
                        _logger.LogInformation("Extracting EnquiryDocument for package {PackageId}", package.Id);
                        var enquiryData = await _documentAgent.ExtractEnquiryDumpAsync(package.EnquiryDocument.BlobUrl, cancellationToken);
                        package.EnquiryDocument.ExtractedDataJson = System.Text.Json.JsonSerializer.Serialize(enquiryData);
                        package.EnquiryDocument.ExtractionConfidence = enquiryData.FieldConfidences.Values.Any()
                            ? enquiryData.FieldConfidences.Values.Average() : 0.5;
                        package.EnquiryDocument.IsFlaggedForReview = enquiryData.IsFlaggedForReview;
                        package.EnquiryDocument.UpdatedAt = DateTime.UtcNow;
                        hasPackageLevelDocs = true;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error extracting EnquiryDocument for package {PackageId}", package.Id);
                    }
                }
            }

            // Extract from Invoices (linked to PO)
            if (package.Invoices != null && package.Invoices.Any())
            {
                _logger.LogInformation("Processing {InvoiceCount} invoices for package {PackageId}", 
                    package.Invoices.Count, package.Id);

                foreach (var invoice in package.Invoices.Where(i => !i.IsDeleted && !string.IsNullOrEmpty(i.BlobUrl)))
                {
                    if (!await _fileStorageService.IsBlobAccessibleAsync(invoice.BlobUrl))
                    {
                        _logger.LogWarning("Invoice blob not accessible for invoice {InvoiceId}, URL: {BlobUrl} — skipping",
                            invoice.Id, invoice.BlobUrl);
                        continue;
                    }

                    try
                    {
                        _logger.LogInformation("Extracting invoice {InvoiceId}", invoice.Id);
                        
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
            }

            // Extract from Teams → Photos
            if (package.Teams != null && package.Teams.Any())
            {
                _logger.LogInformation("Processing hierarchical structure: {TeamCount} teams for package {PackageId}", 
                    package.Teams.Count, package.Id);

                foreach (var team in package.Teams.Where(c => !c.IsDeleted))
                {
                    // Extract photos in batches
                    var photos = team.Photos.Where(p => !p.IsDeleted && !string.IsNullOrEmpty(p.BlobUrl)).ToList();
                    if (photos.Any())
                    {
                        _logger.LogInformation("Processing {Count} photos in batches of {BatchSize} for team {TeamId}",
                            photos.Count, PhotoBatchSize, team.Id);

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

                hasPackageLevelDocs = true;
            }

            if (!hasPackageLevelDocs)
            {
                _logger.LogWarning("No documents or teams found for package {PackageId}", package.Id);
                return false;
            }

            await _context.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Extraction completed for package {PackageId}", package.Id);

            // Push ExtractionComplete event via SignalR
            await _submissionNotificationService.SendExtractionCompleteAsync(
                package.Id,
                new
                {
                    documentId = package.Id,
                    documentType = "Package",
                    status = "Completed",
                    extractedFields = new { hasPackageLevelDocs }
                },
                cancellationToken);

            return true;
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

            // Validate package (persistence now happens inside ValidatePackageAsync)
            var validationResult = await _validationAgent.ValidatePackageAsync(
                package.Id,
                cancellationToken);
            
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
            
            // Note: Scoring state removed from new schema - packages go directly from Validating to PendingCH
            // Keeping this method for backward compatibility but not setting state
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
            
            // Note: Recommending state removed from new schema - packages go directly from Validating to PendingCH
            // Keeping this method for backward compatibility but not setting state
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

            // Revert to Uploaded so the workflow can be retried — processing failures are NOT ASM rejections
            package.State = PackageState.Uploaded;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Notify user of processing failure (not rejection)
            await _notificationAgent.NotifySubmissionReceivedAsync(
                package.SubmittedByUserId,
                package.Id,
                cancellationToken);

            // Send validation_failed email to agency
            var emailResult = await _emailAgent.SendValidationFailedEmailAsync(
                package.Id,
                new List<ValidationIssue> { new() { Field = "Processing", Issue = reason } },
                cancellationToken);
            if (!emailResult.Success)
                _logger.LogWarning("validation_failed email failed for package {PackageId}: {Error}", package.Id, emailResult.ErrorMessage);

            _logger.LogInformation("Compensation completed for package {PackageId}", package.Id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during compensation for package {PackageId}", package.Id);
        }
    }
}
