using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Application.DTOs.Submissions;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;
using System.Text;
using System.Text.Json;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for generating enhanced validation reports with detailed evidence
/// </summary>
public partial class EnhancedValidationReportService : IEnhancedValidationReportService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<EnhancedValidationReportService> _logger;
    private readonly Kernel _kernel;
    private readonly ICorrelationIdService _correlationIdService;

    // Confidence score weights
    private const double PO_WEIGHT = 0.30;
    private const double INVOICE_WEIGHT = 0.30;
    private const double COST_SUMMARY_WEIGHT = 0.20;
    private const double ACTIVITY_WEIGHT = 0.10;
    private const double PHOTOS_WEIGHT = 0.10;

    public EnhancedValidationReportService(
        IApplicationDbContext context,
        IConfiguration configuration,
        ILogger<EnhancedValidationReportService> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _logger = logger;
        _correlationIdService = correlationIdService;

        // Build Semantic Kernel for AI evidence generation
        var endpoint = configuration["AzureOpenAI:Endpoint"] ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        _kernel = builder.Build();
    }

    /// <summary>
    /// Generates a comprehensive validation report for a document package
    /// </summary>
    public async Task<EnhancedValidationReportDto> GenerateReportAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Generating enhanced validation report for package {PackageId}. CorrelationId: {CorrelationId}",
            packageId, correlationId);

        try
        {
            // 1. Load all data
            var package = await LoadPackageWithAllDataAsync(packageId, cancellationToken);
            // TODO: ValidationResult is now polymorphic (per document type), not per package
            // Need to refactor to load validation results for each document type
            // For now, validation report will work without ValidationResult data
            // var validationResult = await LoadValidationResultAsync(packageId, cancellationToken);
            var confidenceScore = await LoadConfidenceScoreAsync(packageId, cancellationToken);
            var recommendation = await LoadRecommendationAsync(packageId, cancellationToken);

            // 2. Build validation categories (without ValidationResult for now)
            var categories = BuildValidationCategories(package, null);

            // 3. Calculate validation-based confidence
            var confidenceBreakdown = CalculateValidationBasedConfidence(
                package, null, confidenceScore, categories);

            // 4. Build summary
            var summary = BuildSummary(categories, confidenceBreakdown, recommendation);

            // 5. Generate detailed evidence with AI
            var detailedEvidence = await GenerateDetailedEvidenceAsync(
                package, null, categories, summary, cancellationToken);

            // 6. Build recommendation DTO
            var recommendationDto = BuildRecommendationDto(
                recommendation, categories, summary);

            _logger.LogInformation(
                "Enhanced validation report generated successfully for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);

            return new EnhancedValidationReportDto
            {
                Summary = summary,
                Categories = categories,
                ConfidenceBreakdown = confidenceBreakdown,
                Recommendation = recommendationDto,
                DetailedEvidence = detailedEvidence
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error generating enhanced validation report for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
            throw;
        }
    }

    // ─── DATA LOADING METHODS ────────────────────────────────────────────

    private async Task<DocumentPackage> LoadPackageWithAllDataAsync(
        Guid packageId,
        CancellationToken cancellationToken)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.PO)
            .Include(p => p.Invoices)
            .Include(p => p.CostSummary)
            .Include(p => p.Teams)
                .ThenInclude(t => t.Photos)
            .AsSplitQuery()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

        if (package == null)
        {
            throw new Domain.Exceptions.NotFoundException($"Package {packageId} not found");
        }

        return package;
    }

    // TODO: ValidationResult is now polymorphic (per document type), not per package
    // This method is temporarily disabled until we refactor to handle per-document validation
    private async Task<ValidationResult?> LoadValidationResultAsync(
        Guid packageId,
        CancellationToken cancellationToken)
    {
        // return await _context.ValidationResults
        //     .FirstOrDefaultAsync(v => v.PackageId == packageId, cancellationToken);
        return null;
    }

    private async Task<ConfidenceScore?> LoadConfidenceScoreAsync(
        Guid packageId,
        CancellationToken cancellationToken)
    {
        return await _context.ConfidenceScores
            .FirstOrDefaultAsync(cs => cs.PackageId == packageId, cancellationToken);
    }

    private async Task<Recommendation?> LoadRecommendationAsync(
        Guid packageId,
        CancellationToken cancellationToken)
    {
        return await _context.Recommendations
            .FirstOrDefaultAsync(r => r.PackageId == packageId, cancellationToken);
    }

    // ─── VALIDATION CATEGORIES BUILDER ───────────────────────────────────

    private List<ValidationCategoryDto> BuildValidationCategories(
        DocumentPackage package,
        ValidationResult? validationResult)
    {
        var categories = new List<ValidationCategoryDto>();

        // 1. PO Number Cross-Validation
        categories.Add(BuildPONumberValidation(package));

        // 2. Invoice Amount Validation
        categories.Add(BuildInvoiceAmountValidation(package));

        // 3. Date Validation
        categories.Add(BuildDateValidation(package));

        // 4. Vendor Matching
        categories.Add(BuildVendorValidation(package));

        // 5. SAP Verification (disabled - ValidationResult is now polymorphic)
        // TODO: Refactor to load SAP validation from document-level ValidationResult
        // if (validationResult != null)
        // {
        //     categories.Add(BuildSAPValidation(validationResult));
        // }

        // 6. Document Completeness
        categories.Add(BuildCompletenessValidation(package));

        // 7. Team Photo Quality
        categories.Add(BuildTeamPhotoValidation(package));

        // 8. Branding Visibility
        categories.Add(BuildBrandingValidation(package));

        // 9. Campaign Duration
        categories.Add(BuildCampaignDurationValidation(package));

        // 10. GST Validation
        categories.Add(BuildGSTValidation(package));

        return categories;
    }

    // ─── INDIVIDUAL VALIDATION BUILDERS ──────────────────────────────────

    private ValidationCategoryDto BuildPONumberValidation(DocumentPackage package)
    {
        var poEntity = package.PO;
        var invoiceEntity = package.Invoices.FirstOrDefault();

        if (poEntity?.ExtractedDataJson == null || invoiceEntity?.ExtractedDataJson == null)
        {
            return new ValidationCategoryDto
            {
                CategoryName = "PO Number Cross-Validation",
                CategoryIcon = "description",
                Passed = false,
                Status = "Failed",
                Severity = "Critical",
                ShortDescription = "Missing PO or Invoice document"
            };
        }

        var poData = JsonSerializer.Deserialize<POData>(poEntity.ExtractedDataJson);
        var invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceEntity.ExtractedDataJson);

        var poNumberMatch = poData?.PONumber?.Equals(
            invoiceData?.PONumber,
            StringComparison.OrdinalIgnoreCase) ?? false;

        return new ValidationCategoryDto
        {
            CategoryName = "PO Number Cross-Validation",
            CategoryIcon = "check_circle",
            Passed = poNumberMatch,
            Status = poNumberMatch ? "Passed" : "Failed",
            Severity = poNumberMatch ? "Low" : "Critical",
            ShortDescription = poNumberMatch
                ? "PO number matches between invoice and PO document"
                : "PO number mismatch detected",
            Details = poNumberMatch ? null : new ValidationDetailDto
            {
                Title = "PO Number Mismatch",
                Description = "The PO number referenced in the invoice does not match the PO document number.",
                ExpectedValue = $"PO Number: {poData?.PONumber ?? "N/A"}",
                ActualValue = $"Invoice references: {invoiceData?.PONumber ?? "N/A"}",
                Impact = "Critical - Documents do not match, possible fraud risk or data entry error",
                SuggestedAction = "Verify the correct PO number and request corrected invoice",
                AffectedDocuments = new List<string> { "Purchase Order", "Invoice" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "PO Document Number", poData?.PONumber ?? "N/A" },
                    { "Invoice PO Reference", invoiceData?.PONumber ?? "N/A" }
                }
            }
        };
    }

    private ValidationCategoryDto BuildInvoiceAmountValidation(DocumentPackage package)
    {
        var poEntity = package.PO;
        var invoiceEntity = package.Invoices.FirstOrDefault();

        if (poEntity?.ExtractedDataJson == null || invoiceEntity?.ExtractedDataJson == null)
        {
            return new ValidationCategoryDto
            {
                CategoryName = "Invoice Amount Validation",
                CategoryIcon = "attach_money",
                Passed = false,
                Status = "Failed",
                Severity = "Critical",
                ShortDescription = "Missing PO or Invoice document"
            };
        }

        var poData = JsonSerializer.Deserialize<POData>(poEntity.ExtractedDataJson);
        var invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceEntity.ExtractedDataJson);

        var invoiceAmount = invoiceData?.TotalAmount ?? 0;
        var poAmount = poData?.TotalAmount ?? 0;
        var withinLimit = invoiceAmount <= poAmount;
        var difference = invoiceAmount - poAmount;
        var percentageOver = poAmount > 0 ? (difference / poAmount) * 100 : 0;

        return new ValidationCategoryDto
        {
            CategoryName = "Invoice Amount Validation",
            CategoryIcon = "attach_money",
            Passed = withinLimit,
            Status = withinLimit ? "Passed" : "Failed",
            Severity = withinLimit ? "Low" : "Critical",
            ShortDescription = withinLimit
                ? $"Invoice amount within PO limit (₹{invoiceAmount:N2} / ₹{poAmount:N2})"
                : $"Invoice amount exceeds PO limit by ₹{difference:N2}",
            Details = withinLimit ? null : new ValidationDetailDto
            {
                Title = "Invoice Amount Exceeds PO Limit",
                Description = "The invoice amount is greater than the approved PO amount.",
                ExpectedValue = $"Invoice Amount ≤ ₹{poAmount:N2}",
                ActualValue = $"Invoice Amount: ₹{invoiceAmount:N2}",
                Impact = $"Critical - Unauthorized expenditure of ₹{difference:N2} ({percentageOver:F1}% over limit)",
                SuggestedAction = "Reject submission - exceeds approved budget. Request revised invoice or PO amendment.",
                AffectedDocuments = new List<string> { "Purchase Order", "Invoice" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "PO Amount", $"₹{poAmount:N2}" },
                    { "Invoice Amount", $"₹{invoiceAmount:N2}" },
                    { "Excess Amount", $"₹{difference:N2}" },
                    { "Percentage Over", $"{percentageOver:F1}%" }
                }
            }
        };
    }

    private ValidationCategoryDto BuildDateValidation(DocumentPackage package)
    {
        var poEntity = package.PO;
        var invoiceEntity = package.Invoices.FirstOrDefault();

        if (poEntity?.ExtractedDataJson == null || invoiceEntity?.ExtractedDataJson == null)
        {
            return new ValidationCategoryDto
            {
                CategoryName = "Date Validation",
                CategoryIcon = "calendar_today",
                Passed = false,
                Status = "Failed",
                Severity = "High",
                ShortDescription = "Missing PO or Invoice document"
            };
        }

        var poData = JsonSerializer.Deserialize<POData>(poEntity.ExtractedDataJson);
        var invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceEntity.ExtractedDataJson);

        var poDate = poData?.PODate ?? DateTime.MinValue;
        var invoiceDate = invoiceData?.InvoiceDate ?? DateTime.MinValue;
        var submissionDate = package.CreatedAt;

        var issues = new List<string>();
        if (invoiceDate < poDate)
        {
            issues.Add($"Invoice date ({invoiceDate:yyyy-MM-dd}) is before PO date ({poDate:yyyy-MM-dd})");
        }
        if (invoiceDate > submissionDate)
        {
            issues.Add($"Invoice date ({invoiceDate:yyyy-MM-dd}) is after submission date ({submissionDate:yyyy-MM-dd})");
        }

        var isValid = issues.Count == 0;

        return new ValidationCategoryDto
        {
            CategoryName = "Date Validation",
            CategoryIcon = "calendar_today",
            Passed = isValid,
            Status = isValid ? "Passed" : "Failed",
            Severity = isValid ? "Low" : "Critical",
            ShortDescription = isValid
                ? "All dates are valid and in correct sequence"
                : "Date sequence validation failed",
            Details = isValid ? null : new ValidationDetailDto
            {
                Title = "Invalid Date Sequence",
                Description = string.Join(". ", issues),
                ExpectedValue = $"PO Date ≤ Invoice Date ≤ Submission Date",
                ActualValue = $"PO: {poDate:yyyy-MM-dd}, Invoice: {invoiceDate:yyyy-MM-dd}, Submission: {submissionDate:yyyy-MM-dd}",
                Impact = "Critical - Timeline inconsistency indicates potential document manipulation",
                SuggestedAction = "Reject submission - investigate date discrepancies",
                AffectedDocuments = new List<string> { "Purchase Order", "Invoice" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "PO Date", poDate.ToString("yyyy-MM-dd") },
                    { "Invoice Date", invoiceDate.ToString("yyyy-MM-dd") },
                    { "Submission Date", submissionDate.ToString("yyyy-MM-dd") }
                }
            }
        };
    }

    private ValidationCategoryDto BuildVendorValidation(DocumentPackage package)
    {
        var poEntity = package.PO;
        var invoiceEntity = package.Invoices.FirstOrDefault();

        if (poEntity?.ExtractedDataJson == null || invoiceEntity?.ExtractedDataJson == null)
        {
            return new ValidationCategoryDto
            {
                CategoryName = "Vendor Matching",
                CategoryIcon = "business",
                Passed = true,
                Status = "Passed",
                Severity = "Low",
                ShortDescription = "Vendor validation skipped - missing documents"
            };
        }

        var poData = JsonSerializer.Deserialize<POData>(poEntity.ExtractedDataJson);
        var invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceEntity.ExtractedDataJson);

        var poVendor = poData?.VendorName?.Trim().ToLowerInvariant() ?? "";
        var invoiceVendor = invoiceData?.VendorName?.Trim().ToLowerInvariant() ?? "";

        var isMatch = poVendor == invoiceVendor;

        return new ValidationCategoryDto
        {
            CategoryName = "Vendor Matching",
            CategoryIcon = "business",
            Passed = isMatch,
            Status = isMatch ? "Passed" : "Warning",
            Severity = isMatch ? "Low" : "Medium",
            ShortDescription = isMatch
                ? "Vendor name matches across documents"
                : "Vendor name variation detected (acceptable)",
            Details = isMatch ? null : new ValidationDetailDto
            {
                Title = "Vendor Name Variation",
                Description = "Vendor names have slight variations across documents. This is common and acceptable.",
                ExpectedValue = $"Vendor from PO: {poData?.VendorName ?? "N/A"}",
                ActualValue = $"Vendor from Invoice: {invoiceData?.VendorName ?? "N/A"}",
                Impact = "Medium - Verify this is the same vendor with name variation (e.g., 'Pvt Ltd' vs 'Private Limited')",
                SuggestedAction = "Review vendor names - acceptable if same entity with different legal name format",
                AffectedDocuments = new List<string> { "Purchase Order", "Invoice" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "PO Vendor", poData?.VendorName ?? "N/A" },
                    { "Invoice Vendor", invoiceData?.VendorName ?? "N/A" }
                }
            }
        };
    }

    private ValidationCategoryDto BuildSAPValidation(ValidationResult validationResult)
    {
        var sapPassed = validationResult.SapVerificationPassed;

        return new ValidationCategoryDto
        {
            CategoryName = "SAP Verification",
            CategoryIcon = "verified",
            Passed = sapPassed,
            Status = sapPassed ? "Passed" : "Failed",
            Severity = sapPassed ? "Low" : "High",
            ShortDescription = sapPassed
                ? "PO verified successfully in SAP system"
                : "SAP verification failed or PO not found",
            Details = sapPassed ? null : new ValidationDetailDto
            {
                Title = "SAP Verification Failed",
                Description = "The PO number could not be verified in the SAP system.",
                ExpectedValue = "PO exists in SAP with matching details",
                ActualValue = "PO not found or details mismatch",
                Impact = "High - Cannot verify PO authenticity against enterprise system",
                SuggestedAction = "Verify PO number is correct. If SAP is unavailable, proceed with manual verification.",
                AffectedDocuments = new List<string> { "Purchase Order" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "SAP Status", "Verification Failed" }
                }
            }
        };
    }

    private ValidationCategoryDto BuildCompletenessValidation(DocumentPackage package)
    {
        var photos = package.Teams.SelectMany(t => t.Photos).ToList();
        var requiredDocs = new Dictionary<string, bool>
        {
            { "Purchase Order", package.PO != null },
            { "Invoice", package.Invoices.Any() },
            { "Cost Summary", package.CostSummary != null },
            { "Photos", photos.Any() }
        };

        var missingDocs = requiredDocs.Where(kvp => !kvp.Value).Select(kvp => kvp.Key).ToList();
        var isComplete = missingDocs.Count == 0;
        var totalDocCount = (package.PO != null ? 1 : 0)
            + package.Invoices.Count
            + (package.CostSummary != null ? 1 : 0)
            + photos.Count;

        return new ValidationCategoryDto
        {
            CategoryName = "Document Completeness",
            CategoryIcon = "folder_open",
            Passed = isComplete,
            Status = isComplete ? "Passed" : "Failed",
            Severity = isComplete ? "Low" : "Critical",
            ShortDescription = isComplete
                ? "All required documents present"
                : $"Missing {missingDocs.Count} required document(s)",
            Details = isComplete ? null : new ValidationDetailDto
            {
                Title = "Incomplete Document Package",
                Description = "Some required documents are missing from the submission.",
                ExpectedValue = "PO, Invoice, Cost Summary, and at least 1 Photo",
                ActualValue = $"Missing: {string.Join(", ", missingDocs)}",
                Impact = "Critical - Cannot process incomplete submission",
                SuggestedAction = $"Request missing documents: {string.Join(", ", missingDocs)}",
                AffectedDocuments = missingDocs,
                AdditionalData = new Dictionary<string, string>
                {
                    { "Total Documents", totalDocCount.ToString() },
                    { "Missing Count", missingDocs.Count.ToString() }
                }
            }
        };
    }

    private ValidationCategoryDto BuildTeamPhotoValidation(DocumentPackage package)
    {
        var photos = package.Teams.SelectMany(t => t.Photos).ToList();

        if (!photos.Any())
        {
            return new ValidationCategoryDto
            {
                CategoryName = "Team Photo Quality",
                CategoryIcon = "photo_camera",
                Passed = false,
                Status = "Failed",
                Severity = "High",
                ShortDescription = "No photos uploaded"
            };
        }

        // Check for photos with metadata indicating team members
        var photosWithFaces = 0;
        foreach (var photo in photos)
        {
            if (photo.ExtractedMetadataJson != null)
            {
                try
                {
                    var metadata = JsonSerializer.Deserialize<Application.DTOs.Documents.PhotoMetadata>(photo.ExtractedMetadataJson);
                    if (metadata?.HasHumanFace == true)
                    {
                        photosWithFaces++;
                    }
                }
                catch
                {
                    // Skip if deserialization fails
                }
            }
        }

        var qualityGood = photosWithFaces >= Math.Min(3, photos.Count);

        return new ValidationCategoryDto
        {
            CategoryName = "Team Photo Quality",
            CategoryIcon = "photo_camera",
            Passed = qualityGood,
            Status = qualityGood ? "Passed" : "Warning",
            Severity = qualityGood ? "Low" : "Medium",
            ShortDescription = qualityGood
                ? $"Photo quality acceptable ({photosWithFaces} of {photos.Count} photos show clear team members)"
                : $"Only {photosWithFaces} of {photos.Count} photos show clear team members",
            Details = qualityGood ? null : new ValidationDetailDto
            {
                Title = "Team Photo Quality Issue",
                Description = "Some photos do not show clear faces of team members.",
                ExpectedValue = $"At least {Math.Min(3, photos.Count)} photos with clear team member faces",
                ActualValue = $"{photosWithFaces} photos with clear faces detected",
                Impact = "Medium - Cannot verify team participation adequately",
                SuggestedAction = "Request additional clear photos showing team members with visible faces",
                AffectedDocuments = new List<string> { "Photos" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "Total Photos", photos.Count.ToString() },
                    { "Photos with Clear Faces", photosWithFaces.ToString() },
                    { "Required", Math.Min(3, photos.Count).ToString() }
                }
            }
        };
    }

    private ValidationCategoryDto BuildBrandingValidation(DocumentPackage package)
    {
        var photos = package.Teams.SelectMany(t => t.Photos).ToList();

        if (!photos.Any())
        {
            return new ValidationCategoryDto
            {
                CategoryName = "Branding Visibility",
                CategoryIcon = "branding_watermark",
                Passed = false,
                Status = "Failed",
                Severity = "High",
                ShortDescription = "No photos uploaded"
            };
        }

        // Check for photos with Bajaj branding
        var photosWithBranding = 0;
        var photosWithoutBranding = new List<int>();
        
        for (int i = 0; i < photos.Count; i++)
        {
            var photo = photos[i];
            if (photo.ExtractedMetadataJson != null)
            {
                try
                {
                    var metadata = JsonSerializer.Deserialize<Application.DTOs.Documents.PhotoMetadata>(photo.ExtractedMetadataJson);
                    if (metadata?.HasBajajVehicle == true)
                    {
                        photosWithBranding++;
                    }
                    else
                    {
                        photosWithoutBranding.Add(i + 1);
                    }
                }
                catch
                {
                    photosWithoutBranding.Add(i + 1);
                }
            }
            else
            {
                photosWithoutBranding.Add(i + 1);
            }
        }

        var brandingGood = photosWithBranding >= Math.Max(1, photos.Count / 2);

        return new ValidationCategoryDto
        {
            CategoryName = "Branding Visibility",
            CategoryIcon = "branding_watermark",
            Passed = brandingGood,
            Status = brandingGood ? "Passed" : "Failed",
            Severity = brandingGood ? "Low" : "High",
            ShortDescription = brandingGood
                ? $"Bajaj branding visible in {photosWithBranding} of {photos.Count} photos"
                : $"Bajaj logo not clearly visible in Stage Photo #{string.Join(", #", photosWithoutBranding)}",
            Details = brandingGood ? null : new ValidationDetailDto
            {
                Title = "Branding Visibility Issue",
                Description = "Bajaj logo or branding is not clearly visible in some stage photos.",
                ExpectedValue = "Bajaj logo clearly visible in at least half of the photos",
                ActualValue = $"Logo detected in only {photosWithBranding} of {photos.Count} photos",
                Impact = "High - Brand compliance requirement not met",
                SuggestedAction = $"Request clearer photos showing Bajaj branding, especially for Photo #{string.Join(", #", photosWithoutBranding.Take(3))}",
                AffectedDocuments = new List<string> { "Photos" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "Total Photos", photos.Count.ToString() },
                    { "Photos with Branding", photosWithBranding.ToString() },
                    { "Photos without Branding", string.Join(", ", photosWithoutBranding.Select(n => $"#{n}")) }
                }
            }
        };
    }

    private ValidationCategoryDto BuildCampaignDurationValidation(DocumentPackage package)
    {
        // TODO: Campaign duration validation disabled - date fields moved to Teams entity
        // Need to refactor to validate dates from Teams collection
        return new ValidationCategoryDto
        {
            CategoryName = "Campaign Duration",
            CategoryIcon = "event",
            Passed = true,
            Status = "Passed",
            Severity = "Low",
            ShortDescription = "Campaign duration validation not yet implemented for new schema"
        };
    }

    private ValidationCategoryDto BuildGSTValidation(DocumentPackage package)
    {
        var invoiceEntity = package.Invoices.FirstOrDefault();

        if (invoiceEntity?.ExtractedDataJson == null)
        {
            return new ValidationCategoryDto
            {
                CategoryName = "GST Validation",
                CategoryIcon = "receipt",
                Passed = true,
                Status = "Passed",
                Severity = "Low",
                ShortDescription = "GST validation skipped - missing invoice"
            };
        }

        var invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceEntity.ExtractedDataJson);
        var gstNumber = invoiceData?.GSTNumber ?? "";
        var stateCode = invoiceData?.StateCode ?? "";

        // Basic GST validation: first 2 digits should match state code
        var isValid = true;
        if (!string.IsNullOrEmpty(gstNumber) && gstNumber.Length >= 2 && !string.IsNullOrEmpty(stateCode))
        {
            var gstStateCode = gstNumber.Substring(0, 2);
            isValid = gstStateCode == stateCode;
        }

        return new ValidationCategoryDto
        {
            CategoryName = "GST Validation",
            CategoryIcon = "receipt",
            Passed = isValid,
            Status = isValid ? "Passed" : "Failed",
            Severity = isValid ? "Low" : "High",
            ShortDescription = isValid
                ? "GST number matches state code"
                : "GST number does not match state code",
            Details = isValid ? null : new ValidationDetailDto
            {
                Title = "GST State Code Mismatch",
                Description = "The GST number's state code does not match the invoice state code.",
                ExpectedValue = $"GST state code should match invoice state: {stateCode}",
                ActualValue = $"GST Number: {gstNumber}",
                Impact = "High - Compliance requirement not met",
                SuggestedAction = "Verify GST number is correct for the state",
                AffectedDocuments = new List<string> { "Invoice" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "GST Number", gstNumber },
                    { "State Code", stateCode }
                }
            }
        };
    }
}
