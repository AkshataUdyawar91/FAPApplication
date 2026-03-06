using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;
using System.Text;
using System.Text.Json;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for generating approval recommendations with evidence
/// </summary>
public class RecommendationAgent : IRecommendationAgent
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<RecommendationAgent> _logger;
    private readonly Kernel _kernel;

    // Recommendation thresholds
    private const double APPROVE_THRESHOLD = 85.0;
    private const double REVIEW_THRESHOLD = 70.0;

    public RecommendationAgent(
        IApplicationDbContext context,
        IConfiguration configuration,
        ILogger<RecommendationAgent> logger)
    {
        _context = context;
        _logger = logger;

        // Build Semantic Kernel for evidence generation
        var endpoint = configuration["AzureOpenAI:Endpoint"] ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        _kernel = builder.Build();
    }

    public async Task<Recommendation> GenerateRecommendationAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Generating recommendation for package {PackageId}", packageId);

        try
        {
            // Load package with related data
            _logger.LogInformation("Loading package {PackageId} with documents", packageId);
            var package = await _context.DocumentPackages
                .Include(p => p.Documents)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                throw new InvalidOperationException($"Package {packageId} not found");
            }
            _logger.LogInformation("Package {PackageId} loaded successfully with {DocumentCount} documents", packageId, package.Documents.Count);

            // Get validation result
            _logger.LogInformation("Loading validation result for package {PackageId}", packageId);
            var validationResult = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.PackageId == packageId, cancellationToken);
            _logger.LogInformation("Validation result loaded: {ValidationPassed}", validationResult?.AllValidationsPassed ?? false);

            // Get confidence score
            _logger.LogInformation("Loading confidence score for package {PackageId}", packageId);
            var confidenceScore = await _context.ConfidenceScores
                .FirstOrDefaultAsync(cs => cs.PackageId == packageId, cancellationToken);

            if (confidenceScore == null)
            {
                _logger.LogError("Confidence score not found for package {PackageId}", packageId);
                throw new InvalidOperationException($"Confidence score not found for package {packageId}");
            }
            _logger.LogInformation("Confidence score loaded: {OverallConfidence:F2}%", confidenceScore.OverallConfidence);

            // Determine recommendation type based on confidence and validation
            _logger.LogInformation("Determining recommendation type for package {PackageId}", packageId);
            var recommendationType = DetermineRecommendationType(
                confidenceScore.OverallConfidence,
                validationResult?.AllValidationsPassed ?? false);
            _logger.LogInformation("Recommendation type determined: {RecommendationType}", recommendationType);

            // Generate evidence summary with AI
            _logger.LogInformation("Generating AI evidence for package {PackageId}", packageId);
            var evidence = await GenerateEvidenceWithAIAsync(
                package,
                validationResult,
                confidenceScore,
                recommendationType,
                cancellationToken);
            _logger.LogInformation("AI evidence generated successfully for package {PackageId}", packageId);

            // Check if recommendation already exists (WITH tracking to enable proper updates)
            _logger.LogInformation("Checking for existing recommendation for package {PackageId}", packageId);
            var existingRecommendation = await _context.Recommendations
                .FirstOrDefaultAsync(r => r.PackageId == packageId, cancellationToken);

            Recommendation recommendation;

            if (existingRecommendation != null)
            {
                _logger.LogInformation("Updating existing recommendation {RecommendationId} for package {PackageId}", existingRecommendation.Id, packageId);
                
                // Update existing tracked entity - EF Core will generate UPDATE statement
                existingRecommendation.Type = recommendationType;
                existingRecommendation.Evidence = evidence;
                existingRecommendation.ConfidenceScore = confidenceScore.OverallConfidence;
                existingRecommendation.ValidationIssuesJson = validationResult != null
                    ? JsonSerializer.Serialize(new
                    {
                        AllPassed = validationResult.AllValidationsPassed,
                        SAPVerified = validationResult.SapVerificationPassed,
                        AmountConsistent = validationResult.AmountConsistencyPassed,
                        LineItemsMatched = validationResult.LineItemMatchingPassed,
                        Complete = validationResult.CompletenessCheckPassed,
                        DatesValid = validationResult.DateValidationPassed,
                        VendorMatched = validationResult.VendorMatchingPassed
                    })
                    : null;
                existingRecommendation.UpdatedAt = DateTime.UtcNow;
                // CreatedAt is preserved automatically

                recommendation = existingRecommendation;
            }
            else
            {
                _logger.LogInformation("Creating new recommendation for package {PackageId}", packageId);
                // Create new recommendation
                recommendation = new Recommendation
                {
                    Id = Guid.NewGuid(),
                    PackageId = packageId,
                    Type = recommendationType,
                    Evidence = evidence,
                    ConfidenceScore = confidenceScore.OverallConfidence,
                    ValidationIssuesJson = validationResult != null
                        ? JsonSerializer.Serialize(new
                        {
                            AllPassed = validationResult.AllValidationsPassed,
                            SAPVerified = validationResult.SapVerificationPassed,
                            AmountConsistent = validationResult.AmountConsistencyPassed,
                            LineItemsMatched = validationResult.LineItemMatchingPassed,
                            Complete = validationResult.CompletenessCheckPassed,
                            DatesValid = validationResult.DateValidationPassed,
                            VendorMatched = validationResult.VendorMatchingPassed
                        })
                        : null,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                _context.Recommendations.Add(recommendation);
            }

            _logger.LogInformation("Saving recommendation to database for package {PackageId}", packageId);
            await _context.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Recommendation saved successfully for package {PackageId}", packageId);

            _logger.LogInformation(
                "Recommendation generated for package {PackageId}: {Type} (Confidence: {Confidence:F2})",
                packageId,
                recommendationType,
                confidenceScore.OverallConfidence);

            return recommendation;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating recommendation for package {PackageId}", packageId);
            throw;
        }
    }

    /// <summary>
    /// Determines the recommendation type based on confidence score and validation results
    /// </summary>
    private RecommendationType DetermineRecommendationType(double confidenceScore, bool validationPassed)
    {
        // REJECT if validation failed or confidence < 70
        if (!validationPassed || confidenceScore < REVIEW_THRESHOLD)
        {
            return RecommendationType.Reject;
        }

        // APPROVE if confidence >= 85 and validation passed
        if (confidenceScore >= APPROVE_THRESHOLD)
        {
            return RecommendationType.Approve;
        }

        // REVIEW if confidence between 70 and 85
        return RecommendationType.Review;
    }

    /// <summary>
    /// Generates plain-English evidence summary with specific citations
    /// </summary>
    private string GenerateEvidence(
        DocumentPackage package,
        ValidationResult? validationResult,
        ConfidenceScore confidenceScore,
        RecommendationType recommendationType)
    {
        var evidence = new StringBuilder();

        // Add confidence score summary
        evidence.AppendLine($"Overall Confidence Score: {confidenceScore.OverallConfidence:F1}%");
        evidence.AppendLine();

        // Add confidence breakdown
        evidence.AppendLine("Confidence Breakdown:");
        evidence.AppendLine($"- PO: {confidenceScore.PoConfidence:F1}%");
        evidence.AppendLine($"- Invoice: {confidenceScore.InvoiceConfidence:F1}%");
        evidence.AppendLine($"- Cost Summary: {confidenceScore.CostSummaryConfidence:F1}%");
        evidence.AppendLine($"- Activity: {confidenceScore.ActivityConfidence:F1}%");
        evidence.AppendLine($"- Photos: {confidenceScore.PhotosConfidence:F1}%");
        evidence.AppendLine();

        // Add validation results
        if (validationResult != null)
        {
            evidence.AppendLine("Validation Results:");
            evidence.AppendLine($"- SAP Verification: {(validationResult.SapVerificationPassed ? "PASSED" : "FAILED")}");
            evidence.AppendLine($"- Amount Consistency: {(validationResult.AmountConsistencyPassed ? "PASSED" : "FAILED")}");
            evidence.AppendLine($"- Line Item Matching: {(validationResult.LineItemMatchingPassed ? "PASSED" : "FAILED")}");
            evidence.AppendLine($"- Completeness Check: {(validationResult.CompletenessCheckPassed ? "PASSED" : "FAILED")}");
            evidence.AppendLine($"- Date Validation: {(validationResult.DateValidationPassed ? "PASSED" : "FAILED")}");
            evidence.AppendLine($"- Vendor Matching: {(validationResult.VendorMatchingPassed ? "PASSED" : "FAILED")}");
            evidence.AppendLine();

            // Add failure details if any
            if (!string.IsNullOrEmpty(validationResult.FailureReason))
            {
                evidence.AppendLine("Validation Issues:");
                evidence.AppendLine(validationResult.FailureReason);
                evidence.AppendLine();
            }
        }

        // Add recommendation rationale
        evidence.AppendLine("Recommendation Rationale:");
        switch (recommendationType)
        {
            case RecommendationType.Approve:
                evidence.AppendLine($"High confidence score ({confidenceScore.OverallConfidence:F1}% >= 85%) and all validations passed. Package is ready for automatic approval.");
                break;

            case RecommendationType.Review:
                evidence.AppendLine($"Moderate confidence score ({confidenceScore.OverallConfidence:F1}% between 70-85%). Manual review recommended to verify accuracy.");
                break;

            case RecommendationType.Reject:
                if (validationResult != null && !validationResult.AllValidationsPassed)
                {
                    evidence.AppendLine("Validation failures detected. Package requires corrections before approval.");
                }
                else
                {
                    evidence.AppendLine($"Low confidence score ({confidenceScore.OverallConfidence:F1}% < 70%). Package quality is insufficient for approval.");
                }
                break;
        }

        return evidence.ToString();
    }

    /// <summary>
    /// Generates AI-powered evidence summary using Semantic Kernel
    /// </summary>
    private async Task<string> GenerateEvidenceWithAIAsync(
        DocumentPackage package,
        ValidationResult? validationResult,
        ConfidenceScore confidenceScore,
        RecommendationType recommendationType,
        CancellationToken cancellationToken)
    {
        try
        {
            // Build structured data summary
            var dataSummary = new StringBuilder();
            dataSummary.AppendLine($"Package ID: {package.Id}");
            dataSummary.AppendLine($"Recommendation: {recommendationType}");
            dataSummary.AppendLine();
            dataSummary.AppendLine($"Overall Confidence: {confidenceScore.OverallConfidence:F1}%");
            dataSummary.AppendLine($"PO Confidence: {confidenceScore.PoConfidence:F1}%");
            dataSummary.AppendLine($"Invoice Confidence: {confidenceScore.InvoiceConfidence:F1}%");
            dataSummary.AppendLine($"Cost Summary Confidence: {confidenceScore.CostSummaryConfidence:F1}%");
            dataSummary.AppendLine($"Activity Confidence: {confidenceScore.ActivityConfidence:F1}%");
            dataSummary.AppendLine($"Photos Confidence: {confidenceScore.PhotosConfidence:F1}%");
            dataSummary.AppendLine();

            if (validationResult != null)
            {
                dataSummary.AppendLine("Validation Results:");
                dataSummary.AppendLine($"SAP Verification: {(validationResult.SapVerificationPassed ? "PASSED" : "FAILED")}");
                dataSummary.AppendLine($"Amount Consistency: {(validationResult.AmountConsistencyPassed ? "PASSED" : "FAILED")}");
                dataSummary.AppendLine($"Line Item Matching: {(validationResult.LineItemMatchingPassed ? "PASSED" : "FAILED")}");
                dataSummary.AppendLine($"Completeness: {(validationResult.CompletenessCheckPassed ? "PASSED" : "FAILED")}");
                dataSummary.AppendLine($"Date Validation: {(validationResult.DateValidationPassed ? "PASSED" : "FAILED")}");
                dataSummary.AppendLine($"Vendor Matching: {(validationResult.VendorMatchingPassed ? "PASSED" : "FAILED")}");

                if (!string.IsNullOrEmpty(validationResult.FailureReason))
                {
                    dataSummary.AppendLine();
                    dataSummary.AppendLine($"Failure Details: {validationResult.FailureReason}");
                }
            }

            // Create AI prompt for evidence generation
            var prompt = $@"You are an AI assistant for the Bajaj Document Processing System. Generate a clear, professional evidence summary for the following document package recommendation.

{dataSummary}

Generate a concise evidence summary (2-3 paragraphs) that:
1. Summarizes the key confidence scores and validation results
2. Explains the rationale for the {recommendationType} recommendation
3. Highlights any specific concerns or strengths
4. Uses specific citations from the data above
5. Maintains a professional, objective tone

Evidence Summary:";

            var chatService = _kernel.GetRequiredService<IChatCompletionService>();
            var result = await chatService.GetChatMessageContentAsync(prompt, cancellationToken: cancellationToken);

            var aiEvidence = result.Content ?? GenerateEvidence(package, validationResult, confidenceScore, recommendationType);

            _logger.LogInformation("AI evidence generated successfully for package {PackageId}", package.Id);

            return aiEvidence;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating AI evidence for package {PackageId}, falling back to template", package.Id);
            // Fallback to template-based evidence
            return GenerateEvidence(package, validationResult, confidenceScore, recommendationType);
        }
    }
}
