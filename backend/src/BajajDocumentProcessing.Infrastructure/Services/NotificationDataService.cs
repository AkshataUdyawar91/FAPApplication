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
            .Include(p => p.Teams.Where(t => !t.IsDeleted))
                .ThenInclude(t => t.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.Teams.Where(t => !t.IsDeleted))
                .ThenInclude(t => t.Photos.Where(ph => !ph.IsDeleted))
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

        var cardData = new SubmissionCardData
        {
            SubmissionId = package.Id,
            SubmissionNumber = "FAP-" + package.Id.ToString()[..8].ToUpper(),
            NotificationTimestamp = DateTime.UtcNow
        };

        // === Key Facts ===
        MapKeyFacts(cardData, package);

        // === AI Recommendation ===
        MapRecommendation(cardData, package);

        // === Validation Checks & Issues ===
        MapValidationChecks(cardData, package);

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

        // Invoice number: first CampaignInvoice across all Teams
        var allInvoices = package.Teams
            .SelectMany(t => t.Invoices)
            .ToList();

        cardData.InvoiceNumber = allInvoices
            .Select(i => i.InvoiceNumber)
            .FirstOrDefault(n => !string.IsNullOrWhiteSpace(n)) ?? "N/A";

        // Invoice amount: sum of TotalAmount across all CampaignInvoices
        var totalAmount = allInvoices
            .Where(i => i.TotalAmount.HasValue)
            .Sum(i => i.TotalAmount!.Value);

        cardData.InvoiceAmountRaw = totalAmount;
        cardData.InvoiceAmount = FormatIndianCurrency(totalAmount);

        // State: first Team's State field
        cardData.State = package.Teams
            .Select(t => t.State)
            .FirstOrDefault(s => !string.IsNullOrWhiteSpace(s)) ?? "N/A";

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
            cardData.Recommendation = "N/A";
            cardData.RecommendationEmoji = "❓";
            cardData.CardStyle = "default";
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

        // Parse ValidationDetailsJson for detailed descriptions
        var detailDescriptions = ParseValidationDetailsJson(vr.ValidationDetailsJson);

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
            catch (JsonException)
            {
                // Malformed JSON — skip silently
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

            int? total = root.TryGetProperty("totalRecords", out var t) && t.ValueKind == JsonValueKind.Number
                ? t.GetInt32()
                : root.TryGetProperty("total_records", out var t2) && t2.ValueKind == JsonValueKind.Number
                    ? t2.GetInt32()
                    : null;

            int? complete = root.TryGetProperty("completeRecords", out var c) && c.ValueKind == JsonValueKind.Number
                ? c.GetInt32()
                : root.TryGetProperty("complete_records", out var c2) && c2.ValueKind == JsonValueKind.Number
                    ? c2.GetInt32()
                    : null;

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
            .Include(p => p.CostSummary)
            .Include(p => p.ActivitySummary)
            .Include(p => p.EnquiryDocument)
            .Include(p => p.CampaignInvoices)
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
        foreach (var inv in package.CampaignInvoices)
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
        // (e.g., Invoice validation saved against a Teams invoice ID, not CampaignInvoice ID)
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
        if (package.CampaignInvoices.Any() && !foundDocTypes.Contains(Domain.Enums.DocumentType.Invoice))
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
            IsAlreadyProcessed = package.State != PackageState.PendingASM,
            PortalUrl = $"{portalBaseUrl}/fap/{package.Id}/review"
        };

        // Populate ProcessedBy/ProcessedAt from latest RequestApprovalHistory
        if (latestHistory is not null)
        {
            breakdown.ProcessedAt = latestHistory.ActionDate;
            breakdown.ProcessedBy = latestHistory.Approver?.FullName;
        }

        // Build validation check groups from ALL documents' validation results
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

        var detailDescriptions = ParseValidationDetailsJson(vr.ValidationDetailsJson);

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
    /// Builds validation check groups from ALL documents in the package.
    /// Shows per-document validation status so the ASM can see checks for PO, Invoice, Cost Summary, etc.
    /// </summary>
    private static List<ValidationCheckGroup> BuildCheckGroupsFromAllDocuments(
        Domain.Entities.DocumentPackage package,
        List<Domain.Entities.ValidationResult> allResults)
    {
        var groups = new List<ValidationCheckGroup>();

        // Build document entries with their expected DocumentType for validation lookup
        var docEntries = new List<(string DocName, Guid? DocId, Domain.Enums.DocumentType DocType)>
        {
            ("PO", package.PO?.Id, Domain.Enums.DocumentType.PO),
            ("Cost Summary", package.CostSummary?.Id, Domain.Enums.DocumentType.CostSummary),
            ("Activity Summary", package.ActivitySummary?.Id, Domain.Enums.DocumentType.ActivitySummary),
            ("Enquiry Document", package.EnquiryDocument?.Id, Domain.Enums.DocumentType.EnquiryDocument)
        };

        // For invoices: the validation system saves ONE ValidationResult for DocumentType.Invoice
        // using the first team invoice's ID. Show it as a single "Invoice" entry rather than per-CampaignInvoice.
        var firstCampaignInvoice = package.CampaignInvoices.FirstOrDefault();
        if (firstCampaignInvoice != null)
        {
            var invoiceCount = package.CampaignInvoices.Count;
            var invoiceLabel = invoiceCount > 1 ? $"Invoices ({invoiceCount})" : "Invoice";
            docEntries.Add((invoiceLabel, firstCampaignInvoice.Id, Domain.Enums.DocumentType.Invoice));
        }

        foreach (var (docName, docId, docType) in docEntries)
        {
            if (docId == null) continue;

            // Look up by document ID first, then fall back to DocumentType match
            var vr = allResults.FirstOrDefault(r => r.DocumentId == docId.Value)
                  ?? allResults.FirstOrDefault(r => r.DocumentType == docType);

            if (vr == null)
            {
                // Document exists but no validation was run on it
                groups.Add(new ValidationCheckGroup
                {
                    GroupName = $"📄 {docName}",
                    Status = "Fail",
                    Details = "No validation data available"
                });
                continue;
            }

            // Parse detail descriptions for failed checks
            var detailDescriptions = ParseValidationDetailsJson(vr.ValidationDetailsJson);

            var checks = new (string CheckName, bool Passed, string DetailKey)[]
            {
                ("SAP Verification", vr.SapVerificationPassed, "SAP Verification"),
                ("Amount Consistency", vr.AmountConsistencyPassed, "Amount Consistency"),
                ("Line Item Matching", vr.LineItemMatchingPassed, "Line Item Matching"),
                ("Completeness", vr.CompletenessCheckPassed, "Completeness Check"),
                ("Date Validation", vr.DateValidationPassed, "Date Validation"),
                ("Vendor Matching", vr.VendorMatchingPassed, "Vendor Matching")
            };

            var failCount = checks.Count(c => !c.Passed);

            // Header row — use FailureReason from ValidationResult if available
            var headerDetails = !string.IsNullOrWhiteSpace(vr.FailureReason)
                ? vr.FailureReason
                : failCount > 0 ? $"{failCount} check(s) failed" : null;

            groups.Add(new ValidationCheckGroup
            {
                GroupName = $"📄 {docName}",
                Status = vr.AllValidationsPassed ? "Pass" : "Fail",
                Details = headerDetails
            });

            // Individual check rows with failure reasons
            foreach (var (checkName, passed, detailKey) in checks)
            {
                var checkDetail = !passed
                    ? detailDescriptions.GetValueOrDefault(detailKey) ?? $"{checkName} failed"
                    : null;

                groups.Add(new ValidationCheckGroup
                {
                    GroupName = $"  {checkName}",
                    Status = passed ? "Pass" : "Fail",
                    Details = checkDetail
                });
            }
        }

        // If no documents found at all, fall back to the old behavior
        if (groups.Count == 0)
        {
            return BuildCheckGroups(allResults.FirstOrDefault());
        }

        return groups;
    }
}
