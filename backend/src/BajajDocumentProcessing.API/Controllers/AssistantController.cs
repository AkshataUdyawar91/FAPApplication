using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Guided workflow assistant controller.
/// Handles the copilot-style chat for field activity requests.
/// </summary>
[ApiController]
[Route("api/assistant")]
[Authorize]
public class AssistantController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AssistantController> _logger;
    private readonly IReferenceDataService _referenceData;

    public AssistantController(
        IApplicationDbContext context,
        ILogger<AssistantController> logger,
        IReferenceDataService referenceData)
    {
        _context = context;
        _logger = logger;
        _referenceData = referenceData;
    }

    /// <summary>
    /// Process an assistant message and return the next response.
    /// </summary>
    [HttpPost("message")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> ProcessMessage(
        [FromBody] AssistantRequest request,
        CancellationToken ct = default)
    {
        var agencyId = await GetAgencyIdAsync(ct);
        if (agencyId == null) return Forbid();

        try
        {
            var response = request.Action?.ToLowerInvariant() switch
            {
                "greet" => BuildGreeting(),
                "create_request" => BuildCreateRequestPrompt(),
                "view_requests" => BuildViewRequestsPrompt(),
                "pending_approvals" => BuildPendingApprovalsPrompt(),
                "search_po" => await HandleSearchPO(request, agencyId.Value, ct),
                "select_po" => await HandleSelectPO(request, agencyId.Value, ct),
                "select_state" => await HandleSelectState(request, agencyId.Value, ct),
                "search_state" => HandleSearchState(request, ct),
                "list_states" => HandleListAllStates(),
                "invoice_uploaded" => await HandleInvoiceUploaded(request, agencyId.Value, ct),
                "continue_invoice" => await HandleContinueInvoice(request, agencyId.Value, ct),
                "reupload_invoice" => HandleReuploadInvoice(),
                "activity_summary_uploaded" => await HandleActivitySummaryUploaded(request, agencyId.Value, ct),
                "reupload_activity_summary" => HandleReuploadActivitySummary(),
                "continue_after_activity" => await HandleContinueAfterActivity(request, agencyId.Value, ct),
                "cost_summary_uploaded" => await HandleCostSummaryUploaded(request, agencyId.Value, ct),
                "reupload_cost_summary" => HandleReuploadCostSummary(),
                "continue_after_cost_summary" => HandleContinueAfterCostSummary(request),
                _ => BuildGreeting(),
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing assistant message");
            return StatusCode(500, new AssistantResponse
            {
                Type = "error",
                Message = "Something went wrong. Please try again.",
            });
        }
    }

    private static AssistantResponse BuildGreeting()
    {
        return new AssistantResponse
        {
            Type = "greeting",
            Message = "Hello! I am your Field Activity Assistant. I can help you manage campaign requests.",
            Cards = new List<WorkflowCard>
            {
                new() { Id = "create_request", Title = "Create Request", Subtitle = "Start a new campaign claim", Icon = "add_circle_outline", Action = "create_request" },
                new() { Id = "view_requests", Title = "View My Requests", Subtitle = "Track your submissions", Icon = "list_alt", Action = "view_requests" },
                new() { Id = "pending_approvals", Title = "Pending Approvals", Subtitle = "Items awaiting action", Icon = "pending_actions", Action = "pending_approvals" },
            },
        };
    }

    private static AssistantResponse BuildCreateRequestPrompt()
    {
        return new AssistantResponse
        {
            Type = "po_search",
            Message = "Type your PO number (e.g., 4500012345)",
            InputHint = "Search PO number...",
            MinSearchLength = 3,
        };
    }

    private static AssistantResponse BuildViewRequestsPrompt()
    {
        return new AssistantResponse
        {
            Type = "text",
            Message = "This feature is coming soon. You'll be able to view and track all your submissions here.",
        };
    }

    private static AssistantResponse BuildPendingApprovalsPrompt()
    {
        return new AssistantResponse
        {
            Type = "text",
            Message = "This feature is coming soon. You'll see items pending your review here.",
        };
    }

    private async Task<AssistantResponse> HandleSearchPO(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var query = request.Message?.Trim() ?? "";
        if (query.Length < 3)
        {
            return new AssistantResponse
            {
                Type = "po_search",
                Message = "Type at least 3 characters to search.",
                InputHint = "Search PO number...",
                MinSearchLength = 3,
            };
        }

        var results = await _context.POs
            .Where(p => p.AgencyId == agencyId
                        && !p.IsDeleted
                        && (p.POStatus == "Open" || p.POStatus == "PartiallyConsumed")
                        && p.PONumber != null && p.PONumber.Contains(query))
            .OrderByDescending(p => p.PODate)
            .Take(10)
            .Select(p => new POItem
            {
                Id = p.Id.ToString(),
                PONumber = p.PONumber ?? "",
                PODate = p.PODate ?? DateTime.MinValue,
                VendorName = p.VendorName ?? "",
                TotalAmount = p.TotalAmount ?? 0,
                RemainingBalance = p.RemainingBalance,
                POStatus = p.POStatus ?? "Unknown",
            })
            .ToListAsync(ct);

        return new AssistantResponse
        {
            Type = "po_search_results",
            Message = results.Count > 0
                ? $"Found {results.Count} PO(s) matching \"{query}\". Select one to continue."
                : $"No POs found matching \"{query}\". Try a different number.",
            POItems = results,
            InputHint = "Search PO number...",
            MinSearchLength = 3,
        };
    }

    private async Task<AssistantResponse> HandleSelectPO(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        if (string.IsNullOrEmpty(request.PayloadJson))
        {
            return BuildCreateRequestPrompt();
        }

        var payload = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(request.PayloadJson);
        if (!payload.TryGetProperty("poId", out var poIdProp) ||
            !Guid.TryParse(poIdProp.GetString(), out var poId))
        {
            return BuildCreateRequestPrompt();
        }

        var po = await _context.POs
            .FirstOrDefaultAsync(p => p.Id == poId && !p.IsDeleted && p.AgencyId == agencyId, ct);

        if (po == null)
        {
            return new AssistantResponse
            {
                Type = "error",
                Message = "Selected PO not found. Please search again.",
            };
        }

        // PO selected — skip upload, go directly to state selection
        var stateResponse = await BuildStateSelectionPrompt(agencyId, po.PONumber ?? poId.ToString(), ct);
        // Return selectedPO so frontend stores it for the invoice upload step
        return new AssistantResponse
        {
            Type = stateResponse.Type,
            Message = stateResponse.Message,
            Cards = stateResponse.Cards,
            InputHint = stateResponse.InputHint,
            MinSearchLength = stateResponse.MinSearchLength,
            SelectedPO = new POItem
            {
                Id = po.Id.ToString(),
                PONumber = po.PONumber ?? "",
                PODate = po.PODate ?? DateTime.MinValue,
                VendorName = po.VendorName ?? "",
                TotalAmount = po.TotalAmount ?? 0,
                RemainingBalance = po.RemainingBalance,
                POStatus = po.POStatus ?? "Unknown",
            },
        };
    }

    // ── Phase 3: State & Activity Region Selection ──────────────────────

    private async Task<AssistantResponse> BuildStateSelectionPrompt(
        Guid agencyId, string poNumber, CancellationToken ct)
    {
        // Get top 4 most frequently used states for this agency
        var frequentStates = await _context.DocumentPackages
            .Where(p => p.AgencyId == agencyId && p.ActivityState != null && !p.IsDeleted)
            .GroupBy(p => p.ActivityState!)
            .OrderByDescending(g => g.Count())
            .Take(4)
            .Select(g => g.Key)
            .ToListAsync(ct);

        // If no history, use default popular states
        if (frequentStates.Count == 0)
        {
            frequentStates = new List<string> { "Maharashtra", "Gujarat", "Karnataka", "Tamil Nadu" };
        }

        var stateButtons = frequentStates
            .Select(s => new WorkflowCard
            {
                Id = $"state_{s.ToLowerInvariant().Replace(" ", "_")}",
                Title = s,
                Subtitle = "",
                Icon = "location_on",
                Action = "select_state",
            })
            .ToList();

        stateButtons.Add(new WorkflowCard
        {
            Id = "more_states",
            Title = "More states...",
            Subtitle = "Search all 36 states/UTs",
            Icon = "search",
            Action = "list_states",
        });

        return new AssistantResponse
        {
            Type = "state_selection",
            Message = $"PO {poNumber} selected. Which state was this activity conducted in? Start typing or select:",
            Cards = stateButtons,
            InputHint = "Type state name...",
            MinSearchLength = 1,
        };
    }

    private async Task<AssistantResponse> HandleSelectState(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var stateName = request.Message?.Trim();

        // Also check payloadJson for state from card tap
        if (string.IsNullOrEmpty(stateName) && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("state", out var stateProp))
            {
                stateName = stateProp.GetString();
            }
        }

        if (string.IsNullOrWhiteSpace(stateName))
        {
            return await BuildStateSelectionPrompt(agencyId, "your PO", ct);
        }

        // Validate against known states
        var validState = AllIndianStates.FirstOrDefault(
            s => s.Equals(stateName, StringComparison.OrdinalIgnoreCase));

        if (validState == null)
        {
            return new AssistantResponse
            {
                Type = "state_selection",
                Message = $"\"{stateName}\" is not a recognized state. Please select from the list or type a valid state name.",
                InputHint = "Type state name...",
                MinSearchLength = 1,
            };
        }

        // Read PO ID from payload
        Guid? selectedPoId = null;
        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var pl = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(request.PayloadJson);
                if (pl.TryGetProperty("poId", out var poIdProp) && Guid.TryParse(poIdProp.GetString(), out var pid))
                    selectedPoId = pid;
            }
            catch { }
        }
        _logger.LogInformation("=== SELECT STATE === State: {State}, PayloadJson: {Payload}, SelectedPOId: {POId}",
            stateName, request.PayloadJson, selectedPoId);

        // Create draft submission with PO and state
        var userIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        Guid? userId = null;
        if (!string.IsNullOrEmpty(userIdClaim) && Guid.TryParse(userIdClaim, out var uid))
            userId = uid;

        Guid? submissionId = null;
        try
        {
            var package = new Domain.Entities.DocumentPackage
            {
                Id = Guid.NewGuid(),
                SubmittedByUserId = userId ?? Guid.Empty,
                AgencyId = agencyId,
                State = Domain.Enums.PackageState.Draft,
                SelectedPOId = selectedPoId,
                ActivityState = validState,
                CurrentStep = 4,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            _context.DocumentPackages.Add(package);
            await _context.SaveChangesAsync(ct);
            submissionId = package.Id;
            _logger.LogInformation("Draft submission {Id} created for state {State}", package.Id, validState);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create draft submission");
        }

        return new AssistantResponse
        {
            Type = "invoice_upload",
            Message = $"State set to {validState}. Please upload the invoice document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG" },
            SubmissionId = submissionId,
            Cards = new List<WorkflowCard>
            {
                new() { Id = "upload_device", Title = "Upload from device", Subtitle = "Select a file from your device", Icon = "upload_file", Action = "upload_invoice" },
                new() { Id = "take_photo", Title = "Take photo", Subtitle = "Capture using camera", Icon = "camera_alt", Action = "take_photo" },
            },
        };
    }

    private async Task<AssistantResponse> HandleInvoiceUploaded(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        // Frontend sends documentId after extraction completes
        string? documentId = request.Message?.Trim();
        Guid? submissionIdFromPayload = null;

        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (string.IsNullOrEmpty(documentId) && payload.TryGetProperty("documentId", out var docProp))
                    documentId = docProp.GetString();
                if (payload.TryGetProperty("submissionId", out var subProp) && Guid.TryParse(subProp.GetString(), out var sid))
                    submissionIdFromPayload = sid;
            }
            catch { }
        }

        if (string.IsNullOrWhiteSpace(documentId) || !Guid.TryParse(documentId, out var docId))
        {
            return new AssistantResponse
            {
                Type = "error",
                Message = "Invoice upload confirmation missing. Please try uploading again.",
            };
        }

        _logger.LogInformation("=== INVOICE VALIDATION === DocumentId: {DocId}, SubmissionId: {SubId}", docId, submissionIdFromPayload);

        // Load invoice from DB
        var invoice = await _context.Invoices
            .Include(i => i.PO)
            .Include(i => i.Package)
            .FirstOrDefaultAsync(i => i.Id == docId && !i.IsDeleted, ct);

        if (invoice == null)
        {
            return new AssistantResponse
            {
                Type = "error",
                Message = "Invoice document not found. Please try uploading again.",
            };
        }

        // Load PO — prefer from package's SelectedPOId, fall back to invoice.POId
        var package = invoice.Package;
        var poId = package?.SelectedPOId ?? invoice.POId;
        var po = await _context.POs.FirstOrDefaultAsync(p => p.Id == poId && !p.IsDeleted, ct);

        // Compute live PO available balance at this exact moment:
        // PO.TotalAmount minus sum of TotalAmount of all other non-deleted invoices on this PO
        // (excluding the current invoice being validated)
        decimal? livePoBalance = null;
        if (po != null && po.TotalAmount.HasValue)
        {
            var alreadyConsumed = await _context.Invoices
                .Where(i => i.POId == po.Id && !i.IsDeleted && i.Id != docId && i.TotalAmount.HasValue)
                .SumAsync(i => i.TotalAmount!.Value, ct);
            livePoBalance = po.TotalAmount.Value - alreadyConsumed;
        }

        // Run the 9 proactive validation rules
        var rules = RunInvoiceValidationRules(invoice, po, livePoBalance);

        int passCount = rules.Count(r => r.Passed && !r.IsWarning);
        int failCount = rules.Count(r => !r.Passed && !r.IsWarning);
        int warnCount = rules.Count(r => r.IsWarning);
        int totalChecks = rules.Count;

        // Short summary message — the validation card widget shows the detail
        string botMessage;
        if (failCount == 0 && warnCount == 0)
            botMessage = $"Invoice analysed. All {totalChecks} checks passed!";
        else
            botMessage = $"Invoice analysed. {passCount} of {totalChecks} checks passed.{(failCount > 0 ? $" {failCount} failed." : "")}{(warnCount > 0 ? $" {warnCount} warning(s)." : "")} Review below and continue or re-upload.";

        // Always persist validation results to ValidationResults table — regardless of pass/fail
        try
        {
            var ruleResultsJson = JsonSerializer.Serialize(rules.Select(r => new
            {
                ruleCode = r.RuleCode,
                type = r.Type,
                passed = r.Passed,
                isWarning = r.IsWarning,
                label = r.Label,
                extractedValue = r.ExtractedValue,
                message = r.Message,
            }));

            var failureReason = failCount > 0
                ? string.Join("; ", rules.Where(r => !r.Passed && !r.IsWarning).Select(r => r.Message ?? r.Label))
                : warnCount > 0
                    ? string.Join("; ", rules.Where(r => r.IsWarning).Select(r => r.Message ?? r.Label))
                    : null;

            var existingResult = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (existingResult != null)
            {
                existingResult.AllValidationsPassed = failCount == 0;
                existingResult.RuleResultsJson = ruleResultsJson;
                existingResult.FailureReason = failureReason;
                existingResult.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                _context.ValidationResults.Add(new Domain.Entities.ValidationResult
                {
                    Id = Guid.NewGuid(),
                    DocumentType = DocumentType.Invoice,
                    DocumentId = docId,
                    AllValidationsPassed = failCount == 0,
                    RuleResultsJson = ruleResultsJson,
                    FailureReason = failureReason,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            await _context.SaveChangesAsync(ct);
            _logger.LogInformation(
                "=== INVOICE VALIDATION SAVED === DocId: {DocId}, Passed: {Passed}, Fails: {Fails}, Warnings: {Warns}",
                docId, failCount == 0, failCount, warnCount);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to persist invoice validation results for document {DocId}", docId);
        }

        // Read back from DB to build response — ensures UI always reflects persisted data
        List<ValidationRuleResult> responseRules = rules; // fallback to in-memory
        try
        {
            var saved = await _context.ValidationResults
                .AsNoTracking()
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (saved?.RuleResultsJson != null)
            {
                var dbRules = JsonSerializer.Deserialize<List<ValidationRuleResult>>(
                    saved.RuleResultsJson,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (dbRules != null && dbRules.Count > 0)
                {
                    responseRules = dbRules;
                    // Recompute counts from DB data
                    passCount = responseRules.Count(r => r.Passed && !r.IsWarning);
                    failCount = responseRules.Count(r => !r.Passed && !r.IsWarning);
                    warnCount = responseRules.Count(r => r.IsWarning);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to read back validation results from DB for {DocId}, using in-memory fallback", docId);
        }

        return new AssistantResponse
        {
            Type = "invoice_validation",
            Message = botMessage,
            ValidationRules = responseRules,
            PassedCount = passCount,
            FailedCount = failCount,
            WarningCount = warnCount,
            SubmissionId = submissionIdFromPayload ?? invoice.PackageId,
        };
    }

    /// <summary>
    /// Runs the 9 proactive invoice validation rules against extracted invoice data + PO master.
    /// </summary>
    private List<ValidationRuleResult> RunInvoiceValidationRules(
        Domain.Entities.Invoice invoice, Domain.Entities.PO? po, decimal? livePoBalance = null)
    {
        var rules = new List<ValidationRuleResult>();

        // 1. INV_INVOICE_NUMBER_PRESENT — Required
        var invNumPresent = !string.IsNullOrWhiteSpace(invoice.InvoiceNumber);
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_INVOICE_NUMBER_PRESENT",
            Type = "Required",
            Passed = invNumPresent,
            IsWarning = false,
            Label = "Invoice Number",
            ExtractedValue = invoice.InvoiceNumber,
            Message = invNumPresent ? null : "Invoice number not detected",
        });

        // 2. INV_DATE_PRESENT — Required
        var datePresent = invoice.InvoiceDate.HasValue && invoice.InvoiceDate.Value != default;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_DATE_PRESENT",
            Type = "Required",
            Passed = datePresent,
            IsWarning = false,
            Label = "Invoice Date",
            ExtractedValue = invoice.InvoiceDate?.ToString("dd-MMM-yyyy"),
            Message = datePresent ? null : "Invoice date not detected",
        });

        // 3. INV_AMOUNT_PRESENT — Required
        var amountPresent = invoice.TotalAmount.HasValue && invoice.TotalAmount.Value > 0;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_AMOUNT_PRESENT",
            Type = "Required",
            Passed = amountPresent,
            IsWarning = false,
            Label = "Invoice Amount",
            ExtractedValue = invoice.TotalAmount.HasValue ? $"₹{invoice.TotalAmount.Value:N0}" : null,
            Message = amountPresent ? null : "Invoice amount not detected or zero",
        });

        // 4. INV_GST_NUMBER_PRESENT — Required (15-char alphanumeric)
        var gstPresent = !string.IsNullOrWhiteSpace(invoice.GSTNumber) && invoice.GSTNumber.Length == 15;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_GST_NUMBER_PRESENT",
            Type = "Required",
            Passed = gstPresent,
            IsWarning = false,
            Label = "GST Number",
            ExtractedValue = invoice.GSTNumber,
            Message = gstPresent ? null : (string.IsNullOrWhiteSpace(invoice.GSTNumber) ? "Not detected" : "Invalid format (must be 15 chars)"),
        });

        // 5. INV_GST_PERCENT_PRESENT — Required (expected 18%, checked against state)
        // Try to read GSTPercentage from ExtractedDataJson
        decimal? gstPercent = null;
        if (!string.IsNullOrEmpty(invoice.ExtractedDataJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(invoice.ExtractedDataJson);
                if (json.TryGetProperty("GSTPercentage", out var gp) || json.TryGetProperty("gstPercentage", out gp))
                    gstPercent = gp.GetDecimal();
            }
            catch { }
        }
        var gstPercentPresent = gstPercent.HasValue && gstPercent.Value > 0;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_GST_PERCENT_PRESENT",
            Type = "Required",
            Passed = gstPercentPresent,
            IsWarning = false,
            Label = "GST %",
            ExtractedValue = gstPercent.HasValue ? $"{gstPercent.Value}%" : null,
            Message = gstPercentPresent ? null : "GST percentage not detected",
        });

        // 6. INV_HSN_SAC_PRESENT — Required
        string? hsnSac = null;
        if (!string.IsNullOrEmpty(invoice.ExtractedDataJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(invoice.ExtractedDataJson);
                if (json.TryGetProperty("HSNSACCode", out var hp) || json.TryGetProperty("hsnSacCode", out hp))
                    hsnSac = hp.GetString();
            }
            catch { }
        }
        var hsnPresent = !string.IsNullOrWhiteSpace(hsnSac);
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_HSN_SAC_PRESENT",
            Type = "Required",
            Passed = hsnPresent,
            IsWarning = false,
            Label = "HSN/SAC Code",
            ExtractedValue = hsnSac,
            Message = hsnPresent ? null : "HSN/SAC code not detected",
        });

        // 7. INV_VENDOR_CODE_PRESENT — Required
        string? vendorCode = null;
        if (!string.IsNullOrEmpty(invoice.ExtractedDataJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(invoice.ExtractedDataJson);
                if (json.TryGetProperty("VendorCode", out var vc) || json.TryGetProperty("vendorCode", out vc))
                    vendorCode = vc.GetString();
            }
            catch { }
        }
        var vendorCodePresent = !string.IsNullOrWhiteSpace(vendorCode);
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_VENDOR_CODE_PRESENT",
            Type = "Required",
            Passed = vendorCodePresent,
            IsWarning = false,
            Label = "Vendor Code",
            ExtractedValue = vendorCode,
            Message = vendorCodePresent ? null : "Vendor code not detected",
        });

        // 8. INV_PO_NUMBER_MATCH — Check (extracted PO number == POs.PONumber)
        string? extractedPoNumber = null;
        if (!string.IsNullOrEmpty(invoice.ExtractedDataJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(invoice.ExtractedDataJson);
                if (json.TryGetProperty("PONumber", out var pn) || json.TryGetProperty("poNumber", out pn))
                    extractedPoNumber = pn.GetString();
            }
            catch { }
        }

        bool poMatch;
        string? poMatchMsg;
        if (po == null)
        {
            poMatch = false;
            poMatchMsg = "PO master data not found";
        }
        else if (string.IsNullOrWhiteSpace(extractedPoNumber))
        {
            poMatch = false;
            poMatchMsg = "PO number not extracted from invoice";
        }
        else
        {
            poMatch = extractedPoNumber.Equals(po.PONumber, StringComparison.OrdinalIgnoreCase);
            poMatchMsg = poMatch
                ? $"matches selected PO ✓"
                : $"does NOT match selected PO {po.PONumber}";
        }
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_PO_NUMBER_MATCH",
            Type = "Check",
            Passed = poMatch,
            IsWarning = false,
            Label = "PO Number",
            ExtractedValue = extractedPoNumber,
            Message = poMatchMsg,
        });

        // 9. INV_AMOUNT_VS_PO_BALANCE — Check (warning if exceeded, not hard block)
        // Uses live balance computed at this exact moment: PO.TotalAmount - sum of other invoices on this PO
        bool amountOk;
        bool isAmountWarning;
        string? amountMsg;
        if (po == null || !invoice.TotalAmount.HasValue)
        {
            amountOk = true;
            isAmountWarning = false;
            amountMsg = po == null ? "PO balance not available" : null;
        }
        else
        {
            // Prefer live computed balance; fall back to stored RemainingBalance, then TotalAmount
            var balance = livePoBalance ?? po.RemainingBalance ?? po.TotalAmount ?? 0;
            amountOk = invoice.TotalAmount.Value <= balance;
            isAmountWarning = !amountOk;
            amountMsg = amountOk
                ? $"within available PO balance (₹{balance:N0})"
                : $"₹{invoice.TotalAmount.Value:N0} exceeds available PO balance (₹{balance:N0})";
        }
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "INV_AMOUNT_VS_PO_BALANCE",
            Type = "Check",
            Passed = amountOk,
            IsWarning = isAmountWarning,
            Label = "Amount vs PO Balance",
            ExtractedValue = invoice.TotalAmount.HasValue ? $"₹{invoice.TotalAmount.Value:N0}" : null,
            Message = amountMsg,
        });

        return rules;
    }

    private async Task<AssistantResponse> HandleContinueInvoice(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        // User confirmed invoice — move to Cost Summary upload
        var submissionId = ExtractSubmissionId(request);
        return new AssistantResponse
        {
            Type = "cost_summary_upload",
            Message = "Invoice accepted. Now please upload the Cost Summary document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG", "XLS", "XLSX" },
            SubmissionId = submissionId,
            Cards = new List<WorkflowCard>
            {
                new() { Id = "upload_cost_summary", Title = "Upload Cost Summary", Subtitle = "Select a file from your device", Icon = "upload_file", Action = "upload_cost_summary" },
            },
        };
    }

    private static AssistantResponse HandleReuploadActivitySummary()
    {
        return new AssistantResponse
        {
            Type = "activity_summary_upload",
            Message = "Please upload the corrected Activity Summary document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG", "XLS", "XLSX" },
            Cards = new List<WorkflowCard>
            {
                new() { Id = "upload_activity", Title = "Upload Activity Summary", Subtitle = "Select a file from your device", Icon = "upload_file", Action = "upload_activity_summary" },
            },
        };
    }

    private async Task<AssistantResponse> HandleActivitySummaryUploaded(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        string? documentId = request.Message?.Trim();
        Guid? submissionIdFromPayload = null;

        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (string.IsNullOrEmpty(documentId) && payload.TryGetProperty("documentId", out var docProp))
                    documentId = docProp.GetString();
                if (payload.TryGetProperty("submissionId", out var subProp) && Guid.TryParse(subProp.GetString(), out var sid))
                    submissionIdFromPayload = sid;
            }
            catch { }
        }

        if (string.IsNullOrWhiteSpace(documentId) || !Guid.TryParse(documentId, out var docId))
            return new AssistantResponse { Type = "error", Message = "Activity Summary upload confirmation missing. Please try uploading again." };

        _logger.LogInformation("=== ACTIVITY SUMMARY VALIDATION === DocumentId: {DocId}", docId);

        var actSummary = await _context.ActivitySummaries
            .FirstOrDefaultAsync(a => a.Id == docId && !a.IsDeleted, ct);

        if (actSummary == null)
            return new AssistantResponse { Type = "error", Message = "Activity Summary document not found. Please try uploading again." };

        // Run validation rules
        var rules = RunActivitySummaryValidationRules(actSummary);

        int passCount = rules.Count(r => r.Passed && !r.IsWarning);
        int failCount = rules.Count(r => !r.Passed && !r.IsWarning);
        int warnCount = rules.Count(r => r.IsWarning);

        string botMessage = failCount == 0 && warnCount == 0
            ? $"Activity Summary analysed. All {rules.Count} checks passed!"
            : $"Activity Summary analysed. {passCount} of {rules.Count} checks passed.{(failCount > 0 ? $" {failCount} failed." : "")}{(warnCount > 0 ? $" {warnCount} warning(s)." : "")} Review below and continue or re-upload.";

        // Persist to ValidationResults table
        try
        {
            var ruleResultsJson = JsonSerializer.Serialize(rules.Select(r => new
            {
                ruleCode = r.RuleCode,
                type = r.Type,
                passed = r.Passed,
                isWarning = r.IsWarning,
                label = r.Label,
                extractedValue = r.ExtractedValue,
                message = r.Message,
            }));

            var failureReason = failCount > 0
                ? string.Join("; ", rules.Where(r => !r.Passed && !r.IsWarning).Select(r => r.Message ?? r.Label))
                : warnCount > 0 ? string.Join("; ", rules.Where(r => r.IsWarning).Select(r => r.Message ?? r.Label))
                : null;

            var existing = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (existing != null)
            {
                existing.AllValidationsPassed = failCount == 0;
                existing.RuleResultsJson = ruleResultsJson;
                existing.FailureReason = failureReason;
                existing.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                _context.ValidationResults.Add(new Domain.Entities.ValidationResult
                {
                    Id = Guid.NewGuid(),
                    DocumentType = DocumentType.ActivitySummary,
                    DocumentId = docId,
                    AllValidationsPassed = failCount == 0,
                    RuleResultsJson = ruleResultsJson,
                    FailureReason = failureReason,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            await _context.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to persist activity summary validation results for {DocId}", docId);
        }

        // Read back from DB — UI always reflects persisted data
        List<ValidationRuleResult> responseRules = rules;
        try
        {
            var saved = await _context.ValidationResults
                .AsNoTracking()
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (saved?.RuleResultsJson != null)
            {
                var dbRules = JsonSerializer.Deserialize<List<ValidationRuleResult>>(
                    saved.RuleResultsJson,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (dbRules != null && dbRules.Count > 0)
                {
                    responseRules = dbRules;
                    passCount = responseRules.Count(r => r.Passed && !r.IsWarning);
                    failCount = responseRules.Count(r => !r.Passed && !r.IsWarning);
                    warnCount = responseRules.Count(r => r.IsWarning);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to read back activity summary validation from DB for {DocId}", docId);
        }

        return new AssistantResponse
        {
            Type = "activity_summary_validation",
            Message = botMessage,
            ValidationRules = responseRules,
            PassedCount = passCount,
            FailedCount = failCount,
            WarningCount = warnCount,
            SubmissionId = submissionIdFromPayload ?? actSummary.PackageId,
        };
    }

    private List<ValidationRuleResult> RunActivitySummaryValidationRules(Domain.Entities.ActivitySummary actSummary)
    {
        var rules = new List<ValidationRuleResult>();

        // Parse extracted JSON once
        string? dealerName = actSummary.DealerName;
        string? location = null;

        if (!string.IsNullOrEmpty(actSummary.ExtractedDataJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(actSummary.ExtractedDataJson);
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
            catch { }
        }

        // AS_DEALER_LOCATION_PRESENT — dealer name AND location must both be present
        bool dealerPresent = !string.IsNullOrWhiteSpace(dealerName);
        bool locationPresent = !string.IsNullOrWhiteSpace(location);
        bool dealerLocationPassed = dealerPresent && locationPresent;

        string extractedDisplay = dealerPresent || locationPresent
            ? string.Join(", ", new[] { dealerName, location }.Where(s => !string.IsNullOrWhiteSpace(s)))
            : null!;

        rules.Add(new ValidationRuleResult
        {
            RuleCode = "AS_DEALER_LOCATION_PRESENT",
            Type = "Required",
            Passed = dealerLocationPassed,
            IsWarning = false,
            Label = "Dealer & Location Details",
            ExtractedValue = string.IsNullOrWhiteSpace(extractedDisplay) ? null : extractedDisplay,
            Message = dealerLocationPassed ? null
                : !dealerPresent && !locationPresent ? "Dealer name and location not detected"
                : !dealerPresent ? "Dealer name not detected"
                : "Location not detected",
        });

        // Info rows — always pass, show extracted values
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "AS_TOTAL_DAYS",
            Type = "Info",
            Passed = true,
            IsWarning = false,
            Label = "Total No. of Days",
            ExtractedValue = actSummary.TotalDays.HasValue ? actSummary.TotalDays.ToString() : "Not extracted",
            Message = null,
        });

        rules.Add(new ValidationRuleResult
        {
            RuleCode = "AS_TOTAL_WORKING_DAYS",
            Type = "Info",
            Passed = true,
            IsWarning = false,
            Label = "Total No. of Working Days",
            ExtractedValue = actSummary.TotalWorkingDays.HasValue ? actSummary.TotalWorkingDays.ToString() : "Not extracted",
            Message = null,
        });

        return rules;
    }


    private async Task<AssistantResponse> HandleContinueAfterActivity(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        return new AssistantResponse
        {
            Type = "text",
            Message = "Activity Summary accepted. Phase 8 (Team Details) coming soon.",
        };
    }

    private async Task<AssistantResponse> HandleCostSummaryUploaded(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        string? documentId = request.Message?.Trim();
        Guid? submissionIdFromPayload = null;

        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (string.IsNullOrEmpty(documentId) && payload.TryGetProperty("documentId", out var docProp))
                    documentId = docProp.GetString();
                if (payload.TryGetProperty("submissionId", out var subProp) && Guid.TryParse(subProp.GetString(), out var sid))
                    submissionIdFromPayload = sid;
            }
            catch { }
        }

        if (string.IsNullOrWhiteSpace(documentId) || !Guid.TryParse(documentId, out var docId))
            return new AssistantResponse { Type = "error", Message = "Cost Summary upload confirmation missing. Please try uploading again." };

        _logger.LogInformation("=== COST SUMMARY VALIDATION === DocumentId: {DocId}", docId);

        var costSummary = await _context.CostSummaries
            .FirstOrDefaultAsync(c => c.Id == docId && !c.IsDeleted, ct);

        if (costSummary == null)
            return new AssistantResponse { Type = "error", Message = "Cost Summary document not found. Please try uploading again." };

        var rules = RunCostSummaryValidationRules(costSummary);

        int passCount = rules.Count(r => r.Passed && !r.IsWarning);
        int failCount = rules.Count(r => !r.Passed && !r.IsWarning);
        int warnCount = rules.Count(r => r.IsWarning);

        string botMessage = failCount == 0 && warnCount == 0
            ? $"Cost Summary analysed. All {rules.Count} checks passed!"
            : $"Cost Summary analysed. {passCount} of {rules.Count} checks passed.{(failCount > 0 ? $" {failCount} failed." : "")}{(warnCount > 0 ? $" {warnCount} warning(s)." : "")} Review below and continue or re-upload.";

        // Persist to ValidationResults
        try
        {
            var ruleResultsJson = JsonSerializer.Serialize(rules.Select(r => new
            {
                ruleCode = r.RuleCode,
                type = r.Type,
                passed = r.Passed,
                isWarning = r.IsWarning,
                label = r.Label,
                extractedValue = r.ExtractedValue,
                message = r.Message,
            }));

            var failureReason = failCount > 0
                ? string.Join("; ", rules.Where(r => !r.Passed && !r.IsWarning).Select(r => r.Message ?? r.Label))
                : warnCount > 0 ? string.Join("; ", rules.Where(r => r.IsWarning).Select(r => r.Message ?? r.Label))
                : null;

            var existing = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (existing != null)
            {
                existing.AllValidationsPassed = failCount == 0;
                existing.RuleResultsJson = ruleResultsJson;
                existing.FailureReason = failureReason;
                existing.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                _context.ValidationResults.Add(new Domain.Entities.ValidationResult
                {
                    Id = Guid.NewGuid(),
                    DocumentType = DocumentType.CostSummary,
                    DocumentId = docId,
                    AllValidationsPassed = failCount == 0,
                    RuleResultsJson = ruleResultsJson,
                    FailureReason = failureReason,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            await _context.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to persist cost summary validation results for {DocId}", docId);
        }

        // Read back from DB
        List<ValidationRuleResult> responseRules = rules;
        try
        {
            var saved = await _context.ValidationResults
                .AsNoTracking()
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (saved?.RuleResultsJson != null)
            {
                var dbRules = JsonSerializer.Deserialize<List<ValidationRuleResult>>(
                    saved.RuleResultsJson,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (dbRules != null && dbRules.Count > 0)
                {
                    responseRules = dbRules;
                    passCount = responseRules.Count(r => r.Passed && !r.IsWarning);
                    failCount = responseRules.Count(r => !r.Passed && !r.IsWarning);
                    warnCount = responseRules.Count(r => r.IsWarning);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to read back cost summary validation from DB for {DocId}", docId);
        }

        return new AssistantResponse
        {
            Type = "cost_summary_validation",
            Message = botMessage,
            ValidationRules = responseRules,
            PassedCount = passCount,
            FailedCount = failCount,
            WarningCount = warnCount,
            SubmissionId = submissionIdFromPayload ?? costSummary.PackageId,
        };
    }

    private List<ValidationRuleResult> RunCostSummaryValidationRules(Domain.Entities.CostSummary costSummary)
    {
        var rules = new List<ValidationRuleResult>();

        string? placeOfSupply = costSummary.PlaceOfSupply;
        int? numberOfDays = costSummary.NumberOfDays;
        int? numberOfActivations = costSummary.NumberOfActivations;
        int? numberOfTeams = costSummary.NumberOfTeams;
        string? elementWiseCosts = costSummary.ElementWiseCostsJson;
        string? elementWiseQuantity = costSummary.ElementWiseQuantityJson;

        // Fallback: parse from ExtractedDataJson if dedicated columns are empty
        bool needsFallback = string.IsNullOrWhiteSpace(placeOfSupply)
            || numberOfDays == null
            || numberOfActivations == null
            || numberOfTeams == null
            || string.IsNullOrWhiteSpace(elementWiseCosts)
            || string.IsNullOrWhiteSpace(elementWiseQuantity);

        if (needsFallback && !string.IsNullOrEmpty(costSummary.ExtractedDataJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(costSummary.ExtractedDataJson);

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
            catch { }
        }

        // CS_PLACE_OF_SUPPLY_PRESENT
        bool posPresent = !string.IsNullOrWhiteSpace(placeOfSupply);
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "CS_PLACE_OF_SUPPLY_PRESENT",
            Type = "Required",
            Passed = posPresent,
            IsWarning = false,
            Label = "Place of Supply",
            ExtractedValue = posPresent ? placeOfSupply : null,
            Message = posPresent ? null : "Place of supply / state not detected",
        });

        // CS_TOTAL_DAYS_PRESENT
        bool daysPresent = numberOfDays.HasValue && numberOfDays.Value > 0;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "CS_TOTAL_DAYS_PRESENT",
            Type = "Required",
            Passed = daysPresent,
            IsWarning = false,
            Label = "No. of Days",
            ExtractedValue = daysPresent ? numberOfDays.ToString() : null,
            Message = daysPresent ? null : "Total number of days not detected",
        });

        // CS_ACTIVATIONS_PRESENT
        bool activationsPresent = numberOfActivations.HasValue && numberOfActivations.Value > 0;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "CS_ACTIVATIONS_PRESENT",
            Type = "Required",
            Passed = activationsPresent,
            IsWarning = false,
            Label = "No. of Activations",
            ExtractedValue = activationsPresent ? numberOfActivations.ToString() : null,
            Message = activationsPresent ? null : "Number of activations not detected",
        });

        // CS_TEAMS_PRESENT
        bool teamsPresent = numberOfTeams.HasValue && numberOfTeams.Value > 0;
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "CS_TEAMS_PRESENT",
            Type = "Required",
            Passed = teamsPresent,
            IsWarning = false,
            Label = "No. of Teams",
            ExtractedValue = teamsPresent ? numberOfTeams.ToString() : null,
            Message = teamsPresent ? null : "Number of teams not detected",
        });

        // CS_ELEMENT_WISE_COSTS_PRESENT
        bool costsPresent = !string.IsNullOrWhiteSpace(elementWiseCosts) && elementWiseCosts != "[]";
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "CS_ELEMENT_WISE_COSTS_PRESENT",
            Type = "Required",
            Passed = costsPresent,
            IsWarning = false,
            Label = "Element-wise Cost",
            ExtractedValue = costsPresent ? elementWiseCosts : null,
            Message = costsPresent ? null : "Element-wise cost breakdown not detected",
        });

        // CS_ELEMENT_WISE_QUANTITY_PRESENT
        bool qtyPresent = !string.IsNullOrWhiteSpace(elementWiseQuantity) && elementWiseQuantity != "[]";
        rules.Add(new ValidationRuleResult
        {
            RuleCode = "CS_ELEMENT_WISE_QUANTITY_PRESENT",
            Type = "Required",
            Passed = qtyPresent,
            IsWarning = false,
            Label = "Element-wise Quantity",
            ExtractedValue = qtyPresent ? elementWiseQuantity : null,
            Message = qtyPresent ? null : "Element-wise quantity breakdown not detected",
        });

        return rules;
    }

    private AssistantResponse HandleReuploadCostSummary()
    {
        return new AssistantResponse
        {
            Type = "cost_summary_upload",
            Message = "Please upload the corrected Cost Summary document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG", "XLS", "XLSX" },
            Cards = new List<WorkflowCard>
            {
                new() { Id = "upload_cost_summary", Title = "Upload Cost Summary", Subtitle = "Select a file from your device", Icon = "upload_file", Action = "upload_cost_summary" },
            },
        };
    }

    private AssistantResponse HandleContinueAfterCostSummary(AssistantRequest request)
    {
        var submissionId = ExtractSubmissionId(request);
        return new AssistantResponse
        {
            Type = "activity_summary_upload",
            Message = "Cost Summary accepted. Now please upload the Activity Summary document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG", "XLS", "XLSX" },
            SubmissionId = submissionId,
            Cards = new List<WorkflowCard>
            {
                new() { Id = "upload_activity", Title = "Upload Activity Summary", Subtitle = "Select a file from your device", Icon = "upload_file", Action = "upload_activity_summary" },
            },
        };
    }

    private Guid? ExtractSubmissionId(AssistantRequest request)
    {
        if (string.IsNullOrEmpty(request.PayloadJson)) return null;
        try
        {
            var pl = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (pl.TryGetProperty("submissionId", out var sp) && Guid.TryParse(sp.GetString(), out var sid))
                return sid;
        }
        catch { }
        return null;
    }

    private static AssistantResponse HandleReuploadInvoice()
    {
        return new AssistantResponse
        {
            Type = "invoice_upload",
            Message = "Please upload the corrected invoice document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG" },
            Cards = new List<WorkflowCard>
            {
                new() { Id = "upload_device", Title = "Upload from device", Subtitle = "Select a file from your device", Icon = "upload_file", Action = "upload_invoice" },
                new() { Id = "take_photo", Title = "Take photo", Subtitle = "Capture using camera", Icon = "camera_alt", Action = "take_photo" },
            },
        };
    }

    private static AssistantResponse HandleSearchState(
        AssistantRequest request, CancellationToken ct)
    {
        var query = request.Message?.Trim() ?? "";
        if (query.Length < 1)
        {
            return HandleListAllStates();
        }

        var matches = AllIndianStates
            .Where(s => s.Contains(query, StringComparison.OrdinalIgnoreCase))
            .Take(10)
            .ToList();

        return new AssistantResponse
        {
            Type = "state_search_results",
            Message = matches.Count > 0
                ? $"Found {matches.Count} state(s) matching \"{query}\". Select one:"
                : $"No states found matching \"{query}\". Try a different name.",
            States = matches,
            InputHint = "Type state name...",
            MinSearchLength = 1,
        };
    }

    private static AssistantResponse HandleListAllStates()
    {
        return new AssistantResponse
        {
            Type = "state_search_results",
            Message = "Select a state from the list below, or type to search:",
            States = AllIndianStates,
            InputHint = "Type state name...",
            MinSearchLength = 1,
        };
    }

    private static readonly List<string> AllIndianStates = new()
    {
        "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
        "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand",
        "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur",
        "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab",
        "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura",
        "Uttar Pradesh", "Uttarakhand", "West Bengal",
        "Andaman and Nicobar Islands", "Chandigarh", "Dadra and Nagar Haveli and Daman and Diu",
        "Delhi", "Jammu and Kashmir", "Ladakh", "Lakshadweep", "Puducherry"
    };

    /// <summary>
    /// Upload a PO document. Wraps the existing document upload and returns assistant-style response.
    /// </summary>
    [HttpPost("/api/upload/po")]
    [Authorize(Roles = "Agency")]
    [RequestSizeLimit(52428800)]
    public async Task<IActionResult> UploadPO(
        [FromForm] IFormFile file,
        [FromForm] Guid? submissionId,
        CancellationToken ct = default)
    {
        var agencyId = await GetAgencyIdAsync(ct);
        if (agencyId == null) return Forbid();

        if (file == null || file.Length == 0)
            return BadRequest(new AssistantResponse { Type = "error", Message = "No file provided." });

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowed = new[] { ".pdf", ".doc", ".docx", ".jpg", ".jpeg", ".png" };
        if (!allowed.Contains(ext))
        {
            return BadRequest(new AssistantResponse
            {
                Type = "error",
                Message = $"File type '{ext}' is not allowed. Allowed: PDF, Word, JPG, PNG.",
            });
        }

        try
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!Guid.TryParse(userIdClaim, out var userId))
                return Unauthorized();

            // Reuse existing document service via the documents upload endpoint logic
            // For now, store minimal info and return success
            var documentService = HttpContext.RequestServices
                .GetRequiredService<IDocumentService>();

            var response = await documentService.UploadDocumentAsync(
                file, DocumentType.PO, submissionId, userId);

            return Ok(new AssistantResponse
            {
                Type = "upload_success",
                Message = "PO uploaded successfully. Please upload the invoice.",
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading PO document");
            return StatusCode(500, new AssistantResponse
            {
                Type = "error",
                Message = "Failed to upload PO. Please try again.",
            });
        }
    }

    /// <summary>
    /// Poll extraction status for a document. Frontend uses this to know when extraction is done
    /// before sending the invoice_uploaded action.
    /// </summary>
    [HttpGet("/api/documents/{id}/extraction-status")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> GetDocumentExtractionStatus(
        Guid id, CancellationToken ct = default)
    {
        var invoice = await _context.Invoices
            .AsNoTracking()
            .Where(i => i.Id == id && !i.IsDeleted)
            .Select(i => new { i.Id, i.ExtractedDataJson, i.ExtractionConfidence, i.InvoiceNumber })
            .FirstOrDefaultAsync(ct);

        if (invoice == null)
            return NotFound(new { status = "not_found" });

        var isExtracted = !string.IsNullOrEmpty(invoice.ExtractedDataJson) || !string.IsNullOrEmpty(invoice.InvoiceNumber);

        return Ok(new
        {
            documentId = invoice.Id,
            status = isExtracted ? "extracted" : "processing",
            extractionConfidence = invoice.ExtractionConfidence,
        });
    }

    private async Task<Guid?> GetAgencyIdAsync(CancellationToken ct)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
            return null;
        var user = await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId && !u.IsDeleted)
            .Select(u => new { u.AgencyId })
            .FirstOrDefaultAsync(ct);

        return user?.AgencyId;
    }
}

