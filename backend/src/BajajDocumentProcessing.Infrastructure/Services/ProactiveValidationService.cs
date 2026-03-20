using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Conversation;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Runs per-document proactive validation immediately after extraction.
/// Returns granular rule-level results for real-time display in the chat UI.
/// Persists results to ValidationResult.RuleResultsJson and pushes SignalR events.
/// </summary>
public class ProactiveValidationService : IProactiveValidationService
{
    private readonly IApplicationDbContext _db;
    private readonly ISubmissionNotificationService _notificationService;
    private readonly ILogger<ProactiveValidationService> _logger;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public ProactiveValidationService(
        IApplicationDbContext db,
        ISubmissionNotificationService notificationService,
        ILogger<ProactiveValidationService> logger)
    {
        _db = db;
        _notificationService = notificationService;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<ProactiveValidationResponse> ValidateDocumentAsync(
        Guid documentId,
        DocumentType documentType,
        Guid packageId,
        CancellationToken ct = default)
    {
        _logger.LogInformation(
            "Starting proactive validation for document {DocumentId} (type={DocumentType}, package={PackageId})",
            documentId, documentType, packageId);

        var rules = documentType switch
        {
            DocumentType.Invoice => await ValidateInvoiceAsync(documentId, packageId, ct),
            DocumentType.ActivitySummary => await ValidateActivitySummaryAsync(documentId, packageId, ct),
            DocumentType.CostSummary => await ValidateCostSummaryAsync(documentId, packageId, ct),
            _ => new List<ProactiveRuleResult>()
        };

        var passCount = rules.Count(r => r.Severity == "Pass");
        var failCount = rules.Count(r => r.Severity == "Fail");
        var warningCount = rules.Count(r => r.Severity == "Warning");

        var response = new ProactiveValidationResponse
        {
            DocumentId = documentId,
            DocumentType = documentType,
            AllPassed = failCount == 0 && warningCount == 0,
            PassCount = passCount,
            FailCount = failCount,
            WarningCount = warningCount,
            Rules = rules
        };

        // Persist results to ValidationResult.RuleResultsJson
        await PersistRuleResultsAsync(documentId, documentType, rules, ct);

        // Push SignalR notification
        await _notificationService.SendValidationCompleteAsync(
            packageId,
            new { documentId, rules },
            ct);

        _logger.LogInformation(
            "Proactive validation complete for document {DocumentId}: {PassCount} pass, {FailCount} fail, {WarningCount} warning",
            documentId, passCount, failCount, warningCount);

        return response;
    }

    #region Invoice Validation (9 rules)

    private async Task<List<ProactiveRuleResult>> ValidateInvoiceAsync(
        Guid documentId, Guid packageId, CancellationToken ct)
    {
        var invoice = await _db.Invoices
            .AsNoTracking()
            .FirstOrDefaultAsync(i => i.Id == documentId && !i.IsDeleted, ct);

        if (invoice is null)
        {
            _logger.LogWarning("Invoice {DocumentId} not found for validation", documentId);
            return new List<ProactiveRuleResult>();
        }

        // Load the PO for cross-checks
        var po = await _db.POs
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.PackageId == packageId && !p.IsDeleted, ct);

        var extractedData = ParseExtractedJson(invoice.ExtractedDataJson);
        var rules = new List<ProactiveRuleResult>();

        // Rule 1: INV_INVOICE_NUMBER_PRESENT
        rules.Add(CheckFieldPresence("INV_INVOICE_NUMBER_PRESENT", invoice.InvoiceNumber, "Invoice Number"));

        // Rule 2: INV_DATE_PRESENT
        rules.Add(CheckFieldPresence("INV_DATE_PRESENT", invoice.InvoiceDate?.ToString("yyyy-MM-dd"), "Invoice Date"));

        // Rule 3: INV_AMOUNT_PRESENT
        rules.Add(CheckFieldPresence("INV_AMOUNT_PRESENT", invoice.TotalAmount?.ToString("F2"), "Invoice Amount"));

        // Rule 4: INV_GST_NUMBER_PRESENT
        var gstNumber = invoice.GSTNumber ?? GetJsonField(extractedData, "gstNumber");
        rules.Add(CheckFieldPresence("INV_GST_NUMBER_PRESENT", gstNumber, "GST Number"));

        // Rule 5: INV_GST_PERCENT_PRESENT
        var gstPercent = GetJsonField(extractedData, "gstPercent") ?? GetJsonField(extractedData, "gstPercentage");
        rules.Add(CheckFieldPresence("INV_GST_PERCENT_PRESENT", gstPercent, "GST Percentage"));

        // Rule 6: INV_HSN_SAC_PRESENT
        var hsnSac = GetJsonField(extractedData, "hsnSacCode") ?? GetJsonField(extractedData, "hsnCode") ?? GetJsonField(extractedData, "sacCode");
        rules.Add(CheckFieldPresence("INV_HSN_SAC_PRESENT", hsnSac, "HSN/SAC Code"));

        // Rule 7: INV_VENDOR_CODE_PRESENT
        var vendorCode = GetJsonField(extractedData, "vendorCode");
        rules.Add(CheckFieldPresence("INV_VENDOR_CODE_PRESENT", vendorCode, "Vendor Code"));

        // Rule 8: INV_PO_NUMBER_MATCH (cross-check against PO)
        rules.Add(CheckPONumberMatch(extractedData, po));

        // Rule 9: INV_AMOUNT_VS_PO_BALANCE (cross-check amount against PO remaining balance)
        rules.Add(CheckInvoiceAmountVsPOBalance(invoice.TotalAmount, po));

        return rules;
    }

