using System.Globalization;
using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Assembles strongly-typed DTOs with all token values needed for
/// adaptive card and email template population.
/// </summary>
public class NotificationDataService : INotificationDataService
{
    private readonly IApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<NotificationDataService> _logger;

    /// <summary>
    /// Indian number format culture for ₹ currency formatting.
    /// </summary>
    private static readonly CultureInfo IndianCulture = new("en-IN");

    /// <summary>
    /// Total number of validation boolean checks on ValidationResult.
    /// </summary>
    private const int TotalValidationChecks = 6;

    /// <summary>
    /// Maximum number of top issues to display on the card.
    /// </summary>
    private const int MaxTopIssues = 3;

    public NotificationDataService(
        IApplicationDbContext context,
        IConfiguration configuration,
        ILogger<NotificationDataService> logger)
    {
        _context = context;
        _configuration = configuration;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<SubmissionCardData> GetSubmissionCardDataAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Assembling submission card data for package {PackageId}", packageId);

        var package = await _context.DocumentPackages
            .Include(p => p.PO)
            .Include(p => p.Agency)
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.Teams.Where(t => !t.IsDeleted))
                .ThenInclude(t => t.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.Teams.Where(t => !t.IsDeleted))
                .ThenInclude(t => t.Photos.Where(ph => !ph.IsDeleted))
            .Include(p => p.CostSummary)
            .Include(p => p.ActivitySummary)
            .Include(p => p.EnquiryDocument)
            .Include(p => p.ConfidenceScore)
            .Include(p => p.Recommendation)
            .AsSplitQuery()
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

        if (package is null)
        {
            _logger.LogWarning("DocumentPackage {PackageId} not found for card data assembly", packageId);
            throw new InvalidOperationException($"DocumentPackage {packageId} not found.");
        }

