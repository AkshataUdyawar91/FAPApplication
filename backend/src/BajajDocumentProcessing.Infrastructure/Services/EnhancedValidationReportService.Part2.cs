using BajajDocumentProcessing.Application.DTOs.Submissions;
using BajajDocumentProcessing.Domain.Entities;
using System.Text;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Part 2: Confidence calculation and summary building methods
/// </summary>
public partial class EnhancedValidationReportService
{
    // ─── CONFIDENCE CALCULATION ──────────────────────────────────────────

    private ConfidenceBreakdownDto CalculateValidationBasedConfidence(
        DocumentPackage package,
        ValidationResult? validationResult,
        ConfidenceScore? confidenceScore,
        List<ValidationCategoryDto> categories)
    {
        // Calculate confidence based on validation pass rate
        var poCategories = categories.Where(c => 
            c.CategoryName.Contains("PO") || 
            c.CategoryName.Contains("SAP")).ToList();
        var invoiceCategories = categories.Where(c => 
            c.CategoryName.Contains("Invoice") || 
            c.CategoryName.Contains("Amount") ||
            c.CategoryName.Contains("GST")).ToList();
        var photoCategories = categories.Where(c => 
            c.CategoryName.Contains("Photo") || 
            c.CategoryName.Contains("Branding")).ToList();
        var otherCategories = categories.Except(poCategories)
            .Except(invoiceCategories)
            .Except(photoCategories).ToList();

        var poConfidence = CalculateDocumentConfidence(poCategories, "PO");
        var invoiceConfidence = CalculateDocumentConfidence(invoiceCategories, "Invoice");
        var photoConfidence = CalculateDocumentConfidence(photoCategories, "Photos");
        
        // For cost summary and activity, use extraction confidence if available
        var costSummaryConfidence = new DocumentConfidenceDto
        {
            Score = confidenceScore?.CostSummaryConfidence ?? 0,
            Weight = COST_SUMMARY_WEIGHT,
            PassedChecks = 0,
            TotalChecks = 0,
            PassedValidations = new List<string> { "Document extracted" },
            FailedValidations = new List<string>()
        };

        var activityConfidence = new DocumentConfidenceDto
        {
            Score = confidenceScore?.ActivityConfidence ?? 0,
            Weight = ACTIVITY_WEIGHT,
            PassedChecks = 0,
            TotalChecks = 0,
            PassedValidations = new List<string> { "Document extracted" },
            FailedValidations = new List<string>()
        };

        // Calculate overall weighted confidence
        var overallConfidence = 
            (poConfidence.Score * PO_WEIGHT) +
            (invoiceConfidence.Score * INVOICE_WEIGHT) +
            (costSummaryConfidence.Score * COST_SUMMARY_WEIGHT) +
            (activityConfidence.Score * ACTIVITY_WEIGHT) +
            (photoConfidence.Score * PHOTOS_WEIGHT);

        return new ConfidenceBreakdownDto
        {
            OverallConfidence = overallConfidence,
            POConfidence = poConfidence,
            InvoiceConfidence = invoiceConfidence,
            CostSummaryConfidence = costSummaryConfidence,
            ActivityConfidence = activityConfidence,
            PhotosConfidence = photoConfidence
        };
    }

    private DocumentConfidenceDto CalculateDocumentConfidence(
        List<ValidationCategoryDto> categories,
        string documentType)
    {
        if (!categories.Any())
        {
            return new DocumentConfidenceDto
            {
                Score = 0,
                Weight = GetWeightForDocumentType(documentType),
                PassedChecks = 0,
                TotalChecks = 0,
                PassedValidations = new List<string>(),
                FailedValidations = new List<string>()
            };
        }

        var passedCount = categories.Count(c => c.Passed);
        var totalCount = categories.Count;
        var score = totalCount > 0 ? (double)passedCount / totalCount * 100 : 0;

        return new DocumentConfidenceDto
        {
            Score = score,
            Weight = GetWeightForDocumentType(documentType),
            PassedChecks = passedCount,
            TotalChecks = totalCount,
            PassedValidations = categories.Where(c => c.Passed)
                .Select(c => c.CategoryName).ToList(),
            FailedValidations = categories.Where(c => !c.Passed)
                .Select(c => c.CategoryName).ToList()
        };
    }

    private double GetWeightForDocumentType(string documentType)
    {
        return documentType switch
        {
            "PO" => PO_WEIGHT,
            "Invoice" => INVOICE_WEIGHT,
            "CostSummary" => COST_SUMMARY_WEIGHT,
            "Activity" => ACTIVITY_WEIGHT,
            "Photos" => PHOTOS_WEIGHT,
            _ => 0
        };
    }

    // ─── SUMMARY BUILDING ────────────────────────────────────────────────

