using BajajDocumentProcessing.Application.DTOs.Submissions;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel.ChatCompletion;
using System.Text;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Part 3: AI evidence generation methods
/// </summary>
public partial class EnhancedValidationReportService
{
    // ─── AI EVIDENCE GENERATION ──────────────────────────────────────────

    private async Task<string> GenerateDetailedEvidenceAsync(
        DocumentPackage package,
        ValidationResult? validationResult,
        List<ValidationCategoryDto> categories,
        ValidationSummaryDto summary,
        CancellationToken cancellationToken)
    {
        try
        {
            var chatService = _kernel.GetRequiredService<IChatCompletionService>();
            var prompt = BuildEvidencePrompt(package, categories, summary);

            var chatHistory = new ChatHistory();
            chatHistory.AddSystemMessage(@"You are an AI assistant helping Area Sales Managers review document submissions for Bajaj Auto Limited.

Generate a clear, professional validation report with specific evidence and actionable recommendations.

Format the response as:
1. Executive Summary (2-3 sentences)
2. Critical Issues (if any) with specific data
3. Passed Validations (brief list)
4. Recommendations with reasoning

Be specific, factual, and actionable. Use actual data from the documents.
Keep the tone professional but conversational.
Focus on what the ASM needs to know to make a decision.");

            chatHistory.AddUserMessage(prompt);

            var response = await chatService.GetChatMessageContentAsync(
                chatHistory,
                cancellationToken: cancellationToken);

            return response.Content ?? GenerateFallbackEvidence(package, categories, summary);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "AI evidence generation failed, using fallback");
            return GenerateFallbackEvidence(package, categories, summary);
        }
    }

    private string BuildEvidencePrompt(
        DocumentPackage package,
        List<ValidationCategoryDto> categories,
        ValidationSummaryDto summary)
    {
        var sb = new StringBuilder();
        
        sb.AppendLine("Generate a detailed validation report for this document package:");
        sb.AppendLine();
        sb.AppendLine($"Package ID: {package.Id}");
        sb.AppendLine($"Submitted by: {package.SubmittedBy?.FullName ?? "Unknown Agency"}");
        sb.AppendLine($"Submission Date: {package.CreatedAt:yyyy-MM-dd}");
        sb.AppendLine($"Overall Confidence: {summary.OverallConfidence:F1}%");
        sb.AppendLine($"Recommendation: {summary.RecommendationType}");
        sb.AppendLine($"Risk Level: {summary.RiskLevel}");
        sb.AppendLine();

        sb.AppendLine("Validation Results:");
        foreach (var category in categories)
        {
            sb.AppendLine($"- {category.CategoryName}: {category.Status} ({category.Severity})");
            if (category.Details != null)
            {
                sb.AppendLine($"  Expected: {category.Details.ExpectedValue}");
                sb.AppendLine($"  Actual: {category.Details.ActualValue}");
                sb.AppendLine($"  Impact: {category.Details.Impact}");
            }
        }

        sb.AppendLine();
        sb.AppendLine("Generate a professional report with:");
        sb.AppendLine("1. Brief executive summary");
        sb.AppendLine("2. List of critical/high priority issues with specific data");
        sb.AppendLine("3. Brief mention of passed validations");
        sb.AppendLine("4. Clear recommendation with reasoning");

        return sb.ToString();
    }

    private string GenerateFallbackEvidence(
        DocumentPackage package,
        List<ValidationCategoryDto> categories,
        ValidationSummaryDto summary)
    {
        var sb = new StringBuilder();

        // Executive Summary
        sb.AppendLine("EXECUTIVE SUMMARY");
        sb.AppendLine("─────────────────");
        sb.AppendLine($"Package submitted by {package.SubmittedBy?.FullName ?? "Unknown Agency"} on {package.CreatedAt:yyyy-MM-dd}.");
        sb.AppendLine($"Overall confidence score: {summary.OverallConfidence:F1}%.");
        
        if (summary.RecommendationType == "Approve")
        {
            sb.AppendLine("All critical validations passed. Package is ready for approval.");
        }
        else if (summary.RecommendationType == "RequestResubmission")
        {
            sb.AppendLine($"Package requires resubmission to address {summary.HighPriorityIssues} high priority issues.");
        }
        else
        {
            sb.AppendLine($"Package must be rejected due to {summary.CriticalIssues} critical issues.");
        }
        sb.AppendLine();

        // Critical Issues
        var criticalCategories = categories.Where(c => !c.Passed && c.Severity == "Critical").ToList();
        if (criticalCategories.Any())
        {
            sb.AppendLine("CRITICAL ISSUES");
            sb.AppendLine("───────────────");
            foreach (var category in criticalCategories)
            {
                sb.AppendLine($"❌ {category.CategoryName}");
                if (category.Details != null)
                {
                    sb.AppendLine($"   Expected: {category.Details.ExpectedValue}");
                    sb.AppendLine($"   Actual: {category.Details.ActualValue}");
                    sb.AppendLine($"   Impact: {category.Details.Impact}");
                    sb.AppendLine($"   Action: {category.Details.SuggestedAction}");
                }
                sb.AppendLine();
            }
        }

        // High Priority Issues
        var highCategories = categories.Where(c => !c.Passed && c.Severity == "High").ToList();
        if (highCategories.Any())
        {
            sb.AppendLine("HIGH PRIORITY ISSUES");
            sb.AppendLine("────────────────────");
            foreach (var category in highCategories)
            {
                sb.AppendLine($"⚠️  {category.CategoryName}");
                if (category.Details != null)
                {
                    sb.AppendLine($"   {category.Details.Description}");
                    sb.AppendLine($"   Action: {category.Details.SuggestedAction}");
                }
                sb.AppendLine();
            }
        }

        // Medium Priority Issues
        var mediumCategories = categories.Where(c => !c.Passed && c.Severity == "Medium").ToList();
        if (mediumCategories.Any())
        {
            sb.AppendLine("MEDIUM PRIORITY ISSUES");
            sb.AppendLine("──────────────────────");
            foreach (var category in mediumCategories)
            {
                sb.AppendLine($"⚠️  {category.CategoryName}: {category.ShortDescription}");
            }
            sb.AppendLine();
        }

        // Passed Validations
        var passedCategories = categories.Where(c => c.Passed).ToList();
        if (passedCategories.Any())
        {
            sb.AppendLine("PASSED VALIDATIONS");
            sb.AppendLine("──────────────────");
            foreach (var category in passedCategories.Take(5))
            {
                sb.AppendLine($"✅ {category.ShortDescription}");
            }
            if (passedCategories.Count > 5)
            {
                sb.AppendLine($"   ... and {passedCategories.Count - 5} more");
            }
            sb.AppendLine();
        }

        // Recommendation
        sb.AppendLine("RECOMMENDATION");
        sb.AppendLine("──────────────");
        sb.AppendLine($"Risk Assessment: {summary.RiskLevel}");
        sb.AppendLine($"Recommended Action: {summary.RecommendationType.ToUpper()}");
        sb.AppendLine();

        if (summary.RecommendationType == "Approve")
        {
            sb.AppendLine("This submission meets all requirements and is ready for approval.");
        }
        else if (summary.RecommendationType == "RequestResubmission")
        {
            sb.AppendLine("Request resubmission with specific feedback on the issues listed above.");
            sb.AppendLine("The agency should address all high priority issues before resubmitting.");
        }
        else
        {
            sb.AppendLine("Reject this submission due to critical issues that cannot be resolved through resubmission.");
            sb.AppendLine("Provide detailed feedback to the agency explaining the reasons for rejection.");
        }

        return sb.ToString();
    }
}