        // ValidationResult uses polymorphic relationship (DocumentType + DocumentId).
        // Load it separately via the PO's Id since it's linked to the PO document.
        if (package.PO != null)
        {
            package.ValidationResult = await _context.ValidationResults
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    vr => vr.DocumentId == package.PO.Id && vr.DocumentType == DocumentType.PO,
                    cancellationToken);
        }

        // Load ALL validation results for all documents in this package (for detailed check groups)
        var allDocumentIds = new List<Guid>();
        if (package.PO != null) allDocumentIds.Add(package.PO.Id);
        var allTeamInvoices = package.Teams.SelectMany(t => t.Invoices).ToList();
        foreach (var inv in allTeamInvoices)
            allDocumentIds.Add(inv.Id);
        // Chatbot flow: also add direct package invoices
        foreach (var inv in package.Invoices)
            if (!allDocumentIds.Contains(inv.Id)) allDocumentIds.Add(inv.Id);

        // CostSummary, ActivitySummary, EnquiryDocument, Invoices are now loaded in the main query above.
        // Add their IDs for validation result lookup.
        if (package.CostSummary != null) allDocumentIds.Add(package.CostSummary.Id);
        if (package.ActivitySummary != null) allDocumentIds.Add(package.ActivitySummary.Id);
        if (package.EnquiryDocument != null) allDocumentIds.Add(package.EnquiryDocument.Id);
        // Add photo IDs so photo-level ValidationResults are loaded
        foreach (var photo in package.Teams.SelectMany(t => t.Photos).Where(p => !p.IsDeleted))
            allDocumentIds.Add(photo.Id);

        // Chatbot flow: PO is referenced via SelectedPOId, not via the PO navigation property.
        // Load it from the POs table so MapKeyFacts can read PONumber and TotalAmount.
        if (package.PO == null && package.SelectedPOId.HasValue)
        {
            package.PO = await _context.POs
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == package.SelectedPOId.Value && !p.IsDeleted, cancellationToken);
        }

        // Chatbot flow: load invoice validation results linked to the invoice document
        // (chatbot stores ValidationResults by invoice DocumentId, not by PO DocumentId)
        if (package.ValidationResult == null && package.Invoices.Any())
        {
            var firstInvoiceId = package.Invoices.First().Id;
            package.ValidationResult = await _context.ValidationResults
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    vr => vr.DocumentId == firstInvoiceId && vr.DocumentType == DocumentType.Invoice,
                    cancellationToken);
        }

        var allValidationResults = allDocumentIds.Count > 0
            ? await _context.ValidationResults
                .AsNoTracking()
                .Where(vr => allDocumentIds.Contains(vr.DocumentId))
                .ToListAsync(cancellationToken)
            : new List<Domain.Entities.ValidationResult>();

        // Also load by DocumentType for any missing results
        var foundDocTypes = allValidationResults.Select(vr => vr.DocumentType).ToHashSet();
        var missingDocTypes = new List<Domain.Enums.DocumentType>();
        if (package.PO != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.PO))
            missingDocTypes.Add(Domain.Enums.DocumentType.PO);
        if (package.CostSummary != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.CostSummary))
            missingDocTypes.Add(Domain.Enums.DocumentType.CostSummary);
        if (package.ActivitySummary != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.ActivitySummary))
            missingDocTypes.Add(Domain.Enums.DocumentType.ActivitySummary);
        if (package.EnquiryDocument != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.EnquiryDocument))
            missingDocTypes.Add(Domain.Enums.DocumentType.EnquiryDocument);
        if (allTeamInvoices.Count > 0 && !foundDocTypes.Contains(Domain.Enums.DocumentType.Invoice))
            missingDocTypes.Add(Domain.Enums.DocumentType.Invoice);

        if (missingDocTypes.Count > 0)
        {
            var additionalResults = await _context.ValidationResults
                .AsNoTracking()
                .Where(vr => missingDocTypes.Contains(vr.DocumentType))
                .ToListAsync(cancellationToken);

            var existingIds = allValidationResults.Select(vr => vr.Id).ToHashSet();
            allValidationResults.AddRange(additionalResults.Where(r => !existingIds.Contains(r.Id)));
        }

        var cardData = new SubmissionCardData
        {
            SubmissionId = package.Id,
            SubmissionNumber = package.SubmissionNumber ?? ("FAP-" + package.Id.ToString()[..8].ToUpper()),
            NotificationTimestamp = DateTime.UtcNow
        };

        // === Key Facts ===
        MapKeyFacts(cardData, package);

        // === AI Recommendation ===
        MapRecommendation(cardData, package);

        // === Validation Checks & Issues ===
        MapValidationChecks(cardData, package);

        // === Detailed Check Groups (per-document validation table) ===
        // Load photo ValidationResults separately by DocumentType + PackageId — most reliable approach
        // since photo DocumentIds may not always be in allDocumentIds if Teams.Photos was empty above.
        var photoIds = package.Teams
            .SelectMany(t => t.Photos)
            .Where(p => !p.IsDeleted)
            .Select(p => p.Id)
            .ToList();
        if (photoIds.Count > 0)
        {
            var photoVrs = await _context.ValidationResults
                .AsNoTracking()
                .Where(vr => vr.DocumentType == DocumentType.TeamPhoto && photoIds.Contains(vr.DocumentId))
                .ToListAsync(cancellationToken);
            // Merge into allValidationResults (avoid duplicates)
            var existingVrIds = allValidationResults.Select(v => v.Id).ToHashSet();
            allValidationResults.AddRange(photoVrs.Where(v => !existingVrIds.Contains(v.Id)));
        }
        cardData.CheckGroups = BuildCheckGroupsFromAllDocuments(package, allValidationResults);

        // === Override recommendation if orchestrator hasn't run (no AI recommendation) ===
        // Score-based: calculate pass rate across all check groups; ≥70% → Approve, <70% → Reject
        if (package.Recommendation is null)
        {
            var totalChecks = cardData.CheckGroups.Count;
            var passedChecks = cardData.CheckGroups.Count(g =>
                g.Status?.Equals("Pass", StringComparison.OrdinalIgnoreCase) == true);
            var passRate = totalChecks > 0 ? (double)passedChecks / totalChecks : 0.0;
            var approve = passRate >= 0.70;
            cardData.Recommendation = approve ? "Approve" : "Reject";
            cardData.RecommendationEmoji = approve ? "✅" : "❌";
            cardData.ConfidenceScore = (int)Math.Round(passRate * 100);
            cardData.ConfidenceScoreFormatted = $"{passedChecks}/{totalChecks} checks passed";
        }

        // === Action Buttons ===
        cardData.ShowQuickApprove = package.Recommendation?.Type == RecommendationType.Approve;

        var portalBaseUrl = _configuration["TeamsBot:PortalBaseUrl"] ?? string.Empty;
        cardData.PortalUrl = $"{portalBaseUrl}/fap/{package.Id}/review";

        _logger.LogInformation(
            "Card data assembled for {SubmissionNumber} — Recommendation={Recommendation}, Confidence={Confidence}",
            cardData.SubmissionNumber, cardData.Recommendation, cardData.ConfidenceScore);

        return cardData;
    }

    /// <summary>
    /// Maps key facts from the package to the card data DTO.
    /// </summary>
    private static void MapKeyFacts(SubmissionCardData cardData, Domain.Entities.DocumentPackage package)
    {
        cardData.AgencyName = package.Agency?.SupplierName ?? "N/A";

        // PO Number with ExtractedDataJson fallback
        cardData.PoNumber = package.PO?.PONumber ?? TryExtractPoNumber(package.PO?.ExtractedDataJson) ?? "N/A";

        // Invoice number + amount: check Teams.Invoices first (dashboard flow),
        // then fall back to package.Invoices (chatbot flow).
        // Use anonymous projection to unify the two different invoice entity types.
        var teamInvoices = package.Teams
            .SelectMany(t => t.Invoices)
            .Select(i => new { i.InvoiceNumber, i.TotalAmount, IsDeleted = false })
            .ToList();

        var invoiceProjections = teamInvoices.Count > 0
            ? teamInvoices
            : package.Invoices
                .Where(i => !i.IsDeleted)
                .Select(i => new { i.InvoiceNumber, i.TotalAmount, IsDeleted = i.IsDeleted })
                .ToList();

        cardData.InvoiceNumber = invoiceProjections
            .Select(i => i.InvoiceNumber)
            .FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "N/A";

        // Invoice amount: sum of TotalAmount across all invoices
        var totalAmount = invoiceProjections
            .Where(i => i.TotalAmount.HasValue)
            .Sum(i => i.TotalAmount!.Value);

        cardData.InvoiceAmountRaw = totalAmount;
        cardData.InvoiceAmount = FormatIndianCurrency(totalAmount);

        // State: Teams.State first (dashboard flow), fall back to package.ActivityState (chatbot flow)
        cardData.State = package.Teams
            .Select(t => t.State)
            .FirstOrDefault(s => !string.IsNullOrWhiteSpace(s))
            ?? package.ActivityState
            ?? "N/A";

        // Submitted timestamp
        cardData.SubmittedAt = package.CreatedAt;
        cardData.SubmittedAtFormatted = package.CreatedAt.ToString("dd-MMM-yyyy, hh:mm tt", CultureInfo.InvariantCulture);

        // Team and photo counts
        cardData.TeamCount = package.Teams.Count;
        cardData.PhotoCount = package.Teams.SelectMany(t => t.Photos).Count();
        cardData.TeamPhotoSummary = $"{cardData.TeamCount} teams | {cardData.PhotoCount} photos";

        // Inquiry summary from EnquiryDocument
        cardData.InquirySummary = ParseInquirySummary(package.EnquiryDocument?.ExtractedDataJson);
    }

    /// <summary>
    /// Maps AI recommendation fields from the package to the card data DTO.
    /// </summary>
    private static void MapRecommendation(SubmissionCardData cardData, Domain.Entities.DocumentPackage package)
    {
        if (package.Recommendation is null)
        {
            // Orchestrator hasn't run yet — derive a basic recommendation from invoice validation results.
            // Binary: all checks passed → Approve, any failure → Reject.
            if (package.ValidationResult != null)
            {
                var allPassed = package.ValidationResult.AllValidationsPassed;
                cardData.Recommendation = allPassed ? "Approve" : "Reject";
                cardData.RecommendationEmoji = allPassed ? "✅" : "❌";
                cardData.CardStyle = "default";
                cardData.ConfidenceScore = 0;
                cardData.ConfidenceScoreFormatted = "Pending";
            }
            else
            {
                // No validation result at all — count fails across all check groups
                // Default to Approve unless we have evidence of failures
                cardData.Recommendation = "Approve";
                cardData.RecommendationEmoji = "✅";
                cardData.CardStyle = "default";
                cardData.ConfidenceScore = 0;
                cardData.ConfidenceScoreFormatted = "Pending";
            }
            return;
        }

        var (cardStyle, emoji) = package.Recommendation.Type switch
        {
            RecommendationType.Approve => ("default", "✅"),
            RecommendationType.Review => ("default", "⚠️"),
            RecommendationType.Reject => ("default", "❌"),
            _ => ("default", "❓")
        };

        cardData.Recommendation = package.Recommendation.Type.ToString();
        cardData.RecommendationEmoji = emoji;
        cardData.CardStyle = cardStyle;
        cardData.ConfidenceScore = package.ConfidenceScore?.OverallConfidence ?? 0;
        cardData.ConfidenceScoreFormatted = $"{cardData.ConfidenceScore:0}/100";
    }

    /// <summary>
    /// Maps validation check counts and top issues from the package to the card data DTO.
    /// </summary>
    private static void MapValidationChecks(SubmissionCardData cardData, Domain.Entities.DocumentPackage package)
    {
        var vr = package.ValidationResult;
        if (vr is null)
        {
            cardData.TotalChecks = TotalValidationChecks;
            cardData.PassedChecks = 0;
            cardData.ChecksSummary = $"0/{TotalValidationChecks} checks passed";
            cardData.AllChecksPassed = false;
            return;
        }

        // Count passed checks from the 6 boolean fields
        var passedChecks = new[]
        {
            vr.SapVerificationPassed,
            vr.AmountConsistencyPassed,
            vr.LineItemMatchingPassed,
            vr.CompletenessCheckPassed,
            vr.DateValidationPassed,
            vr.VendorMatchingPassed
        }.Count(b => b);

        cardData.TotalChecks = TotalValidationChecks;
        cardData.PassedChecks = passedChecks;
        cardData.ChecksSummary = $"{passedChecks}/{TotalValidationChecks} checks passed";
        cardData.AllChecksPassed = vr.AllValidationsPassed;

        // Collect failed checks as issues
        var issues = CollectValidationIssues(vr, package.Recommendation?.ValidationIssuesJson);

        // Sort: Fail before Warning
        issues.Sort((a, b) =>
        {
            var order = SeverityOrder(a.Severity).CompareTo(SeverityOrder(b.Severity));
            return order != 0 ? order : string.Compare(a.Description, b.Description, StringComparison.Ordinal);
        });

        cardData.TopIssues = issues.Take(MaxTopIssues).ToList();
        cardData.RemainingIssueCount = Math.Max(0, issues.Count - MaxTopIssues);
        cardData.RemainingIssueText = cardData.RemainingIssueCount > 0
            ? $"... and {cardData.RemainingIssueCount} more issues"
            : string.Empty;
    }

    /// <summary>
    /// Collects validation issues from failed boolean checks and detail JSON sources.
    /// </summary>
    private static List<ValidationIssueItem> CollectValidationIssues(
        Domain.Entities.ValidationResult vr,
        string? recommendationIssuesJson)
    {
        // Map each boolean field to its check name
        var checkMap = new (bool Passed, string CheckName)[]
        {
            (vr.SapVerificationPassed, "SAP Verification"),
            (vr.AmountConsistencyPassed, "Amount Consistency"),
            (vr.LineItemMatchingPassed, "Line Item Matching"),
            (vr.CompletenessCheckPassed, "Completeness Check"),
            (vr.DateValidationPassed, "Date Validation"),
            (vr.VendorMatchingPassed, "Vendor Matching")
        };

        // Parse RuleResultsJson for detailed descriptions
        var detailDescriptions = ParseValidationDetailsJson(vr.RuleResultsJson);

        var issues = new List<ValidationIssueItem>();

        foreach (var (passed, checkName) in checkMap)
        {
            if (passed) continue;

            var description = detailDescriptions.GetValueOrDefault(checkName)
                              ?? $"{checkName} failed";

            issues.Add(new ValidationIssueItem
            {
                Severity = "Fail",
                Description = description
            });
        }

        // Also parse recommendation ValidationIssuesJson for any Warning-level items
        if (!string.IsNullOrWhiteSpace(recommendationIssuesJson))
        {
            try
            {
                using var doc = JsonDocument.Parse(recommendationIssuesJson);
                if (doc.RootElement.ValueKind == JsonValueKind.Array)
                {
                    foreach (var element in doc.RootElement.EnumerateArray())
                    {
                        // Skip non-object elements (plain strings, numbers, etc.)
                        if (element.ValueKind != JsonValueKind.Object)
                            continue;

                        var severity = element.TryGetProperty("severity", out var sevProp)
                            ? sevProp.GetString() ?? "Warning"
                            : "Warning";
                        var desc = element.TryGetProperty("description", out var descProp)
                            ? descProp.GetString() ?? string.Empty
                            : string.Empty;

                        if (string.IsNullOrWhiteSpace(desc)) continue;

                        // Avoid duplicating issues already captured from boolean checks
                        if (issues.Any(i => i.Description.Equals(desc, StringComparison.OrdinalIgnoreCase)))
                            continue;

                        issues.Add(new ValidationIssueItem
                        {
                            Severity = severity.Equals("Fail", StringComparison.OrdinalIgnoreCase) ? "Fail" : "Warning",
                            Description = desc
                        });
                    }
                }
            }
            catch (Exception ex) when (ex is JsonException or InvalidOperationException)
            {
                // Malformed or unexpected JSON structure — skip silently
            }
        }

        return issues;
    }

    /// <summary>
    /// Returns a sort order value for severity: Fail=0, Warning=1, others=2.
    /// </summary>
    private static int SeverityOrder(string severity) => severity switch
    {
        "Fail" => 0,
        "Warning" => 1,
        _ => 2
    };

    /// <summary>
    /// Parses ValidationDetailsJson into a dictionary of check name → description.
    /// Supports both object-with-named-keys and array-of-objects formats.
    /// </summary>
    private static Dictionary<string, string> ParseValidationDetailsJson(string? json)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(json)) return result;

        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            // Determine the array to parse — handle both formats:
            // 1. {"checks": [{...}, ...]}  (object wrapper with inner array)
            // 2. [{...}, ...]              (flat array)
            // 3. {"SAP Verification": "description", ...} (flat object with string values)
            // 4. {"SAP Verification": {"description": "..."}, ...} (flat object with nested objects)
            JsonElement arrayToParse = default;
            var hasArray = false;

            if (root.ValueKind == JsonValueKind.Object)
            {
                // Check if it's a wrapper like {"checks": [...]}
                if (root.TryGetProperty("checks", out var checksArray) && checksArray.ValueKind == JsonValueKind.Array)
                {
                    arrayToParse = checksArray;
                    hasArray = true;
                }
                else
                {
                    // Flat object: key = check name, value = string or {description: "..."}
                    foreach (var prop in root.EnumerateObject())
                    {
                        string? description = null;
                        if (prop.Value.ValueKind == JsonValueKind.String)
                        {
                            description = prop.Value.GetString();
                        }
                        else if (prop.Value.ValueKind == JsonValueKind.Object &&
                                 prop.Value.TryGetProperty("description", out var descProp))
                        {
                            description = descProp.GetString();
                        }

                        if (!string.IsNullOrWhiteSpace(description))
                            result[prop.Name] = description!;
                    }
                }
            }
            else if (root.ValueKind == JsonValueKind.Array)
            {
                arrayToParse = root;
                hasArray = true;
            }

            // Parse array elements: [{name: "...", details: "..."}, ...]
            if (hasArray)
            {
                foreach (var element in arrayToParse.EnumerateArray())
                {
                    if (element.ValueKind != JsonValueKind.Object) continue;

                    var name = element.TryGetProperty("checkName", out var nameProp)
                        ? nameProp.GetString()
                        : element.TryGetProperty("name", out var n) ? n.GetString() : null;
                    var desc = element.TryGetProperty("description", out var descProp)
                        ? descProp.GetString()
                        : element.TryGetProperty("details", out var d) ? d.GetString() : null;

                    if (!string.IsNullOrWhiteSpace(name) && !string.IsNullOrWhiteSpace(desc))
                        result[name!] = desc!;
                }
            }
        }
        catch (JsonException)
        {
            // Malformed JSON — return empty
        }

        return result;
    }

    /// <summary>
    /// Attempts to extract a PO number from the PO's ExtractedDataJson as a fallback.
    /// </summary>
    private static string? TryExtractPoNumber(string? extractedDataJson)
    {
        if (string.IsNullOrWhiteSpace(extractedDataJson)) return null;

        try
        {
            using var doc = JsonDocument.Parse(extractedDataJson);
            if (doc.RootElement.TryGetProperty("poNumber", out var poNum))
                return poNum.GetString();
            if (doc.RootElement.TryGetProperty("PONumber", out var poNum2))
                return poNum2.GetString();
            if (doc.RootElement.TryGetProperty("po_number", out var poNum3))
                return poNum3.GetString();
        }
        catch (JsonException)
        {
            // Malformed JSON — return null
        }

        return null;
    }

    /// <summary>
    /// Parses the EnquiryDocument ExtractedDataJson to produce a human-readable inquiry summary.
    /// Expected format: { "totalRecords": 87, "completeRecords": 84 } or similar.
    /// </summary>
    private static string ParseInquirySummary(string? extractedDataJson)
    {
        if (string.IsNullOrWhiteSpace(extractedDataJson)) return "N/A";

        try
        {
            using var doc = JsonDocument.Parse(extractedDataJson);
            var root = doc.RootElement;

            // Try various casing variants for TotalRecords
            int? total = null;
            foreach (var key in new[] { "TotalRecords", "totalRecords", "total_records", "Total" })
            {
                if (root.TryGetProperty(key, out var t) && t.ValueKind == JsonValueKind.Number)
                { total = t.GetInt32(); break; }
            }

            // If TotalRecords not found, count the Records array
            if (!total.HasValue)
            {
                foreach (var key in new[] { "Records", "records" })
                {
                    if (root.TryGetProperty(key, out var arr) && arr.ValueKind == JsonValueKind.Array)
                    { total = arr.GetArrayLength(); break; }
                }
            }

            int? complete = null;
            foreach (var key in new[] { "CompleteRecords", "completeRecords", "complete_records" })
            {
                if (root.TryGetProperty(key, out var c) && c.ValueKind == JsonValueKind.Number)
                { complete = c.GetInt32(); break; }
            }

            if (total.HasValue && complete.HasValue)
                return $"{total.Value} records ({complete.Value} complete)";

            if (total.HasValue)
                return $"{total.Value} records";

            return "N/A";
        }
        catch (JsonException)
        {
            return "N/A";
        }
    }

    /// <summary>
    /// Formats a decimal amount in Indian ₹ currency format (e.g., ₹1,25,000).
    /// </summary>
    private static string FormatIndianCurrency(decimal amount)
    {
        return "₹" + amount.ToString("N0", IndianCulture);
    }

    /// <inheritdoc />
    public async Task<ValidationBreakdownData> GetValidationBreakdownAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Assembling validation breakdown for package {PackageId}", packageId);

        var package = await _context.DocumentPackages
            .Include(p => p.PO)
            .Include(p => p.Invoices)
            .Include(p => p.CostSummary)
            .Include(p => p.ActivitySummary)
            .Include(p => p.EnquiryDocument)
            .Include(p => p.Teams).ThenInclude(t => t.Invoices)
            .Include(p => p.Teams).ThenInclude(t => t.Photos.Where(ph => !ph.IsDeleted))
            .AsSplitQuery()
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

        if (package is null)
        {
            _logger.LogWarning("DocumentPackage {PackageId} not found for validation breakdown", packageId);
            throw new InvalidOperationException($"DocumentPackage {packageId} not found.");
        }

        // Collect all document IDs in this package to load their validation results
        var documentIds = new List<Guid>();
        if (package.PO != null) documentIds.Add(package.PO.Id);
        if (package.CostSummary != null) documentIds.Add(package.CostSummary.Id);
        if (package.ActivitySummary != null) documentIds.Add(package.ActivitySummary.Id);
        if (package.EnquiryDocument != null) documentIds.Add(package.EnquiryDocument.Id);
        foreach (var inv in package.Invoices.Where(i => !i.IsDeleted))
            documentIds.Add(inv.Id);
        foreach (var inv in package.Teams.SelectMany(t => t.Invoices))
            documentIds.Add(inv.Id);

        // Load ALL validation results for all documents in this package
        // Also load by DocumentType to catch results linked to team invoice IDs
        var allValidationResults = new List<Domain.Entities.ValidationResult>();
        if (documentIds.Count > 0)
        {
            allValidationResults = await _context.ValidationResults
                .AsNoTracking()
                .Where(vr => documentIds.Contains(vr.DocumentId))
                .ToListAsync(cancellationToken);
        }

        // Also load any validation results by DocumentType that weren't found by ID
        var foundDocTypes = allValidationResults.Select(vr => vr.DocumentType).ToHashSet();
        var missingDocTypes = new List<Domain.Enums.DocumentType>();
        if (package.PO != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.PO))
            missingDocTypes.Add(Domain.Enums.DocumentType.PO);
        if (package.CostSummary != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.CostSummary))
            missingDocTypes.Add(Domain.Enums.DocumentType.CostSummary);
        if (package.ActivitySummary != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.ActivitySummary))
            missingDocTypes.Add(Domain.Enums.DocumentType.ActivitySummary);
        if (package.EnquiryDocument != null && !foundDocTypes.Contains(Domain.Enums.DocumentType.EnquiryDocument))
            missingDocTypes.Add(Domain.Enums.DocumentType.EnquiryDocument);
        if (package.Invoices.Any(i => !i.IsDeleted) && !foundDocTypes.Contains(Domain.Enums.DocumentType.Invoice))
            missingDocTypes.Add(Domain.Enums.DocumentType.Invoice);

        if (missingDocTypes.Count > 0)
        {
            // Find validation results for this package's documents by type
            // We need to search across all possible document IDs in the package
            var additionalResults = await _context.ValidationResults
                .AsNoTracking()
                .Where(vr => missingDocTypes.Contains(vr.DocumentType))
                .ToListAsync(cancellationToken);

            // Only add results that aren't already in our list
            var existingIds = allValidationResults.Select(vr => vr.Id).ToHashSet();
            allValidationResults.AddRange(additionalResults.Where(r => !existingIds.Contains(r.Id)));
        }

        // Load latest approval history separately to avoid split query issues
        var latestHistory = await _context.RequestApprovalHistories
            .Include(h => h.Approver)
            .AsNoTracking()
            .Where(h => h.PackageId == packageId)
            .OrderByDescending(h => h.ActionDate)
            .FirstOrDefaultAsync(cancellationToken);

        var shortId = "FAP-" + package.Id.ToString()[..8].ToUpper();
        var portalBaseUrl = _configuration["TeamsBot:PortalBaseUrl"] ?? string.Empty;

        var breakdown = new ValidationBreakdownData
        {
            SubmissionId = package.Id,
            SubmissionNumber = shortId,
            CurrentStatus = package.State.ToString(),
            IsAlreadyProcessed = package.State != PackageState.PendingCH,
            PortalUrl = $"{portalBaseUrl}/fap/{package.Id}/review"
        };

        // Populate ProcessedBy/ProcessedAt from latest RequestApprovalHistory
        if (latestHistory is not null)
        {
            breakdown.ProcessedAt = latestHistory.ActionDate;
            breakdown.ProcessedBy = latestHistory.Approver?.FullName;
        }

        // Build validation check groups from ALL documents' validation results
        // Load photo ValidationResults separately by DocumentType + photo IDs
        var photoIdsBreakdown = package.Teams
            .SelectMany(t => t.Photos)
            .Where(p => !p.IsDeleted)
            .Select(p => p.Id)
            .ToList();
        if (photoIdsBreakdown.Count > 0)
        {
            var photoVrs = await _context.ValidationResults
                .AsNoTracking()
                .Where(vr => vr.DocumentType == DocumentType.TeamPhoto && photoIdsBreakdown.Contains(vr.DocumentId))
                .ToListAsync(cancellationToken);
            var existingVrIds = allValidationResults.Select(v => v.Id).ToHashSet();
            allValidationResults.AddRange(photoVrs.Where(v => !existingVrIds.Contains(v.Id)));
        }
        breakdown.CheckGroups = BuildCheckGroupsFromAllDocuments(package, allValidationResults);

        _logger.LogInformation(
            "Validation breakdown assembled for {SubmissionNumber} — {GroupCount} groups, IsAlreadyProcessed={IsProcessed}",
            shortId, breakdown.CheckGroups.Count, breakdown.IsAlreadyProcessed);

        return breakdown;
    }

    /// <summary>
    /// Builds validation check groups from the ValidationResult boolean fields.
    /// </summary>
    private static List<ValidationCheckGroup> BuildCheckGroups(Domain.Entities.ValidationResult? vr)
    {
        if (vr is null)
        {
            // Return all groups as "Fail" with no details when no validation result exists
            return new List<ValidationCheckGroup>
            {
                new() { GroupName = "SAP Verification", Status = "Fail" },
                new() { GroupName = "Amount Consistency", Status = "Fail" },
                new() { GroupName = "Line Item Matching", Status = "Fail" },
                new() { GroupName = "Completeness", Status = "Fail" },
                new() { GroupName = "Date Validation", Status = "Fail" },
                new() { GroupName = "Vendor Matching", Status = "Fail" }
            };
        }

        var detailDescriptions = ParseValidationDetailsJson(vr.RuleResultsJson);

        var checks = new (string GroupName, bool Passed, string DetailKey)[]
        {
            ("SAP Verification", vr.SapVerificationPassed, "SAP Verification"),
            ("Amount Consistency", vr.AmountConsistencyPassed, "Amount Consistency"),
            ("Line Item Matching", vr.LineItemMatchingPassed, "Line Item Matching"),
            ("Completeness", vr.CompletenessCheckPassed, "Completeness Check"),
            ("Date Validation", vr.DateValidationPassed, "Date Validation"),
            ("Vendor Matching", vr.VendorMatchingPassed, "Vendor Matching")
        };

        return checks.Select(c => new ValidationCheckGroup
        {
            GroupName = c.GroupName,
            Status = c.Passed ? "Pass" : "Fail",
            Details = !c.Passed ? detailDescriptions.GetValueOrDefault(c.DetailKey) : null
        }).ToList();
    }

    /// <summary>
    /// Builds a flat, numbered list of validation check groups from ALL documents in the package.
    /// Each row represents one check for one document type, with status and evidence text.
    /// </summary>
    private static List<ValidationCheckGroup> BuildCheckGroupsFromAllDocuments(
        Domain.Entities.DocumentPackage package,
        List<Domain.Entities.ValidationResult> allResults)
    {
        var groups = new List<ValidationCheckGroup>();

        // Cost Summary: use the same validation as the conversational chatbot (6 checks)
        var costSummary = package.CostSummary;
        if (costSummary != null && !costSummary.IsDeleted)
        {
            string? placeOfSupply = costSummary.PlaceOfSupply;
            int? numberOfDays = costSummary.NumberOfDays;
            int? numberOfActivations = costSummary.NumberOfActivations;
            int? numberOfTeams = costSummary.NumberOfTeams;
            string? elementWiseCosts = costSummary.ElementWiseCostsJson;
            string? elementWiseQuantity = costSummary.ElementWiseQuantityJson;

            // Fallback: parse from ExtractedDataJson if dedicated columns are empty
            if (!string.IsNullOrEmpty(costSummary.ExtractedDataJson))
            {
                try
                {
                    var json = JsonDocument.Parse(costSummary.ExtractedDataJson).RootElement;

                    if (string.IsNullOrWhiteSpace(placeOfSupply))
                    {
                        if (json.TryGetProperty("PlaceOfSupply", out var pos) || json.TryGetProperty("placeOfSupply", out pos))
                            placeOfSupply = pos.GetString();
                        if (string.IsNullOrWhiteSpace(placeOfSupply))
                            if (json.TryGetProperty("State", out var st) || json.TryGetProperty("state", out st))
                                placeOfSupply = st.GetString();
                    }
                    if (numberOfDays == null)
                        if (json.TryGetProperty("NumberOfDays", out var nd) || json.TryGetProperty("numberOfDays", out nd))
                            try { numberOfDays = nd.GetInt32(); } catch { }
                    if (numberOfActivations == null)
                        if (json.TryGetProperty("NumberOfActivations", out var na) || json.TryGetProperty("numberOfActivations", out na))
                            try { numberOfActivations = na.GetInt32(); } catch { }
                    if (numberOfTeams == null)
                        if (json.TryGetProperty("NumberOfTeams", out var nt) || json.TryGetProperty("numberOfTeams", out nt))
                            try { numberOfTeams = nt.GetInt32(); } catch { }
                    if (string.IsNullOrWhiteSpace(elementWiseCosts))
                        if (json.TryGetProperty("ElementWiseCostsJson", out var ewc) || json.TryGetProperty("elementWiseCostsJson", out ewc))
                            elementWiseCosts = ewc.GetString();
                    if (string.IsNullOrWhiteSpace(elementWiseQuantity))
                        if (json.TryGetProperty("ElementWiseQuantityJson", out var ewq) || json.TryGetProperty("elementWiseQuantityJson", out ewq))
                            elementWiseQuantity = ewq.GetString();
                }
                catch { /* malformed JSON */ }
            }

            // 1. Place of Supply
            bool posPresent = !string.IsNullOrWhiteSpace(placeOfSupply);
            groups.Add(new ValidationCheckGroup
            {
                GroupName = "Cost Summary",
                Status = posPresent ? "Pass" : "Fail",
                Details = "Place of Supply",
                Evidence = posPresent ? placeOfSupply! : "Place of supply / state not detected"
            });

            // 2. No. of Days
            bool daysPresent = numberOfDays.HasValue && numberOfDays.Value > 0;
            groups.Add(new ValidationCheckGroup
            {
                GroupName = "Cost Summary",
                Status = daysPresent ? "Pass" : "Fail",
                Details = "No. of Days",
                Evidence = daysPresent ? numberOfDays.ToString()! : "Total number of days not detected"
            });

            // 3. No. of Activations
            bool activationsPresent = numberOfActivations.HasValue && numberOfActivations.Value > 0;
            groups.Add(new ValidationCheckGroup
            {
                GroupName = "Cost Summary",
                Status = activationsPresent ? "Pass" : "Fail",
                Details = "No. of Activations",
                Evidence = activationsPresent ? numberOfActivations.ToString()! : "Number of activations not detected"
            });

            // 4. No. of Teams
            bool teamsPresent = numberOfTeams.HasValue && numberOfTeams.Value > 0;
            groups.Add(new ValidationCheckGroup
            {
                GroupName = "Cost Summary",
                Status = teamsPresent ? "Pass" : "Fail",
                Details = "No. of Teams",
                Evidence = teamsPresent ? numberOfTeams.ToString()! : "Number of teams not detected"
            });

            // 5. Element-wise Cost
            bool costsPresent = !string.IsNullOrWhiteSpace(elementWiseCosts) && elementWiseCosts != "[]";
            groups.Add(new ValidationCheckGroup
            {
                GroupName = "Cost Summary",
                Status = costsPresent ? "Pass" : "Fail",
                Details = "Element-wise Cost",
                Evidence = costsPresent ? "Cost breakdown detected" : "Element-wise cost breakdown not detected"
            });

            // 6. Element-wise Quantity
            bool qtyPresent = !string.IsNullOrWhiteSpace(elementWiseQuantity) && elementWiseQuantity != "[]";
            groups.Add(new ValidationCheckGroup
            {
                GroupName = "Cost Summary",
                Status = qtyPresent ? "Pass" : "Fail",
                Details = "Element-wise Quantity",
                Evidence = qtyPresent ? "Quantity breakdown detected" : "Element-wise quantity breakdown not detected"
            });
        }

        // Activity Summary: read from ValidationResults.RuleResultsJson (same pattern as Enquiry Dump)
        var actSummary = package.ActivitySummary;
        if (actSummary != null && !actSummary.IsDeleted)
        {
            var actVr = allResults.FirstOrDefault(vr =>
                vr.DocumentId == actSummary.Id ||
                vr.DocumentType == Domain.Enums.DocumentType.ActivitySummary);

            bool builtFromRules = false;
            if (actVr?.RuleResultsJson != null)
            {
                try
                {
                    var rules = JsonSerializer.Deserialize<List<EnquiryRuleResult>>(
                        actVr.RuleResultsJson,
                        new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                    if (rules != null && rules.Count > 0)
                    {
                        foreach (var rule in rules)
                        {
                            groups.Add(new ValidationCheckGroup
                            {
                                GroupName = "Activity Summary",
                                Status = rule.Passed ? "Pass" : "Fail",
                                Details = rule.Label ?? rule.RuleCode ?? "Check",
                                Evidence = rule.ExtractedValue
                                    ?? (rule.Passed ? "Present" : rule.Message ?? "Not detected")
                            });
                        }
                        builtFromRules = true;
                    }
                }
                catch { /* malformed JSON — fall through to hardcoded */ }
            }

            // Fallback: hardcoded 3-row layout if no RuleResultsJson available
            if (!builtFromRules)
            {
                string? dealerName = actSummary.DealerName;
                string? location = null;

                if (!string.IsNullOrEmpty(actSummary.ExtractedDataJson))
                {
                    try
                    {
                        var json = JsonDocument.Parse(actSummary.ExtractedDataJson).RootElement;
                        if (string.IsNullOrWhiteSpace(dealerName))
                        {
                            if (json.TryGetProperty("DealerName", out var dn) || json.TryGetProperty("dealerName", out dn))
                                dealerName = dn.GetString();
                        }
                        if (json.TryGetProperty("Rows", out var rows) || json.TryGetProperty("rows", out rows))
                        {
                            if (rows.ValueKind == JsonValueKind.Array && rows.GetArrayLength() > 0)
                            {
                                var first = rows[0];
                                if (string.IsNullOrWhiteSpace(dealerName))
                                {
                                    if (first.TryGetProperty("DealerName", out var rdn) || first.TryGetProperty("dealerName", out rdn))
                                        dealerName = rdn.GetString();
                                }
                                if (first.TryGetProperty("Location", out var loc) || first.TryGetProperty("location", out loc))
                                    location = loc.GetString();
                            }
                        }
                    }
                    catch { /* malformed JSON */ }
                }

                bool dealerPresent = !string.IsNullOrWhiteSpace(dealerName);
                bool locationPresent = !string.IsNullOrWhiteSpace(location);
                bool dealerLocationPassed = dealerPresent && locationPresent;

                string evidence;
                if (dealerLocationPassed)
                    evidence = string.Join(", ", new[] { dealerName, location }.Where(s => !string.IsNullOrWhiteSpace(s)));
                else if (!dealerPresent && !locationPresent)
                    evidence = "Dealer name and location not detected";
                else if (!dealerPresent)
                    evidence = $"Location: {location} — Dealer name not detected";
                else
                    evidence = $"Dealer: {dealerName} — Location not detected";

                groups.Add(new ValidationCheckGroup
                {
                    GroupName = "Activity Summary",
                    Status = dealerLocationPassed ? "Pass" : "Fail",
                    Details = "Dealer & Location Details",
                    Evidence = evidence
                });
                groups.Add(new ValidationCheckGroup
                {
                    GroupName = "Activity Summary",
                    Status = "Pass",
                    Details = "Total No. of Days",
                    Evidence = actSummary.TotalDays.HasValue ? actSummary.TotalDays.ToString()! : "Not extracted"
                });
                groups.Add(new ValidationCheckGroup
                {
                    GroupName = "Activity Summary",
                    Status = "Pass",
                    Details = "Total No. of Working Days",
                    Evidence = actSummary.TotalWorkingDays.HasValue ? actSummary.TotalWorkingDays.ToString()! : "Not extracted"
                });
            }
        }

        // Invoice: use the same 9 specific checks as the conversational chatbot.
        // Check both direct Invoices and CampaignInvoices (via Teams) since seed data
        // uses CampaignInvoices linked through Teams, not direct Invoices.
        var directInvoices = package.Invoices.Where(i => !i.IsDeleted).ToList();
        var campaignInvoices = package.Teams
            .SelectMany(t => t.Invoices)
            .Where(i => !i.IsDeleted)
            .ToList();

        // Use direct invoices if available, otherwise fall back to campaign invoices
        string? invNumber = directInvoices.FirstOrDefault()?.InvoiceNumber
            ?? campaignInvoices.FirstOrDefault()?.InvoiceNumber;
        DateTime? invDate = directInvoices.FirstOrDefault()?.InvoiceDate
            ?? campaignInvoices.FirstOrDefault()?.InvoiceDate;
        decimal? invAmount = directInvoices.FirstOrDefault()?.TotalAmount
            ?? campaignInvoices.FirstOrDefault()?.TotalAmount;
        string? invGst = directInvoices.FirstOrDefault()?.GSTNumber
            ?? campaignInvoices.FirstOrDefault()?.GSTNumber;
        string? invExtractedJson = directInvoices.FirstOrDefault()?.ExtractedDataJson
            ?? campaignInvoices.FirstOrDefault()?.ExtractedDataJson;
        int invoiceCount = directInvoices.Count > 0 ? directInvoices.Count : campaignInvoices.Count;
        bool hasInvoice = invoiceCount > 0;

        if (hasInvoice)
        {
            var invoiceLabel = invoiceCount > 1 ? $"Invoices ({invoiceCount})" : "Invoice";
            var po = package.PO;

            // Parse ExtractedDataJson once for field lookups
            JsonElement? extractedJson = null;
            if (!string.IsNullOrEmpty(invExtractedJson))
            {
                try { extractedJson = JsonDocument.Parse(invExtractedJson).RootElement; }
                catch { /* malformed JSON */ }
            }

            // 1. Invoice Number
            var invNumPresent = !string.IsNullOrWhiteSpace(invNumber);
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = invNumPresent ? "Pass" : "Fail",
                Details = "Invoice Number",
                Evidence = invNumPresent ? invNumber! : "Invoice number not detected"
            });

            // 2. Invoice Date
            var datePresent = invDate.HasValue && invDate.Value != default;
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = datePresent ? "Pass" : "Fail",
                Details = "Invoice Date",
                Evidence = datePresent ? invDate!.Value.ToString("dd-MMM-yyyy") : "Invoice date not detected"
            });

            // 3. Invoice Amount
            var amountPresent = invAmount.HasValue && invAmount.Value > 0;
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = amountPresent ? "Pass" : "Fail",
                Details = "Invoice Amount",
                Evidence = amountPresent ? $"₹{invAmount!.Value:N0}" : "Invoice amount not detected"
            });

            // 4. GST Number (15-char alphanumeric)
            var gstPresent = !string.IsNullOrWhiteSpace(invGst) && invGst.Length == 15;
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = gstPresent ? "Pass" : "Fail",
                Details = "GST Number",
                Evidence = gstPresent
                    ? invGst!
                    : (string.IsNullOrWhiteSpace(invGst) ? "Not detected" : "Invalid format (must be 15 chars)")
            });

            // 5. GST %
            decimal? gstPercent = null;
            if (extractedJson.HasValue)
            {
                if (extractedJson.Value.TryGetProperty("GSTPercentage", out var gp) ||
                    extractedJson.Value.TryGetProperty("gstPercentage", out gp) ||
                    extractedJson.Value.TryGetProperty("gstPercent", out gp))
                {
                    try { gstPercent = gp.GetDecimal(); } catch { /* not a number */ }
                }
            }
            var gstPercentPresent = gstPercent.HasValue && gstPercent.Value > 0;
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = gstPercentPresent ? "Pass" : "Fail",
                Details = "GST %",
                Evidence = gstPercentPresent ? $"{gstPercent!.Value}%" : "GST percentage not detected"
            });

            // 6. HSN/SAC Code
            string? hsnSac = null;
            if (extractedJson.HasValue)
            {
                if (extractedJson.Value.TryGetProperty("HSNSACCode", out var hp) ||
                    extractedJson.Value.TryGetProperty("hsnSacCode", out hp) ||
                    extractedJson.Value.TryGetProperty("hsnCode", out hp) ||
                    extractedJson.Value.TryGetProperty("sacCode", out hp))
                {
                    hsnSac = hp.GetString();
                }
            }
            var hsnPresent = !string.IsNullOrWhiteSpace(hsnSac);
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = hsnPresent ? "Pass" : "Fail",
                Details = "HSN/SAC Code",
                Evidence = hsnPresent ? hsnSac! : "HSN/SAC code not detected"
            });

            // 7. Vendor Code
            string? vendorCode = null;
            if (extractedJson.HasValue)
            {
                if (extractedJson.Value.TryGetProperty("VendorCode", out var vc) ||
                    extractedJson.Value.TryGetProperty("vendorCode", out vc))
                {
                    vendorCode = vc.GetString();
                }
            }
            var vendorCodePresent = !string.IsNullOrWhiteSpace(vendorCode);
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = vendorCodePresent ? "Pass" : "Fail",
                Details = "Vendor Code",
                Evidence = vendorCodePresent ? vendorCode! : "Vendor code not detected"
            });

            // 8. PO Number (cross-check against PO)
            string? extractedPoNumber = null;
            if (extractedJson.HasValue)
            {
                if (extractedJson.Value.TryGetProperty("PONumber", out var pn) ||
                    extractedJson.Value.TryGetProperty("poNumber", out pn))
                {
                    extractedPoNumber = pn.GetString();
                }
            }
            bool poMatch;
            string poEvidence;
            if (po == null)
            {
                poMatch = false;
                poEvidence = "PO master data not found";
            }
            else if (string.IsNullOrWhiteSpace(extractedPoNumber))
            {
                poMatch = false;
                poEvidence = "PO number not extracted from invoice";
            }
            else
            {
                poMatch = extractedPoNumber.Equals(po.PONumber, StringComparison.OrdinalIgnoreCase);
                poEvidence = poMatch
                    ? $"{extractedPoNumber} matches selected PO"
                    : $"{extractedPoNumber} does NOT match selected PO {po.PONumber}";
            }
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = poMatch ? "Pass" : "Fail",
                Details = "PO Number",
                Evidence = poEvidence
            });

            // 9. Amount vs PO Balance
            bool amountOk;
            string balanceEvidence;
            if (po == null || !invAmount.HasValue)
            {
                amountOk = po == null ? false : true;
                balanceEvidence = po == null ? "PO balance not available" : "Invoice amount not detected";
            }
            else
            {
                var balance = po.RemainingBalance ?? po.TotalAmount ?? 0;
                amountOk = invAmount.Value <= balance;
                balanceEvidence = amountOk
                    ? $"₹{invAmount.Value:N0} within PO balance (₹{balance:N0})"
                    : $"₹{invAmount.Value:N0} exceeds PO balance (₹{balance:N0})";
            }
            groups.Add(new ValidationCheckGroup
            {
                GroupName = invoiceLabel,
                Status = amountOk ? "Pass" : "Fail",
                Details = "Amount vs PO Balance",
                Evidence = balanceEvidence
            });
        }

        if (groups.Count == 0)
        {
            return BuildCheckGroups(allResults.FirstOrDefault());
        }

        // Enquiry Dump validation section — read from ValidationResults.RuleResultsJson
        var enquiry = package.EnquiryDocument;
        if (enquiry != null && !enquiry.IsDeleted)
        {
            // Find the ValidationResult for this enquiry document
            var enquiryVr = allResults.FirstOrDefault(vr =>
                vr.DocumentId == enquiry.Id ||
                vr.DocumentType == Domain.Enums.DocumentType.EnquiryDocument);

            if (enquiryVr?.RuleResultsJson != null)
            {
                try
                {
                    var rules = JsonSerializer.Deserialize<List<EnquiryRuleResult>>(
                        enquiryVr.RuleResultsJson,
                        new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                    if (rules != null)
                    {
                        // Display in the required order
                        var orderedCodes = new[]
                        {
                            "EQ_STATE", "EQ_DATE", "EQ_DEALER_CODE", "EQ_DEALER_NAME",
                            "EQ_DISTRICT", "EQ_PINCODE", "EQ_CUSTOMER_NAME",
                            "EQ_CUSTOMER_PHONE", "EQ_TEST_RIDE"
                        };

                        foreach (var code in orderedCodes)
                        {
                            var rule = rules.FirstOrDefault(r =>
                                r.RuleCode?.Equals(code, StringComparison.OrdinalIgnoreCase) == true);
                            if (rule == null) continue;

                            groups.Add(new ValidationCheckGroup
                            {
                                GroupName = "Enquiry Dump",
                                Status = rule.Passed ? "Pass" : "Fail",
                                Details = rule.Label ?? code,
                                Evidence = rule.ExtractedValue
                                    ?? (rule.Passed ? "Present" : rule.Message ?? "Not detected")
                            });
                        }
                    }
                }
                catch { /* malformed JSON — fall through to basic check */ }
            }

            // Fallback if no ValidationResult found
            if (!groups.Any(g => g.GroupName == "Enquiry Dump"))
            {
                groups.Add(new ValidationCheckGroup
                {
                    GroupName = "Enquiry Dump",
                    Status = "Fail",
                    Details = "Validation",
                    Evidence = "No validation results found"
                });
            }
        }

        // Photos validation section — one row per rule per photo, grouped by team
        var teams = package.Teams.Where(t => !t.IsDeleted).ToList();
        if (teams.Any())
        {
            for (int ti = 0; ti < teams.Count; ti++)
            {
                var team = teams[ti];
                var teamLabel = team.CampaignName ?? $"Team {ti + 1}";
                var photos = team.Photos.Where(p => !p.IsDeleted).ToList();

                if (photos.Count == 0)
                {
                    groups.Add(new ValidationCheckGroup
                    {
                        GroupName = "Team Photos",
                        Status = "Fail",
                        Details = $"{teamLabel} — Photo Count",
                        Evidence = "No photos uploaded"
                    });
                    continue;
                }

                // Collect all rule results across all photos for this team
                // Key: ruleCode → aggregate (all passed, pass values, fail messages)
                var ruleAgg = new Dictionary<string, (string Label, bool AllPassed, List<string> PassValues, List<string> FailMessages)>(StringComparer.OrdinalIgnoreCase);

                foreach (var photo in photos)
                {
                    var photoVr = photo.ValidationResult
                        ?? allResults.FirstOrDefault(vr => vr.DocumentId == photo.Id);
                    if (photoVr?.RuleResultsJson == null) continue;

                    try
                    {
                        var rules = JsonSerializer.Deserialize<List<EnquiryRuleResult>>(
                            photoVr.RuleResultsJson,
                            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                        if (rules == null) continue;

                        foreach (var rule in rules)
                        {
                            if (string.IsNullOrWhiteSpace(rule.RuleCode)) continue;
                            var key = rule.RuleCode!;
                            if (!ruleAgg.TryGetValue(key, out var agg))
                                agg = (rule.Label ?? key, true, new List<string>(), new List<string>());

                            bool nowPassed = agg.AllPassed && rule.Passed;

                            if (rule.Passed)
                            {
                                if (!string.IsNullOrWhiteSpace(rule.ExtractedValue))
                                    agg.PassValues.Add(rule.ExtractedValue!);
                            }
                            else
                            {
                                var failMsg = rule.Message ?? rule.ExtractedValue ?? "Not detected";
                                if (!string.IsNullOrWhiteSpace(failMsg))
                                    agg.FailMessages.Add(failMsg);
                            }

                            ruleAgg[key] = (agg.Label, nowPassed, agg.PassValues, agg.FailMessages);
                        }
                    }
                    catch { /* malformed JSON */ }
                }

                if (ruleAgg.Count > 0)
                {
                    // Photo count row first
                    bool enoughPhotos = photos.Count >= 3;
                    groups.Add(new ValidationCheckGroup
                    {
                        GroupName = "Team Photos",
                        Status = enoughPhotos ? "Pass" : "Fail",
                        Details = $"{teamLabel} — Photo Count",
                        Evidence = enoughPhotos
                            ? $"{photos.Count} photos uploaded"
                            : $"Only {photos.Count} photo(s) — minimum 3 required"
                    });

                    // One row per rule (aggregated across all photos in this team)
                    foreach (var (code, (label, allPassed, passValues, failMessages)) in ruleAgg)
                    {
                        string evidence;
                        if (allPassed)
                            evidence = passValues.Count > 0 ? string.Join(", ", passValues.Distinct()) : "Present";
                        else
                            evidence = failMessages.Count > 0 ? string.Join("; ", failMessages.Distinct()) : "Not detected";

                        groups.Add(new ValidationCheckGroup
                        {
                            GroupName = "Team Photos",
                            Status = allPassed ? "Pass" : "Fail",
                            Details = $"{teamLabel} — {label}",
                            Evidence = evidence
                        });
                    }
                }
                else
                {
                    // Fallback: no ValidationResult found — just show photo count
                    bool enoughPhotos = photos.Count >= 3;
                    groups.Add(new ValidationCheckGroup
                    {
                        GroupName = "Team Photos",
                        Status = enoughPhotos ? "Pass" : "Fail",
                        Details = $"{teamLabel} — Photo Count",
                        Evidence = enoughPhotos
                            ? $"{photos.Count} photos uploaded"
                            : $"Only {photos.Count} photo(s) — minimum 3 required"
                    });
                }
            }
        }

        return groups;
    }

    /// <summary>
    /// Parses ValidationDetailsJson into a dictionary of check name → evidence description
    /// for ALL checks (both pass and fail). Unlike ParseValidationDetailsJson which is used
    /// for issue descriptions, this extracts the "details" field for every check.
    /// </summary>
    private static Dictionary<string, string> ParseValidationEvidenceJson(string? json)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(json)) return result;

        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            JsonElement arrayToParse = default;
            var hasArray = false;

            if (root.ValueKind == JsonValueKind.Object)
            {
                if (root.TryGetProperty("checks", out var checksArray) && checksArray.ValueKind == JsonValueKind.Array)
                {
                    arrayToParse = checksArray;
                    hasArray = true;
                }
                else
                {
                    // Flat object format
                    foreach (var prop in root.EnumerateObject())
                    {
                        string? description = null;
                        if (prop.Value.ValueKind == JsonValueKind.String)
                            description = prop.Value.GetString();
                        else if (prop.Value.ValueKind == JsonValueKind.Object &&
                                 prop.Value.TryGetProperty("description", out var descProp))
                            description = descProp.GetString();

                        if (!string.IsNullOrWhiteSpace(description))
                            result[prop.Name] = description!;
                    }
                }
            }
            else if (root.ValueKind == JsonValueKind.Array)
            {
                arrayToParse = root;
                hasArray = true;
            }

            if (hasArray)
            {
                foreach (var element in arrayToParse.EnumerateArray())
                {
                    if (element.ValueKind != JsonValueKind.Object) continue;

                    var name = element.TryGetProperty("checkName", out var nameProp)
                        ? nameProp.GetString()
                        : element.TryGetProperty("name", out var n) ? n.GetString() : null;

                    var desc = element.TryGetProperty("details", out var detProp)
                        ? detProp.GetString()
                        : element.TryGetProperty("description", out var d) ? d.GetString() : null;

                    if (!string.IsNullOrWhiteSpace(name) && !string.IsNullOrWhiteSpace(desc))
                        result[name!] = desc!;
                }
            }
        }
        catch (JsonException)
        {
            // Malformed JSON — return empty
        }

        return result;
    }
}

/// <summary>
/// Minimal DTO for deserializing enquiry dump rule results from RuleResultsJson.
/// </summary>
file sealed class EnquiryRuleResult
{
    public string? RuleCode { get; set; }
    public string? Label { get; set; }
    public bool Passed { get; set; }
    public string? ExtractedValue { get; set; }
    public string? Message { get; set; }
}
