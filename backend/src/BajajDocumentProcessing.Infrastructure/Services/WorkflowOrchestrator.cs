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
    private readonly ILogger<WorkflowOrchestrator> _logger;

    public WorkflowOrchestrator(
        IApplicationDbContext context,
        IDocumentAgent documentAgent,
        IValidationAgent validationAgent,
        IConfidenceScoreService confidenceScoreService,
        IRecommendationAgent recommendationAgent,
        INotificationAgent notificationAgent,
        ILogger<WorkflowOrchestrator> logger)
    {
        _context = context;
        _documentAgent = documentAgent;
        _validationAgent = validationAgent;
        _confidenceScoreService = confidenceScoreService;
        _recommendationAgent = recommendationAgent;
        _notificationAgent = notificationAgent;
        _logger = logger;
    }

    public async Task<bool> ProcessSubmissionAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting workflow orchestration for package {PackageId}", packageId);

        try
        {
            // Load package with documents
            var package = await _context.DocumentPackages
                .Include(p => p.Documents)
                .Include(p => p.SubmittedBy)
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
                package.State == PackageState.RejectedByHQ)
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

            // Process each document
            foreach (var document in package.Documents)
            {
                // Only classify if document type is not already set (e.g., AdditionalDocument)
                // For user-specified types (PO, Invoice, CostSummary), skip classification
                if (document.Type == Domain.Enums.DocumentType.AdditionalDocument || 
                    document.Type == Domain.Enums.DocumentType.Photo)
                {
                    // Classify document
                    var classification = await _documentAgent.ClassifyAsync(
                        document.BlobUrl,
                        cancellationToken);
                    
                    document.Type = classification.Type;
                    document.ExtractionConfidence = classification.Confidence;
                    document.IsFlaggedForReview = classification.IsFlaggedForReview;
                }
                else
                {
                    _logger.LogInformation("Document type already set to {Type}, skipping classification", document.Type);
                }

                // Extract data based on type
                string extractedDataJson = document.Type switch
                {
                    Domain.Enums.DocumentType.PO => 
                        System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractPOAsync(document.BlobUrl, cancellationToken)),
                    Domain.Enums.DocumentType.Invoice => 
                        System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractInvoiceAsync(document.BlobUrl, cancellationToken)),
                    Domain.Enums.DocumentType.CostSummary => 
                        System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractCostSummaryAsync(document.BlobUrl, cancellationToken)),
                    Domain.Enums.DocumentType.Photo => 
                        System.Text.Json.JsonSerializer.Serialize(await _documentAgent.ExtractPhotoMetadataAsync(document.BlobUrl, cancellationToken)),
                    _ => "{}"
                };
                
                document.ExtractedDataJson = extractedDataJson;
                document.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync(cancellationToken);
            
            _logger.LogInformation("Extraction step completed for package {PackageId}", package.Id);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during extraction step for package {PackageId}", package.Id);
            return false;
        }
    }

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

    private async Task CompensateAsync(
        Domain.Entities.DocumentPackage package,
        string reason,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogWarning("Compensating workflow for package {PackageId}, Reason: {Reason}", 
                package.Id, reason);

            // Set package to error state
            package.State = PackageState.Rejected;
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
}
