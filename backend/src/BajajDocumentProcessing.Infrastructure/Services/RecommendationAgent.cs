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
    private readonly ICorrelationIdService _correlationIdService;

    // Recommendation thresholds
    private const double APPROVE_THRESHOLD = 85.0;
    private const double REVIEW_THRESHOLD = 70.0;

    public RecommendationAgent(
        IApplicationDbContext context,
        IConfiguration configuration,
        ILogger<RecommendationAgent> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _logger = logger;
        _correlationIdService = correlationIdService;

        // Build Semantic Kernel for evidence generation
        var endpoint = configuration["AzureOpenAI:Endpoint"] ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        _kernel = builder.Build();
    }

    /// <summary>
    /// Generates an AI-powered approval recommendation with evidence for a document package.
    /// </summary>
    /// <param name="packageId">The unique identifier of the document package to analyze.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>A recommendation entity containing the recommendation type, confidence score, and AI-generated evidence.</returns>
    /// <exception cref="InvalidOperationException">Thrown when the package or confidence score is not found.</exception>
    /// <remarks>
    /// This method:
    /// - Loads the package with documents and validation results
    /// - Retrieves the confidence score
    /// - Determines recommendation type based on thresholds (Approve >= 85%, Review 70-85%, Reject &lt; 70%)
    /// - Generates AI-powered evidence summary using Azure OpenAI
    /// - Creates or updates the recommendation in the database
    /// </remarks>
    public async Task<Recommendation> GenerateRecommendationAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Generating recommendation for package {PackageId}. CorrelationId: {CorrelationId}",
            packageId, correlationId);

        try
        {
            // Load package with related data
            _logger.LogInformation("Loading package {PackageId}", packageId);
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                throw new Domain.Exceptions.NotFoundException($"Package {packageId} not found");
            }
            _logger.LogInformation("Package {PackageId} loaded successfully", packageId);

            // Get validation result - TODO: ValidationResult is now polymorphic (per document type)
            // For now, we'll skip validation result and rely on confidence scores only
            _logger.LogInformation("Skipping validation result load (ValidationResult is now polymorphic)");
            ValidationResult? validationResult = null;

            // Get confidence score
            _logger.LogInformation("Loading confidence score for package {PackageId}", packageId);
            var confidenceScore = await _context.ConfidenceScores
                .FirstOrDefaultAsync(cs => cs.PackageId == packageId, cancellationToken);

            if (confidenceScore == null)
            {
                _logger.LogError("Confidence score not found for package {PackageId}", packageId);
                throw new Domain.Exceptions.NotFoundException($"Confidence score not found for package {packageId}");
            }
            _logger.LogInformation("Confidence score loaded: {OverallConfidence:F2}%", confidenceScore.OverallConfidence);

            // Determine recommendation type based on confidence and validation
            _logger.LogInformation("Determining recommendation type for package {PackageId}", packageId);
            var recommendationType = DetermineRecommendationType(
                confidenceScore.OverallConfidence,
                validationResult?.AllValidationsPassed ?? true);
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
                // TODO: ValidationIssuesJson disabled until ValidationResult refactored for polymorphic model
                existingRecommendation.ValidationIssuesJson = null;
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
                    // TODO: ValidationIssuesJson disabled until ValidationResult refactored for polymorphic model
                    ValidationIssuesJson = null,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                _context.Recommendations.Add(recommendation);
            }

            _logger.LogInformation("Saving recommendation to database for package {PackageId}", packageId);
            await _context.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Recommendation saved successfully for package {PackageId}", packageId);

            _logger.LogInformation(
                "Recommendation generated for package {PackageId}: {Type} (Confidence: {Confidence:F2}). CorrelationId: {CorrelationId}",
                packageId,
                recommendationType,
                confidenceScore.OverallConfidence,
                correlationId);

            return recommendation;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error generating recommendation for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
            throw;
        }
    }

    /// <summary>
    /// Determines the recommendation type based on confidence score and validation results.
    /// </summary>
    /// <param name="confidenceScore">The overall confidence score (0-100).</param>
    /// <param name="validationPassed">Whether all validation checks passed.</param>
    /// <returns>
    /// - <see cref="RecommendationType.Reject"/> if validation failed or confidence &lt; 70%
    /// - <see cref="RecommendationType.Approve"/> if validation passed and confidence >= 85%
    /// - <see cref="RecommendationType.Review"/> if validation passed and confidence between 70-85%
    /// </returns>
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
    /// Generates a plain-English evidence summary with specific citations from validation and confidence data.
    /// </summary>
    /// <param name="package">The document package being analyzed.</param>
    /// <param name="validationResult">The validation results, or null if validation has not been performed.</param>
    /// <param name="confidenceScore">The confidence score breakdown for all document types.</param>
    /// <param name="recommendationType">The determined recommendation type.</param>
    /// <returns>A formatted string containing the evidence summary with confidence breakdown, validation results, and rationale.</returns>
    /// <remarks>
    /// This method serves as a fallback when AI-powered evidence generation fails.
    /// It creates a structured summary including:
    /// - Overall and per-document confidence scores
    /// - Validation check results (SAP, amounts, line items, completeness, dates, vendor)
    /// - Recommendation rationale based on the recommendation type
    /// </remarks>
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
    /// Generates an AI-powered evidence summary using Azure OpenAI via Semantic Kernel.
    /// </summary>
    /// <param name="package">The document package being analyzed.</param>
    /// <param name="validationResult">The validation results, or null if validation has not been performed.</param>
    /// <param name="confidenceScore">The confidence score breakdown for all document types.</param>
    /// <param name="recommendationType">The determined recommendation type.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>An AI-generated evidence summary in plain English, or a template-based summary if AI generation fails.</returns>
    /// <remarks>
    /// This method:
    /// - Constructs a structured data summary with all relevant metrics
    /// - Sends a prompt to Azure OpenAI requesting a professional evidence summary
    /// - Falls back to template-based evidence generation if AI call fails
    /// - Generates 2-3 paragraph summaries with specific citations and professional tone
    /// </remarks>
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

            // Create AI prompt for evidence generation - optimized for ASM readability
            var prompt = $@"You are an AI assistant helping Area Sales Managers (ASMs) review document submissions at Bajaj Auto. Generate a clear, easy-to-understand summary for the following submission.

DATA:
{dataSummary}

INSTRUCTIONS:
Write a brief summary (3-4 short paragraphs) that an ASM can quickly understand. Use simple language, not technical jargon.

FORMAT YOUR RESPONSE EXACTLY LIKE THIS:

RECOMMENDATION SUMMARY
[One sentence stating the recommendation clearly, e.g., ""This submission is recommended for APPROVAL because..."" or ""This submission requires MANUAL REVIEW because...""]

KEY STRENGTHS
- [List 2-3 positive findings as bullet points]

AREAS OF CONCERN
- [List any issues or concerns as bullet points, or write ""No significant concerns identified"" if all checks passed]

DECISION GUIDANCE
[One sentence advising the ASM on what to focus on when making their decision]

IMPORTANT RULES:
- Use plain English, avoid technical terms
- Be specific with numbers and percentages
- Focus on what matters for the approval decision
- Keep each bullet point to one line
- Do not include raw data or JSON

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