// --- DTOs ---

public class ValidationRuleResult
{
    [JsonPropertyName("ruleCode")]
    public required string RuleCode { get; init; }

    [JsonPropertyName("type")]
    public required string Type { get; init; }

    [JsonPropertyName("passed")]
    public bool Passed { get; init; }

    [JsonPropertyName("isWarning")]
    public bool IsWarning { get; init; }

    [JsonPropertyName("label")]
    public required string Label { get; init; }

    [JsonPropertyName("extractedValue")]
    public string? ExtractedValue { get; init; }

    [JsonPropertyName("message")]
    public string? Message { get; init; }
}

public class AssistantRequest
{
    [JsonPropertyName("userId")]
    public string? UserId { get; init; }

    [JsonPropertyName("action")]
    public string? Action { get; init; }

    [JsonPropertyName("message")]
    public string? Message { get; init; }

    [JsonPropertyName("payloadJson")]
    public string? PayloadJson { get; init; }
}

public class AssistantResponse
{
    [JsonPropertyName("type")]
    public required string Type { get; init; }

    [JsonPropertyName("message")]
    public required string Message { get; init; }

    [JsonPropertyName("cards")]
    public List<WorkflowCard>? Cards { get; init; }

    [JsonPropertyName("poItems")]
    public List<POItem>? POItems { get; init; }