    private ValidationSummaryDto BuildSummary(
        List<ValidationCategoryDto> categories,
        ConfidenceBreakdownDto confidenceBreakdown,
        Recommendation? recommendation)
    {
        var totalValidations = categories.Count;
        var passedValidations = categories.Count(c => c.Passed);
        var failedValidations = totalValidations - passedValidations;

        var criticalIssues = categories.Count(c => !c.Passed && c.Severity == "Critical");
        var highPriorityIssues = categories.Count(c => !c.Passed && c.Severity == "High");
        var mediumPriorityIssues = categories.Count(c => !c.Passed && c.Severity == "Medium");

        var recommendationType = DetermineRecommendationType(
            confidenceBreakdown.OverallConfidence,
            criticalIssues,
            highPriorityIssues);

        var riskLevel = DetermineRiskLevel(criticalIssues, highPriorityIssues, mediumPriorityIssues);

        return new ValidationSummaryDto
        {
            OverallConfidence = confidenceBreakdown.OverallConfidence,
            TotalValidations = totalValidations,
            PassedValidations = passedValidations,
            FailedValidations = failedValidations,
            CriticalIssues = criticalIssues,
            HighPriorityIssues = highPriorityIssues,
            MediumPriorityIssues = mediumPriorityIssues,
            RecommendationType = recommendationType,
            RiskLevel = riskLevel
        };
    }

    private string DetermineRecommendationType(
        double confidence,
        int criticalIssues,
        int highPriorityIssues)
    {
        // REJECT if any critical issues
        if (criticalIssues > 0)
        {
            return "Reject";
        }

        // REJECT if confidence < 70%
        if (confidence < 70)
        {
            return "Reject";
        }

        // REQUEST RESUBMISSION if high priority issues or confidence 70-85%
        if (highPriorityIssues > 0 || confidence < 85)
        {
            return "RequestResubmission";
        }

        // APPROVE if confidence >= 85% and no critical/high issues
        return "Approve";
    }

    private string DetermineRiskLevel(
        int criticalIssues,
        int highPriorityIssues,
        int mediumPriorityIssues)
    {
        if (criticalIssues > 0)
        {
            return "High";
        }

        if (highPriorityIssues > 0)
        {
            return "Medium";
        }

        if (mediumPriorityIssues > 0)
        {
            return "Low";
        }

        return "Low";
    }

    // ─── RECOMMENDATION BUILDING ─────────────────────────────────────────

    private EnhancedRecommendationDto BuildRecommendationDto(
        Recommendation? recommendation,
        List<ValidationCategoryDto> categories,
        ValidationSummaryDto summary)
    {
        var criticalIssues = categories
            .Where(c => !c.Passed && c.Severity == "Critical" && c.Details != null)
            .Select(c => new IssueDto
            {
                Title = c.Details!.Title,
                Description = c.Details.Description,
                ExpectedValue = c.Details.ExpectedValue,
                ActualValue = c.Details.ActualValue,
                Impact = c.Details.Impact,
                SuggestedResolution = c.Details.SuggestedAction,
                Severity = "Critical"
            })
            .ToList();

        var highPriorityIssues = categories
            .Where(c => !c.Passed && c.Severity == "High" && c.Details != null)
            .Select(c => new IssueDto
            {
                Title = c.Details!.Title,
                Description = c.Details.Description,
                ExpectedValue = c.Details.ExpectedValue,
                ActualValue = c.Details.ActualValue,
                Impact = c.Details.Impact,
                SuggestedResolution = c.Details.SuggestedAction,
                Severity = "High"
            })
            .ToList();

        var mediumPriorityIssues = categories
            .Where(c => !c.Passed && c.Severity == "Medium" && c.Details != null)
            .Select(c => new IssueDto
            {
                Title = c.Details!.Title,
                Description = c.Details.Description,
                ExpectedValue = c.Details.ExpectedValue,
                ActualValue = c.Details.ActualValue,
                Impact = c.Details.Impact,
                SuggestedResolution = c.Details.SuggestedAction,
                Severity = "Medium"
            })
            .ToList();

        var passedValidations = categories
            .Where(c => c.Passed)
            .Select(c => c.ShortDescription)
            .ToList();

        var recommendationSummary = BuildRecommendationSummary(
            summary.RecommendationType,
            criticalIssues.Count,
            highPriorityIssues.Count,
            mediumPriorityIssues.Count);

        var recommendedAction = BuildRecommendedAction(
            summary.RecommendationType,
            criticalIssues,
            highPriorityIssues);

        return new EnhancedRecommendationDto
        {
            Type = summary.RecommendationType,
            Summary = recommendationSummary,
            CriticalIssues = criticalIssues,
            HighPriorityIssues = highPriorityIssues,
            MediumPriorityIssues = mediumPriorityIssues,
            PassedValidations = passedValidations,
            RiskAssessment = summary.RiskLevel,
            RecommendedAction = recommendedAction
        };
    }

    private string BuildRecommendationSummary(
        string recommendationType,
        int criticalCount,
        int highCount,
        int mediumCount)
    {
        return recommendationType switch
        {
            "Approve" => "All critical validations passed. Package is ready for approval.",
            "RequestResubmission" => $"Package requires resubmission. Found {highCount} high priority and {mediumCount} medium priority issues that need to be addressed.",
            "Reject" => $"Package must be rejected. Found {criticalCount} critical issues that block approval.",
            _ => "Unable to determine recommendation."
        };
    }

    private string BuildRecommendedAction(
        string recommendationType,
        List<IssueDto> criticalIssues,
        List<IssueDto> highPriorityIssues)
    {
        return recommendationType switch
        {
            "Approve" => "APPROVE this submission for processing.",
            "RequestResubmission" => $"REQUEST RESUBMISSION with specific feedback on: {string.Join(", ", highPriorityIssues.Take(3).Select(i => i.Title))}",
            "Reject" => $"REJECT this submission due to: {string.Join(", ", criticalIssues.Take(3).Select(i => i.Title))}",
            _ => "Review manually and make a decision."
        };
    }
}