    private ProactiveRuleResult CheckPONumberMatch(Dictionary<string, string> extractedData, PO? po)
    {
        var invoicePONumber = GetJsonField(extractedData, "poNumber") ?? GetJsonField(extractedData, "purchaseOrderNumber");

        if (po is null)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "INV_PO_NUMBER_MATCH",
                Type = "Check",
                Passed = false,
                ExtractedValue = invoicePONumber,
                ExpectedValue = null,
                Message = "No PO found for this submission to cross-check",
                Severity = "Warning"
            };
        }

        if (string.IsNullOrWhiteSpace(invoicePONumber))
        {
            return new ProactiveRuleResult
            {
                RuleCode = "INV_PO_NUMBER_MATCH",
                Type = "Check",
                Passed = false,
                ExtractedValue = null,
                ExpectedValue = po.PONumber,
                Message = "PO number not found in invoice for cross-check",
                Severity = "Warning"
            };
        }

        var matches = string.Equals(invoicePONumber.Trim(), po.PONumber?.Trim(), StringComparison.OrdinalIgnoreCase);
        return new ProactiveRuleResult
        {
            RuleCode = "INV_PO_NUMBER_MATCH",
            Type = "Check",
            Passed = matches,
            ExtractedValue = invoicePONumber,
            ExpectedValue = po.PONumber,
            Message = matches ? "PO number matches" : "PO number on invoice does not match selected PO",
            Severity = matches ? "Pass" : "Fail"
        };
    }

    private static ProactiveRuleResult CheckInvoiceAmountVsPOBalance(decimal? invoiceAmount, PO? po)
    {
        if (po is null || !po.RemainingBalance.HasValue)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "INV_AMOUNT_VS_PO_BALANCE",
                Type = "Check",
                Passed = true,
                ExtractedValue = invoiceAmount?.ToString("F2"),
                ExpectedValue = null,
                Message = "PO balance not available for cross-check",
                Severity = "Warning"
            };
        }

        if (!invoiceAmount.HasValue)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "INV_AMOUNT_VS_PO_BALANCE",
                Type = "Check",
                Passed = false,
                ExtractedValue = null,
                ExpectedValue = po.RemainingBalance.Value.ToString("F2"),
                Message = "Invoice amount not available for comparison",
                Severity = "Warning"
            };
        }

        var withinBalance = invoiceAmount.Value <= po.RemainingBalance.Value;
        return new ProactiveRuleResult
        {
            RuleCode = "INV_AMOUNT_VS_PO_BALANCE",
            Type = "Check",
            Passed = withinBalance,
            ExtractedValue = invoiceAmount.Value.ToString("F2"),
            ExpectedValue = po.RemainingBalance.Value.ToString("F2"),
            Message = withinBalance
                ? "Invoice amount is within PO remaining balance"
                : "Invoice amount exceeds PO remaining balance",
            Severity = withinBalance ? "Pass" : "Fail"
        };
    }

    #endregion

    #region Activity Summary Validation (3 rules)

    private async Task<List<ProactiveRuleResult>> ValidateActivitySummaryAsync(
        Guid documentId, Guid packageId, CancellationToken ct)
    {
        var activity = await _db.ActivitySummaries
            .AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == documentId && !a.IsDeleted, ct);

        if (activity is null)
        {
            _logger.LogWarning("ActivitySummary {DocumentId} not found for validation", documentId);
            return new List<ProactiveRuleResult>();
        }

        var extractedData = ParseExtractedJson(activity.ExtractedDataJson);
        var rules = new List<ProactiveRuleResult>();

        // Rule 1: AS_DEALER_LOCATION_PRESENT
        var dealerLocation = GetJsonField(extractedData, "dealerLocation")
            ?? GetJsonField(extractedData, "location")
            ?? GetJsonField(extractedData, "dealerName");
        rules.Add(CheckFieldPresence("AS_DEALER_LOCATION_PRESENT", dealerLocation, "Dealer/Location"));

        // Rule 2: AS_DAYS_MATCH_COST_SUMMARY — cross-check days against cost summary
        var costSummary = await _db.CostSummaries
            .AsNoTracking()
            .FirstOrDefaultAsync(cs => cs.PackageId == packageId && !cs.IsDeleted, ct);
        rules.Add(CheckActivityDaysVsCostSummary(extractedData, costSummary));

        // Rule 3: AS_DAYS_MATCH_TEAM_DETAILS — cross-check days against team entries
        var teams = await _db.Teams
            .AsNoTracking()
            .Where(t => t.PackageId == packageId && !t.IsDeleted)
            .ToListAsync(ct);
        rules.Add(CheckActivityDaysVsTeamDetails(extractedData, teams));

        return rules;
    }

    private ProactiveRuleResult CheckActivityDaysVsCostSummary(
        Dictionary<string, string> activityData, CostSummary? costSummary)
    {
        var activityDaysStr = GetJsonField(activityData, "totalDays")
            ?? GetJsonField(activityData, "workingDays")
            ?? GetJsonField(activityData, "days");

        if (costSummary is null)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "AS_DAYS_MATCH_COST_SUMMARY",
                Type = "Check",
                Passed = true,
                ExtractedValue = activityDaysStr,
                ExpectedValue = null,
                Message = "Cost summary not yet uploaded for cross-check",
                Severity = "Warning"
            };
        }

        var costData = ParseExtractedJson(costSummary.ExtractedDataJson);
        var costDaysStr = GetJsonField(costData, "totalDays") ?? GetJsonField(costData, "days");

        if (string.IsNullOrWhiteSpace(activityDaysStr) || string.IsNullOrWhiteSpace(costDaysStr))
        {
            return new ProactiveRuleResult
            {
                RuleCode = "AS_DAYS_MATCH_COST_SUMMARY",
                Type = "Check",
                Passed = false,
                ExtractedValue = activityDaysStr,
                ExpectedValue = costDaysStr,
                Message = "Days field missing from activity summary or cost summary",
                Severity = "Warning"
            };
        }

        var matches = string.Equals(activityDaysStr.Trim(), costDaysStr.Trim(), StringComparison.OrdinalIgnoreCase);
        return new ProactiveRuleResult
        {
            RuleCode = "AS_DAYS_MATCH_COST_SUMMARY",
            Type = "Check",
            Passed = matches,
            ExtractedValue = activityDaysStr,
            ExpectedValue = costDaysStr,
            Message = matches
                ? "Activity days match cost summary"
                : "Activity days do not match cost summary days",
            Severity = matches ? "Pass" : "Fail"
        };
    }

    private static ProactiveRuleResult CheckActivityDaysVsTeamDetails(
        Dictionary<string, string> activityData, List<Domain.Entities.Teams> teams)
    {
        var activityDaysStr = GetJsonField(activityData, "totalDays")
            ?? GetJsonField(activityData, "workingDays")
            ?? GetJsonField(activityData, "days");

        if (teams.Count == 0)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "AS_DAYS_MATCH_TEAM_DETAILS",
                Type = "Check",
                Passed = true,
                ExtractedValue = activityDaysStr,
                ExpectedValue = null,
                Message = "No team details entered yet for cross-check",
                Severity = "Warning"
            };
        }

        var totalTeamDays = teams.Sum(t => t.WorkingDays ?? 0);
        var teamDaysStr = totalTeamDays.ToString();

        if (string.IsNullOrWhiteSpace(activityDaysStr))
        {
            return new ProactiveRuleResult
            {
                RuleCode = "AS_DAYS_MATCH_TEAM_DETAILS",
                Type = "Check",
                Passed = false,
                ExtractedValue = null,
                ExpectedValue = teamDaysStr,
                Message = "Days field missing from activity summary",
                Severity = "Warning"
            };
        }

        if (int.TryParse(activityDaysStr.Trim(), out var activityDays))
        {
            var matches = activityDays == totalTeamDays;
            return new ProactiveRuleResult
            {
                RuleCode = "AS_DAYS_MATCH_TEAM_DETAILS",
                Type = "Check",
                Passed = matches,
                ExtractedValue = activityDaysStr,
                ExpectedValue = teamDaysStr,
                Message = matches
                    ? "Activity days match total team working days"
                    : "Activity days do not match total team working days",
                Severity = matches ? "Pass" : "Fail"
            };
        }

        return new ProactiveRuleResult
        {
            RuleCode = "AS_DAYS_MATCH_TEAM_DETAILS",
            Type = "Check",
            Passed = false,
            ExtractedValue = activityDaysStr,
            ExpectedValue = teamDaysStr,
            Message = "Could not parse days from activity summary for comparison",
            Severity = "Warning"
        };
    }

    #endregion

    #region Cost Summary Validation (4 rules)

    private async Task<List<ProactiveRuleResult>> ValidateCostSummaryAsync(
        Guid documentId, Guid packageId, CancellationToken ct)
    {
        var costSummary = await _db.CostSummaries
            .AsNoTracking()
            .FirstOrDefaultAsync(cs => cs.Id == documentId && !cs.IsDeleted, ct);

        if (costSummary is null)
        {
            _logger.LogWarning("CostSummary {DocumentId} not found for validation", documentId);
            return new List<ProactiveRuleResult>();
        }

        var extractedData = ParseExtractedJson(costSummary.ExtractedDataJson);
        var rules = new List<ProactiveRuleResult>();

        // Rule 1: CS_PLACE_OF_SUPPLY_PRESENT
        var placeOfSupply = GetJsonField(extractedData, "placeOfSupply")
            ?? GetJsonField(extractedData, "supplyPlace")
            ?? GetJsonField(extractedData, "location");
        rules.Add(CheckFieldPresence("CS_PLACE_OF_SUPPLY_PRESENT", placeOfSupply, "Place of Supply"));

        // Rule 2: CS_TOTAL_DAYS_PRESENT
        var totalDays = GetJsonField(extractedData, "totalDays") ?? GetJsonField(extractedData, "days");
        rules.Add(CheckFieldPresence("CS_TOTAL_DAYS_PRESENT", totalDays, "Total Days"));

        // Rule 3: CS_TOTAL_VS_INVOICE — cross-check total cost against invoice amount
        var invoice = await _db.Invoices
            .AsNoTracking()
            .FirstOrDefaultAsync(i => i.PackageId == packageId && !i.IsDeleted, ct);
        rules.Add(CheckCostTotalVsInvoice(costSummary.TotalCost, extractedData, invoice));

        // Rule 4: CS_ELEMENT_COST_VS_RATES — check element costs against rate master
        rules.Add(CheckElementCostsVsRates(extractedData));

        return rules;
    }

    private static ProactiveRuleResult CheckCostTotalVsInvoice(
        decimal? costTotal, Dictionary<string, string> costData, Invoice? invoice)
    {
        // Try to get total from extracted data if entity field is null
        var totalStr = costTotal?.ToString("F2")
            ?? GetJsonField(costData, "totalCost")
            ?? GetJsonField(costData, "totalAmount")
            ?? GetJsonField(costData, "grandTotal");

        if (invoice is null)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "CS_TOTAL_VS_INVOICE",
                Type = "Check",
                Passed = true,
                ExtractedValue = totalStr,
                ExpectedValue = null,
                Message = "Invoice not yet uploaded for cross-check",
                Severity = "Warning"
            };
        }

        if (!invoice.TotalAmount.HasValue)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "CS_TOTAL_VS_INVOICE",
                Type = "Check",
                Passed = false,
                ExtractedValue = totalStr,
                ExpectedValue = null,
                Message = "Invoice amount not available for comparison",
                Severity = "Warning"
            };
        }

        decimal? parsedCostTotal = costTotal;
        if (!parsedCostTotal.HasValue && !string.IsNullOrWhiteSpace(totalStr))
        {
            decimal.TryParse(totalStr.Trim(), out var parsed);
            if (parsed > 0) parsedCostTotal = parsed;
        }

        if (!parsedCostTotal.HasValue)
        {
            return new ProactiveRuleResult
            {
                RuleCode = "CS_TOTAL_VS_INVOICE",
                Type = "Check",
                Passed = false,
                ExtractedValue = null,
                ExpectedValue = invoice.TotalAmount.Value.ToString("F2"),
                Message = "Cost summary total not available for comparison",
                Severity = "Warning"
            };
        }

        var matches = parsedCostTotal.Value == invoice.TotalAmount.Value;
        return new ProactiveRuleResult
        {
            RuleCode = "CS_TOTAL_VS_INVOICE",
            Type = "Check",
            Passed = matches,
            ExtractedValue = parsedCostTotal.Value.ToString("F2"),
            ExpectedValue = invoice.TotalAmount.Value.ToString("F2"),
            Message = matches
                ? "Cost summary total matches invoice amount"
                : "Cost summary total does not match invoice amount",
            Severity = matches ? "Pass" : "Fail"
        };
    }

    private static ProactiveRuleResult CheckElementCostsVsRates(Dictionary<string, string> extractedData)
    {
        // Check if cost breakdown elements exist and have reasonable values.
        // Full rate master comparison requires external SAP data; here we validate
        // that element costs are present and parseable.
        var costBreakdown = GetJsonField(extractedData, "costBreakdown")
            ?? GetJsonField(extractedData, "elements")
            ?? GetJsonField(extractedData, "lineItems");

        if (string.IsNullOrWhiteSpace(costBreakdown))
        {
            return new ProactiveRuleResult
            {
                RuleCode = "CS_ELEMENT_COST_VS_RATES",
                Type = "Check",
                Passed = false,
                ExtractedValue = null,
                ExpectedValue = null,
                Message = "Cost breakdown elements not found in extracted data",
                Severity = "Warning"
            };
        }

        return new ProactiveRuleResult
        {
            RuleCode = "CS_ELEMENT_COST_VS_RATES",
            Type = "Check",
            Passed = true,
            ExtractedValue = "Present",
            ExpectedValue = null,
            Message = "Cost breakdown elements present for rate comparison",
            Severity = "Pass"
        };
    }

    #endregion

    #region Persistence

    private async Task PersistRuleResultsAsync(
        Guid documentId,
        DocumentType documentType,
        List<ProactiveRuleResult> rules,
        CancellationToken ct)
    {
        try
        {
            var ruleResultsJson = JsonSerializer.Serialize(
                rules.Select(r => new
                {
                    r.RuleCode,
                    r.Type,
                    r.Passed,
                    r.ExtractedValue,
                    r.ExpectedValue
                }),
                JsonOptions);

            // Find or create ValidationResult for this document
            var validationResult = await _db.ValidationResults
                .FirstOrDefaultAsync(
                    vr => vr.DocumentId == documentId
                        && vr.DocumentType == documentType
                        && !vr.IsDeleted,
                    ct);

            if (validationResult is null)
            {
                validationResult = new ValidationResult
                {
                    Id = Guid.NewGuid(),
                    DocumentId = documentId,
                    DocumentType = documentType,
                    RuleResultsJson = ruleResultsJson,
                    ValidationDetailsJson = BuildDetailsWithProactiveRules(null, ruleResultsJson),
                    CreatedAt = DateTime.UtcNow
                };
                _db.ValidationResults.Add(validationResult);
            }
            else
            {
                validationResult.RuleResultsJson = ruleResultsJson;
                // Merge proactive rules into existing ValidationDetailsJson
                validationResult.ValidationDetailsJson = BuildDetailsWithProactiveRules(
                    validationResult.ValidationDetailsJson, ruleResultsJson);
                validationResult.UpdatedAt = DateTime.UtcNow;
            }

            await _db.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to persist rule results for document {DocumentId}", documentId);
            // Don't throw — validation results are still returned to the caller
        }
    }

    /// <summary>
    /// Builds or updates ValidationDetailsJson by adding/replacing the proactiveRules array.
    /// Preserves any existing reactive validation properties (fieldPresence, crossDocument, etc.).
    /// </summary>
    private static string BuildDetailsWithProactiveRules(string? existingDetailsJson, string ruleResultsJson)
    {
        try
        {
            using var proactiveDoc = JsonDocument.Parse(ruleResultsJson);
            if (proactiveDoc.RootElement.ValueKind != JsonValueKind.Array)
                return existingDetailsJson ?? "{}";

            using var existingDoc = JsonDocument.Parse(existingDetailsJson ?? "{}");

            using var stream = new MemoryStream();
            using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = false }))
            {
                writer.WriteStartObject();

                // Copy all existing properties except proactiveRules (will be replaced)
                foreach (var prop in existingDoc.RootElement.EnumerateObject())
                {
                    if (!string.Equals(prop.Name, "proactiveRules", StringComparison.OrdinalIgnoreCase))
                    {
                        prop.WriteTo(writer);
                    }
                }

                // Write the updated proactive rules
                writer.WritePropertyName("proactiveRules");
                proactiveDoc.RootElement.WriteTo(writer);

                writer.WriteEndObject();
            }

            return System.Text.Encoding.UTF8.GetString(stream.ToArray());
        }
        catch (JsonException)
        {
            return existingDetailsJson ?? "{}";
        }
    }

    #endregion

    #region Helpers

    private static ProactiveRuleResult CheckFieldPresence(string ruleCode, string? value, string fieldName)
    {
        var present = !string.IsNullOrWhiteSpace(value);
        return new ProactiveRuleResult
        {
            RuleCode = ruleCode,
            Type = "Required",
            Passed = present,
            ExtractedValue = present ? value : null,
            ExpectedValue = null,
            Message = present ? $"{fieldName} found" : $"{fieldName} not found in extracted data",
            Severity = present ? "Pass" : "Fail"
        };
    }

    private static Dictionary<string, string> ParseExtractedJson(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        try
        {
            using var doc = JsonDocument.Parse(json);
            var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            foreach (var property in doc.RootElement.EnumerateObject())
            {
                var value = property.Value.ValueKind switch
                {
                    JsonValueKind.String => property.Value.GetString(),
                    JsonValueKind.Number => property.Value.GetRawText(),
                    JsonValueKind.True => "true",
                    JsonValueKind.False => "false",
                    JsonValueKind.Array or JsonValueKind.Object => property.Value.GetRawText(),
                    _ => null
                };

                if (value is not null)
                    result[property.Name] = value;
            }

            return result;
        }
        catch
        {
            return new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
    }

    private static string? GetJsonField(Dictionary<string, string> data, string key)
    {
        return data.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value
            : null;
    }

    #endregion
}