    [JsonPropertyName("selectedPO")]
    public POItem? SelectedPO { get; init; }

    [JsonPropertyName("allowedFormats")]
    public List<string>? AllowedFormats { get; init; }

    [JsonPropertyName("states")]
    public List<string>? States { get; init; }

    [JsonPropertyName("inputHint")]
    public string? InputHint { get; init; }

    [JsonPropertyName("minSearchLength")]
    public int? MinSearchLength { get; init; }

    [JsonPropertyName("submissionId")]
    public Guid? SubmissionId { get; init; }

    [JsonPropertyName("validationRules")]
    public List<ValidationRuleResult>? ValidationRules { get; init; }

    [JsonPropertyName("passedCount")]
    public int? PassedCount { get; init; }

    [JsonPropertyName("failedCount")]
    public int? FailedCount { get; init; }

    [JsonPropertyName("warningCount")]
    public int? WarningCount { get; init; }
}

public class WorkflowCard
{
    [JsonPropertyName("id")]
    public required string Id { get; init; }

    [JsonPropertyName("title")]
    public required string Title { get; init; }

    [JsonPropertyName("subtitle")]
    public required string Subtitle { get; init; }

    [JsonPropertyName("icon")]
    public required string Icon { get; init; }

    [JsonPropertyName("action")]
    public required string Action { get; init; }
}

public class POItem
{
    [JsonPropertyName("id")]
    public required string Id { get; init; }

    [JsonPropertyName("poNumber")]
    public required string PONumber { get; init; }

    [JsonPropertyName("poDate")]
    public DateTime PODate { get; init; }

    [JsonPropertyName("vendorName")]
    public required string VendorName { get; init; }

    [JsonPropertyName("totalAmount")]
    public decimal TotalAmount { get; init; }

    [JsonPropertyName("remainingBalance")]
    public decimal? RemainingBalance { get; init; }

    [JsonPropertyName("poStatus")]
    public required string POStatus { get; init; }
}
