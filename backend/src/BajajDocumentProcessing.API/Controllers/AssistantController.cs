using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
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
    private readonly ISubmissionNumberService _submissionNumberService;
    private readonly IBackgroundWorkflowQueue _backgroundQueue;

    public AssistantController(
        IApplicationDbContext context,
        ILogger<AssistantController> logger,
        IReferenceDataService referenceData,
        ISubmissionNumberService submissionNumberService,
        IBackgroundWorkflowQueue backgroundQueue)
    {
        _context = context;
        _logger = logger;
        _referenceData = referenceData;
        _submissionNumberService = submissionNumberService;
        _backgroundQueue = backgroundQueue;
    }

    /// <summary>
    /// Process an assistant message and return the next response.
    /// </summary>
    [HttpPost("message")]
    [Authorize(Roles = "Agency,ASM,HQ")]
    public async Task<IActionResult> ProcessMessage(
        [FromBody] AssistantRequest request,
        CancellationToken ct = default)
    {
        var agencyId = await GetAgencyIdAsync(ct);
        var action = request.Action?.ToLowerInvariant();

        // Actions that don't require an agencyId (available to all roles)
        var publicActions = new HashSet<string>
        {
            "greet", "create_request", "view_requests", "pending_approvals",
            "search_state", "list_states", "submit_team_name",
            "search_dealer", "select_dealer", "submit_team_dates",
            "reupload_invoice", "reupload_activity_summary",
            "reupload_cost_summary", "reupload_enquiry_dump",
            "continue_after_cost_summary", "continue_after_teams",
            "save_draft_from_chat",
        };

        if (!publicActions.Contains(action ?? "") && agencyId == null)
            return Forbid();

        try
        {
            var response = action switch
            {
                "greet" => BuildGreeting(),
                "create_request" => BuildCreateRequestPrompt(),
                "view_requests" => BuildViewRequestsPrompt(),
                "pending_approvals" => BuildPendingApprovalsPrompt(),
                "search_po" => await HandleSearchPO(request, agencyId!.Value, ct),
                "select_po" => await HandleSelectPO(request, agencyId!.Value, ct),
                "select_state" => await HandleSelectState(request, agencyId!.Value, ct),
                "search_state" => HandleSearchState(request, ct),
                "list_states" => HandleListAllStates(),
                "invoice_uploaded" => await HandleInvoiceUploaded(request, agencyId!.Value, ct),
                "continue_invoice" => await HandleContinueInvoice(request, agencyId!.Value, ct),
                "reupload_invoice" => HandleReuploadInvoice(),
                "activity_summary_uploaded" => await HandleActivitySummaryUploaded(request, agencyId!.Value, ct),
                "reupload_activity_summary" => HandleReuploadActivitySummary(),
                "continue_after_activity" => await HandleContinueAfterActivity(request, agencyId!.Value, ct),
                "start_team_entry" => await HandleStartTeamEntry(request, agencyId!.Value, ct),
                "submit_team_count" => await HandleSubmitTeamCount(request, agencyId!.Value, ct),
                "submit_team_name" => await HandleSubmitTeamName(request, ct),
                "search_dealer" => await HandleSearchDealer(request, ct),
                "select_dealer" => HandleSelectDealer(request),
                "submit_team_dates" => HandleSubmitTeamDates(request),
                "confirm_team" => await HandleConfirmTeam(request, agencyId!.Value, ct),
                "start_photo_upload" => await HandleStartPhotoUpload(request, agencyId!.Value, ct),
                "photos_uploaded" => await HandlePhotosUploaded(request, agencyId!.Value, ct),
                "replace_photo" => await HandleReplacePhoto(request, agencyId!.Value, ct),
                "add_more_photos" => await HandleAddMorePhotos(request, agencyId!.Value, ct),
                "done_team_photos" => await HandleDoneTeamPhotos(request, agencyId!.Value, ct),
                "cost_summary_uploaded" => await HandleCostSummaryUploaded(request, agencyId!.Value, ct),
                "reupload_cost_summary" => HandleReuploadCostSummary(),
                "continue_after_cost_summary" => HandleContinueAfterCostSummary(request),
                "continue_after_teams" => HandleEnquiryDumpUpload(),
                "enquiry_dump_uploaded" => await HandleEnquiryDumpUploaded(request, agencyId!.Value, ct),
                "reupload_enquiry_dump" => HandleEnquiryDumpUpload(),
                "continue_after_enquiry" => await HandleFinalReview(request, agencyId!.Value, ct),
                "submit_from_chat" => await HandleSubmitFromChat(request, agencyId!.Value, ct),
                "save_draft_from_chat" => HandleSaveDraftFromChat(),
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
            botMessage = $"Invoice analysed. {passCount} of {totalChecks} checks passed.{(failCount > 0 ? $" {failCount} failed." : "")} Review below and continue or re-upload.";

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

            var validationDetailsJson = BuildValidationDetailsJson("proactive", rules);

            if (existingResult != null)
            {
                existingResult.AllValidationsPassed = failCount == 0;
                existingResult.RuleResultsJson = ruleResultsJson;
                existingResult.ValidationDetailsJson = validationDetailsJson;
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
                    ValidationDetailsJson = validationDetailsJson,
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
            FileName = invoice.FileName,
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
        string? costSummaryDocumentId = null;

        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (string.IsNullOrEmpty(documentId) && payload.TryGetProperty("documentId", out var docProp))
                    documentId = docProp.GetString();
                if (payload.TryGetProperty("submissionId", out var subProp) && Guid.TryParse(subProp.GetString(), out var sid))
                    submissionIdFromPayload = sid;
                if (payload.TryGetProperty("costSummaryDocumentId", out var csdProp))
                    costSummaryDocumentId = csdProp.GetString();
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

        // Fetch cost summary for the same package (for AS_DAYS_MATCH_COST_SUMMARY check)
        // Prefer exact document ID to avoid picking up stale previous uploads
        Domain.Entities.CostSummary? costSummary = null;
        if (!string.IsNullOrEmpty(costSummaryDocumentId) && Guid.TryParse(costSummaryDocumentId, out var csDocId))
        {
            costSummary = await _context.CostSummaries
                .Where(c => c.Id == csDocId && !c.IsDeleted)
                .FirstOrDefaultAsync(ct);
        }
        if (costSummary == null)
        {
            costSummary = await _context.CostSummaries
                .Where(c => c.PackageId == actSummary.PackageId && !c.IsDeleted)
                .OrderByDescending(c => c.CreatedAt)
                .FirstOrDefaultAsync(ct);
        }

        // Run validation rules
        var rules = RunActivitySummaryValidationRules(actSummary, costSummary?.NumberOfDays);

        int passCount = rules.Count(r => r.Passed && !r.IsWarning);
        int failCount = rules.Count(r => !r.Passed && !r.IsWarning);
        int warnCount = rules.Count(r => r.IsWarning);

        string botMessage = failCount == 0 && warnCount == 0
            ? $"Activity Summary analysed. All {rules.Count} checks passed!"
            : $"Activity Summary analysed. {passCount} of {rules.Count} checks passed.{(failCount > 0 ? $" {failCount} failed." : "")} Review below and continue or re-upload.";

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

            var validationDetailsJson = BuildValidationDetailsJson("proactive", rules);

            var existing = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (existing != null)
            {
                existing.AllValidationsPassed = failCount == 0;
                existing.RuleResultsJson = ruleResultsJson;
                existing.ValidationDetailsJson = validationDetailsJson;
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
                    ValidationDetailsJson = validationDetailsJson,
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
            PayloadJson = JsonSerializer.Serialize(new
            {
                submissionId = (submissionIdFromPayload ?? actSummary.PackageId).ToString(),
                costSummaryDocumentId,
            }),
        };
    }

    private List<ValidationRuleResult> RunActivitySummaryValidationRules(Domain.Entities.ActivitySummary actSummary, int? costSummaryDays = null)
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

        // AS_DAYS_MATCH_COST_SUMMARY: TotalDays must match CostSummary.NumberOfDays
        int? actDays = actSummary.TotalDays;
        if (actDays == null || costSummaryDays == null)
        {
            rules.Add(new ValidationRuleResult
            {
                RuleCode = "AS_DAYS_MATCH_COST_SUMMARY",
                Type = "Required",
                Passed = false,
                IsWarning = true,
                Label = "Days Match with Cost Summary",
                ExtractedValue = actDays.HasValue ? actDays.ToString() : null,
                Message = actDays == null
                    ? "Activity Summary days not extracted — cannot compare with Cost Summary"
                    : "Cost Summary days not available — cannot compare",
            });
        }
        else
        {
            bool match = actDays.Value == costSummaryDays.Value;
            rules.Add(new ValidationRuleResult
            {
                RuleCode = "AS_DAYS_MATCH_COST_SUMMARY",
                Type = "Required",
                Passed = match,
                IsWarning = false,
                Label = "Days Match with Cost Summary",
                ExtractedValue = $"Activity: {actDays.Value} days | Cost Summary: {costSummaryDays.Value} days",
                Message = match ? null : $"Activity Summary days ({actDays.Value}) does not match Cost Summary days ({costSummaryDays.Value})",
            });
        }

        return rules;
    }


    private async Task<AssistantResponse> HandleContinueAfterActivity(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        // Kick off team entry — read team count from cost summary
        var submissionId = ExtractSubmissionId(request);

        // Try to get the exact cost summary document ID from payload (set by HandleCostSummaryUploaded)
        Guid? costSummaryDocId = null;
        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var pl = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (pl.TryGetProperty("costSummaryDocumentId", out var csdProp) && Guid.TryParse(csdProp.GetString(), out var csd))
                    costSummaryDocId = csd;
            }
            catch { }
        }

        int? totalTeams = null;
        if (submissionId.HasValue)
        {
            // Prefer exact document ID to avoid picking up stale previous uploads
            if (costSummaryDocId.HasValue)
            {
                var cs = await _context.CostSummaries
                    .Where(c => c.Id == costSummaryDocId.Value && !c.IsDeleted)
                    .Select(c => new { c.NumberOfTeams, c.ExtractedDataJson })
                    .FirstOrDefaultAsync(ct);

                // Read from the DB column first (populated by DocumentService during extraction)
                if (cs?.NumberOfTeams > 0)
                {
                    totalTeams = cs.NumberOfTeams;
                }
                else if (!string.IsNullOrEmpty(cs?.ExtractedDataJson))
                {
                    // Fallback: parse ExtractedDataJson — note JsonElement.TryGetProperty is case-sensitive
                    // so try both PascalCase and camelCase keys
                    try
                    {
                        var json = JsonSerializer.Deserialize<JsonElement>(cs.ExtractedDataJson);
                        if ((json.TryGetProperty("NumberOfTeams", out var nt) || json.TryGetProperty("numberOfTeams", out nt))
                            && nt.ValueKind == JsonValueKind.Number)
                        {
                            var extracted = nt.GetInt32();
                            if (extracted > 0) totalTeams = extracted;
                        }
                    }
                    catch { }
                }
            }
            else
            {
                // Fallback: latest cost summary for the package
                var cs = await _context.CostSummaries
                    .Where(c => c.PackageId == submissionId.Value && !c.IsDeleted)
                    .OrderByDescending(c => c.CreatedAt)
                    .Select(c => new { c.NumberOfTeams, c.ExtractedDataJson })
                    .FirstOrDefaultAsync(ct);

                if (cs?.NumberOfTeams > 0)
                {
                    totalTeams = cs.NumberOfTeams;
                }
                else if (!string.IsNullOrEmpty(cs?.ExtractedDataJson))
                {
                    try
                    {
                        var json = JsonSerializer.Deserialize<JsonElement>(cs.ExtractedDataJson);
                        if ((json.TryGetProperty("NumberOfTeams", out var nt) || json.TryGetProperty("numberOfTeams", out nt))
                            && nt.ValueKind == JsonValueKind.Number)
                        {
                            var extracted = nt.GetInt32();
                            if (extracted > 0) totalTeams = extracted;
                        }
                    }
                    catch { }
                }
            }
        }

        if (!totalTeams.HasValue || totalTeams.Value <= 0)
        {
            // Cannot determine team count — ask user to enter it manually
            var askPayload = System.Text.Json.JsonSerializer.Serialize(new
            {
                submissionId = submissionId?.ToString(),
            });
            return new AssistantResponse
            {
                Type = "team_count_input",
                Message = "Activity Summary accepted. Could not determine team count from Cost Summary. How many teams were there?",
                PayloadJson = askPayload,
                SubmissionId = submissionId,
            };
        }

        var payloadJson = System.Text.Json.JsonSerializer.Serialize(new
        {
            submissionId = submissionId?.ToString(),
            totalTeams = totalTeams.Value,
            currentTeam = 1,
        });

        return new AssistantResponse
        {
            Type = "team_name_input",
            Message = $"Activity Summary accepted. Your cost summary mentions {totalTeams.Value} team{(totalTeams.Value > 1 ? "s" : "")}. Let's add details for each team.\n\nStarting with Team 1 of {totalTeams.Value}.\n\nPlease enter Team 1 name:",
            TeamContext = new TeamContextDto { CurrentTeam = 1, TotalTeams = totalTeams.Value },
            PayloadJson = payloadJson,
            SubmissionId = submissionId,
        };
    }

    private async Task<AssistantResponse> HandleStartTeamEntry(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        return await HandleContinueAfterActivity(request, agencyId, ct);
    }

    private async Task<AssistantResponse> HandleSubmitTeamCount(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        if (!int.TryParse(request.Message?.Trim(), out var totalTeams) || totalTeams <= 0)
        {
            return new AssistantResponse
            {
                Type = "team_count_input",
                Message = "Please enter a valid number of teams (e.g. 2):",
                PayloadJson = request.PayloadJson,
            };
        }

        var submissionId = ExtractSubmissionId(request);
        var payloadJson = System.Text.Json.JsonSerializer.Serialize(new
        {
            submissionId = submissionId?.ToString(),
            totalTeams,
            currentTeam = 1,
        });

        return new AssistantResponse
        {
            Type = "team_name_input",
            Message = $"Starting with Team 1 of {totalTeams}.\n\nPlease enter Team 1 name:",
            TeamContext = new TeamContextDto { CurrentTeam = 1, TotalTeams = totalTeams },
            PayloadJson = payloadJson,
            SubmissionId = submissionId,
        };
    }

    private async Task<AssistantResponse> HandleSubmitTeamName(AssistantRequest request, CancellationToken ct)
    {
        // Read team name from message, carry forward payload
        var teamName = request.Message?.Trim();
        if (string.IsNullOrWhiteSpace(teamName))
        {
            return new AssistantResponse
            {
                Type = "team_name_input",
                Message = "Team name cannot be empty. Please enter a valid team name:",
            };
        }

        // Parse existing payload and add teamName
        var ctx = ParseTeamPayload(request.PayloadJson);
        ctx["teamName"] = teamName;

        var currentTeam = ctx.TryGetValue("currentTeam", out var ct2) ? (ct2 is JsonElement ct2e ? ct2e.GetInt32() : Convert.ToInt32(ct2)) : 1;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;

        // Load all dealers for the selected state upfront — no typing required
        string? activityState = null;
        var submissionId = ExtractSubmissionId(request);
        if (submissionId.HasValue)
        {
            activityState = await _context.DocumentPackages
                .Where(p => p.Id == submissionId.Value && !p.IsDeleted)
                .Select(p => p.ActivityState)
                .FirstOrDefaultAsync(ct);
        }

        var dealerQuery = _context.Dealers.Where(d => d.IsActive && !d.IsDeleted);
        if (!string.IsNullOrEmpty(activityState))
            dealerQuery = dealerQuery.Where(d => d.State == activityState);

        var dealers = await dealerQuery
            .OrderBy(d => d.DealerName)
            .Select(d => new DealerItem
            {
                DealerCode = d.DealerCode,
                DealerName = d.DealerName,
                City = d.City ?? "",
                State = d.State,
            })
            .ToListAsync(ct);

        var stateLabel = !string.IsNullOrEmpty(activityState) ? $" in {activityState}" : "";
        var message = dealers.Count > 0
            ? $"Which dealer was Team {teamName} assigned to? Select from the list below{stateLabel}:"
            : $"No dealers found{stateLabel}. Please contact support to add dealers for this state.";

        return new AssistantResponse
        {
            Type = "dealer_list",
            Message = message,
            Dealers = dealers,
            TeamContext = new TeamContextDto { CurrentTeam = currentTeam, TotalTeams = totalTeams },
            PayloadJson = System.Text.Json.JsonSerializer.Serialize(ctx),
        };
    }

    private async Task<AssistantResponse> HandleSearchDealer(
        AssistantRequest request, CancellationToken ct)
    {
        var query = request.Message?.Trim() ?? "";
        if (query.Length < 2)
        {
            return new AssistantResponse
            {
                Type = "dealer_search",
                Message = "Type at least 2 characters to search for a dealer.",
                InputHint = "Type dealer name (min 2 chars)...",
                MinSearchLength = 2,
            };
        }

        // Get the state selected earlier in the chatbot flow
        string? activityState = null;
        var submissionId = ExtractSubmissionId(request);
        if (submissionId.HasValue)
        {
            activityState = await _context.DocumentPackages
                .Where(p => p.Id == submissionId.Value && !p.IsDeleted)
                .Select(p => p.ActivityState)
                .FirstOrDefaultAsync(ct);
        }

        var q = query.ToLower();
        var dealerQuery = _context.Dealers
            .Where(d => d.IsActive && !d.IsDeleted &&
                (d.DealerName.ToLower().Contains(q) ||
                 d.DealerCode.ToLower().Contains(q) ||
                 (d.City != null && d.City.ToLower().Contains(q))));

        // Filter by state if we have one from the chatbot flow
        if (!string.IsNullOrEmpty(activityState))
            dealerQuery = dealerQuery.Where(d => d.State == activityState);

        var dealers = await dealerQuery
            .Take(10)
            .Select(d => new DealerItem
            {
                DealerCode = d.DealerCode,
                DealerName = d.DealerName,
                City = d.City ?? "",
                State = d.State,
            })
            .ToListAsync(ct);

        var stateLabel = !string.IsNullOrEmpty(activityState) ? $" in {activityState}" : "";
        return new AssistantResponse
        {
            Type = "dealer_search_results",
            Message = dealers.Count > 0
                ? $"Found {dealers.Count} dealer(s) matching \"{query}\"{stateLabel}. Select one:"
                : $"No dealers found matching \"{query}\"{stateLabel}. Try a different name.",
            Dealers = dealers,
            InputHint = "Type dealer name (min 2 chars)...",
            MinSearchLength = 2,
            PayloadJson = request.PayloadJson,
        };
    }

    private static AssistantResponse HandleSelectDealer(AssistantRequest request)
    {
        // Dealer info comes in PayloadJson under "selectedDealer"
        var ctx = ParseTeamPayload(request.PayloadJson);

        string? dealerName = null, dealerCode = null, city = null, state = null;
        if (ctx.TryGetValue("selectedDealer", out var sd) && sd is System.Text.Json.JsonElement sdElem)
        {
            dealerCode = sdElem.TryGetProperty("dealerCode", out var dc) ? dc.GetString() : null;
            dealerName = sdElem.TryGetProperty("dealerName", out var dn) ? dn.GetString() : null;
            city = sdElem.TryGetProperty("city", out var c) ? c.GetString() : null;
            state = sdElem.TryGetProperty("state", out var st) ? st.GetString() : null;
        }

        var teamName = ctx.TryGetValue("teamName", out var tn) ? tn?.ToString() : "the team";
        var currentTeam = ctx.TryGetValue("currentTeam", out var ct2) ? (ct2 is JsonElement ct2e ? ct2e.GetInt32() : Convert.ToInt32(ct2)) : 1;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;

        return new AssistantResponse
        {
            Type = "date_picker_start",
            Message = $"Dealer: {dealerName}, {city}\n\nActivity period for Team {teamName}?\nPick start date:",
            TeamContext = new TeamContextDto { CurrentTeam = currentTeam, TotalTeams = totalTeams },
            PayloadJson = System.Text.Json.JsonSerializer.Serialize(ctx),
        };
    }

    private static AssistantResponse HandleSubmitTeamDates(AssistantRequest request)
    {
        // Expects payload: startDate + endDate (ISO strings)
        var ctx = ParseTeamPayload(request.PayloadJson);

        DateTime? startDate = null, endDate = null;
        if (ctx.TryGetValue("startDate", out var sd) && sd != null)
        {
            var sdStr = sd is JsonElement sde ? sde.GetString() : sd.ToString();
            if (DateTime.TryParse(sdStr, out var sdt)) startDate = sdt;
        }
        if (ctx.TryGetValue("endDate", out var ed) && ed != null)
        {
            var edStr = ed is JsonElement ede ? ede.GetString() : ed.ToString();
            if (DateTime.TryParse(edStr, out var edt)) endDate = edt;
        }

        if (!startDate.HasValue || !endDate.HasValue)
        {
            return new AssistantResponse
            {
                Type = "date_picker_start",
                Message = "Could not parse dates. Please pick the start date again:",
                PayloadJson = request.PayloadJson,
            };
        }

        if (endDate.Value < startDate.Value)
        {
            return new AssistantResponse
            {
                Type = "date_picker_start",
                Message = "End date cannot be before start date. Please pick the start date again:",
                PayloadJson = request.PayloadJson,
            };
        }

        int workingDays = CalculateWorkingDays(startDate.Value, endDate.Value);
        var teamName = ctx.TryGetValue("teamName", out var tn) ? tn?.ToString() : "the team";
        var currentTeam = ctx.TryGetValue("currentTeam", out var ct2) ? (ct2 is JsonElement ct2e ? ct2e.GetInt32() : Convert.ToInt32(ct2)) : 1;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;

        ctx["workingDays"] = workingDays;

        return new AssistantResponse
        {
            Type = "team_dates_confirm",
            Message = $"Start: {startDate.Value:dd-MMM-yyyy} | End: {endDate.Value:dd-MMM-yyyy}\nWorking days (auto-calculated): {workingDays}",
            TeamContext = new TeamContextDto { CurrentTeam = currentTeam, TotalTeams = totalTeams },
            PayloadJson = System.Text.Json.JsonSerializer.Serialize(ctx),
        };
    }

    private async Task<AssistantResponse> HandleConfirmTeam(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var ctx = ParseTeamPayload(request.PayloadJson);

        var submissionId = ctx.TryGetValue("submissionId", out var sid) && sid != null
            ? (Guid.TryParse(sid is JsonElement side ? side.GetString() : sid.ToString(), out var g) ? g : (Guid?)null)
            : null;
        var teamName = ctx.TryGetValue("teamName", out var tn) ? tn?.ToString() : null;
        var currentTeam = ctx.TryGetValue("currentTeam", out var ct2) ? (ct2 is JsonElement ct2e ? ct2e.GetInt32() : Convert.ToInt32(ct2)) : 1;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;

        // Extract dealer info
        string? dealerName = null, dealerCode = null, city = null, state = null;
        if (ctx.TryGetValue("selectedDealer", out var sd) && sd is System.Text.Json.JsonElement sdElem)
        {
            dealerCode = sdElem.TryGetProperty("dealerCode", out var dc) ? dc.GetString() : null;
            dealerName = sdElem.TryGetProperty("dealerName", out var dn) ? dn.GetString() : null;
            city = sdElem.TryGetProperty("city", out var c) ? c.GetString() : null;
            state = sdElem.TryGetProperty("state", out var st) ? st.GetString() : null;
        }

        // Extract dates
        DateTime? startDate = null, endDate = null;
        if (ctx.TryGetValue("startDate", out var sdv) && sdv != null)
        {
            var sdvStr = sdv is JsonElement sdve ? sdve.GetString() : sdv.ToString();
            if (DateTime.TryParse(sdvStr, out var sdt)) startDate = sdt;
        }
        if (ctx.TryGetValue("endDate", out var edv) && edv != null)
        {
            var edvStr = edv is JsonElement edve ? edve.GetString() : edv.ToString();
            if (DateTime.TryParse(edvStr, out var edt)) endDate = edt;
        }

        int workingDays = ctx.TryGetValue("workingDays", out var wd)
            ? (wd is JsonElement wde ? wde.GetInt32() : Convert.ToInt32(wd))
            : 0;

        // Save to Teams table
        if (submissionId.HasValue)
        {
            try
            {
                var team = new Domain.Entities.Teams
                {
                    Id = Guid.NewGuid(),
                    PackageId = submissionId.Value,
                    CampaignName = teamName,
                    TeamCode = dealerCode,
                    TeamNumber = currentTeam,
                    StartDate = startDate,
                    EndDate = endDate,
                    WorkingDays = workingDays,
                    DealershipName = dealerName,
                    DealershipAddress = city,
                    State = state,
                    VersionNumber = 1,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                };
                _context.Teams.Add(team);
                await _context.SaveChangesAsync(ct);
                _logger.LogInformation("Team {TeamNum} saved for package {PackageId}", currentTeam, submissionId.Value);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to save team {TeamNum} for package {PackageId}", currentTeam, submissionId.Value);
            }
        }

        // If more teams remain, loop to next team
        if (currentTeam < totalTeams)
        {
            int nextTeam = currentTeam + 1;
            var nextPayload = System.Text.Json.JsonSerializer.Serialize(new
            {
                submissionId = submissionId?.ToString(),
                totalTeams,
                currentTeam = nextTeam,
            });

            return new AssistantResponse
            {
                Type = "team_name_input",
                Message = $"Team {teamName} details saved!\n\nNow let's add details for Team {nextTeam} of {totalTeams}.\n\nPlease enter Team {nextTeam} name:",
                TeamContext = new TeamContextDto { CurrentTeam = nextTeam, TotalTeams = totalTeams },
                PayloadJson = nextPayload,
                SubmissionId = submissionId,
            };
        }

        // All teams done — start Phase 9: photo upload loop
        var photoPayload = System.Text.Json.JsonSerializer.Serialize(new
        {
            submissionId = submissionId?.ToString(),
            totalTeams,
            currentPhotoTeam = 1,
        });
        return new AssistantResponse
        {
            Type = "photo_upload",
            Message = await BuildPhotoUploadMessage(submissionId, 1, totalTeams, ct),
            TeamContext = new TeamContextDto { CurrentTeam = 1, TotalTeams = totalTeams },
            PayloadJson = photoPayload,
            SubmissionId = submissionId,
        };
    }

    // ── Phase 9: Photo Proofs Upload ─────────────────────────────────────

    private async Task<string> BuildPhotoUploadMessage(Guid? submissionId, int currentPhotoTeam, int totalTeams, CancellationToken ct)
    {
        string teamName = $"Team {currentPhotoTeam}";
        if (submissionId.HasValue)
        {
            var team = await _context.Teams
                .Where(t => t.PackageId == submissionId.Value && t.TeamNumber == currentPhotoTeam && !t.IsDeleted)
                .Select(t => new { t.CampaignName })
                .FirstOrDefaultAsync(ct);
            if (!string.IsNullOrWhiteSpace(team?.CampaignName))
                teamName = team.CampaignName;
        }
        return $"Now upload photo proofs for {teamName} (Team {currentPhotoTeam} of {totalTeams}).\nMinimum 3 photos, maximum 10 photos.";
    }

    private async Task<AssistantResponse> HandleStartPhotoUpload(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var ctx = ParseTeamPayload(request.PayloadJson);
        var submissionId = ctx.TryGetValue("submissionId", out var sid) && sid != null
            ? (Guid.TryParse(sid is JsonElement side ? side.GetString() : sid.ToString(), out var g) ? g : (Guid?)null)
            : null;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;
        var currentPhotoTeam = ctx.TryGetValue("currentPhotoTeam", out var cpt) ? (cpt is JsonElement cpte ? cpte.GetInt32() : Convert.ToInt32(cpt)) : 1;

        return new AssistantResponse
        {
            Type = "photo_upload",
            Message = await BuildPhotoUploadMessage(submissionId, currentPhotoTeam, totalTeams, ct),
            TeamContext = new TeamContextDto { CurrentTeam = currentPhotoTeam, TotalTeams = totalTeams },
            PayloadJson = request.PayloadJson,
            SubmissionId = submissionId,
        };
    }

    private async Task<AssistantResponse> HandlePhotosUploaded(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var ctx = ParseTeamPayload(request.PayloadJson);
        var submissionId = ctx.TryGetValue("submissionId", out var sid) && sid != null
            ? (Guid.TryParse(sid is JsonElement side ? side.GetString() : sid.ToString(), out var g) ? g : (Guid?)null)
            : null;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;
        var currentPhotoTeam = ctx.TryGetValue("currentPhotoTeam", out var cpt) ? (cpt is JsonElement cpte ? cpte.GetInt32() : Convert.ToInt32(cpt)) : 1;

        // Parse photo IDs from message (comma-separated) or payload
        var photoIds = new List<Guid>();
        if (!string.IsNullOrEmpty(request.Message))
        {
            foreach (var part in request.Message.Split(',', StringSplitOptions.RemoveEmptyEntries))
                if (Guid.TryParse(part.Trim(), out var pid)) photoIds.Add(pid);
        }

        if (photoIds.Count == 0)
            return new AssistantResponse { Type = "error", Message = "No photos received. Please try uploading again.", PayloadJson = request.PayloadJson };

        // Enforce max 10
        if (photoIds.Count > 10)
            return new AssistantResponse
            {
                Type = "photo_upload",
                Message = "Maximum 10 photos per team. Please select up to 10 photos.",
                TeamContext = new TeamContextDto { CurrentTeam = currentPhotoTeam, TotalTeams = totalTeams },
                PayloadJson = request.PayloadJson,
                SubmissionId = submissionId,
            };

        // Find the team record
        Guid? teamId = null;
        string teamName = $"Team {currentPhotoTeam}";
        if (submissionId.HasValue)
        {
            var team = await _context.Teams
                .Where(t => t.PackageId == submissionId.Value && t.TeamNumber == currentPhotoTeam && !t.IsDeleted)
                .Select(t => new { t.Id, t.CampaignName })
                .FirstOrDefaultAsync(ct);
            if (team != null)
            {
                teamId = team.Id;
                if (!string.IsNullOrWhiteSpace(team.CampaignName)) teamName = team.CampaignName;
            }
        }

        // Get existing photo count for this team (for replace/add-more scenarios)
        int existingCount = 0;
        if (teamId.HasValue)
            existingCount = await _context.TeamPhotos.CountAsync(p => p.TeamId == teamId.Value && !p.IsDeleted, ct);

        if (existingCount + photoIds.Count > 10)
            return new AssistantResponse
            {
                Type = "photo_validation_results",
                Message = $"Maximum 10 photos per team. You already have {existingCount} photo(s). Remove a photo first or proceed with current set.",
                TeamContext = new TeamContextDto { CurrentTeam = currentPhotoTeam, TotalTeams = totalTeams, TeamName = teamName },
                PayloadJson = request.PayloadJson,
                SubmissionId = submissionId,
            };

        // Run AI vision validation on each photo and save to TeamPhotos + ValidationResults
        var photoResults = new List<PhotoValidationResult>();
        int displayOrder = existingCount + 1;

        foreach (var photoId in photoIds)
        {
            var photo = await _context.TeamPhotos
                .FirstOrDefaultAsync(p => p.Id == photoId && !p.IsDeleted, ct);

            if (photo == null) continue;

            // Link to team if not already linked
            if (teamId.HasValue && photo.TeamId == Guid.Empty)
            {
                photo.TeamId = teamId.Value;
                photo.PackageId = submissionId ?? photo.PackageId;
                photo.DisplayOrder = displayOrder++;
                photo.UpdatedAt = DateTime.UtcNow;
            }

            // Run vision validation rules
            var rules = RunPhotoValidationRules(photo);
            int passCount = rules.Count(r => r.Passed);
            int failCount = rules.Count(r => !r.Passed);
            bool allPassed = failCount == 0;

            photo.IsFlaggedForReview = !allPassed;
            photo.UpdatedAt = DateTime.UtcNow;

            // Persist validation result
            try
            {
                var ruleJson = JsonSerializer.Serialize(rules.Select(r => new
                {
                    ruleCode = r.RuleCode, type = r.Type, passed = r.Passed,
                    isWarning = r.IsWarning, label = r.Label,
                    extractedValue = r.ExtractedValue, message = r.Message,
                }));

                var existing = await _context.ValidationResults
                    .FirstOrDefaultAsync(v => v.DocumentId == photoId, ct);

                var validationDetailsJson = BuildValidationDetailsJson("proactive", rules);

                if (existing != null)
                {
                    existing.AllValidationsPassed = allPassed;
                    existing.RuleResultsJson = ruleJson;
                    existing.ValidationDetailsJson = validationDetailsJson;
                    existing.FailureReason = allPassed ? null : string.Join("; ", rules.Where(r => !r.Passed).Select(r => r.Message ?? r.Label));
                    existing.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    _context.ValidationResults.Add(new Domain.Entities.ValidationResult
                    {
                        Id = Guid.NewGuid(),
                        DocumentType = DocumentType.TeamPhoto,
                        DocumentId = photoId,
                        AllValidationsPassed = allPassed,
                        RuleResultsJson = ruleJson,
                        ValidationDetailsJson = validationDetailsJson,
                        FailureReason = allPassed ? null : string.Join("; ", rules.Where(r => !r.Passed).Select(r => r.Message ?? r.Label)),
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow,
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to persist photo validation for {PhotoId}", photoId);
            }

            photoResults.Add(new PhotoValidationResult
            {
                PhotoId = photoId.ToString(),
                DisplayOrder = photo.DisplayOrder,
                FileName = photo.FileName,
                Rules = rules,
                AllPassed = allPassed,
            });
        }

        await _context.SaveChangesAsync(ct);

        // Get total photo count for this team now
        int totalPhotos = teamId.HasValue
            ? await _context.TeamPhotos.CountAsync(p => p.TeamId == teamId.Value && !p.IsDeleted, ct)
            : photoResults.Count;

        int fullyPassed = photoResults.Count(p => p.AllPassed);
        int withIssues = photoResults.Count(p => !p.AllPassed);

        string summary = $"{totalPhotos} photo(s) uploaded for {teamName}.\n";
        if (withIssues > 0)
            summary += $"{fullyPassed} of {photoResults.Count} passed. {withIssues} failed checks.";
        else
            summary += $"All {fullyPassed} passed AI analysis.";

        var newPayload = System.Text.Json.JsonSerializer.Serialize(new
        {
            submissionId = submissionId?.ToString(),
            totalTeams,
            currentPhotoTeam,
            totalPhotos,
        });

        return new AssistantResponse
        {
            Type = "photo_validation_results",
            Message = summary,
            TeamContext = new TeamContextDto { CurrentTeam = currentPhotoTeam, TotalTeams = totalTeams, TeamName = teamName },
            PhotoResults = photoResults,
            PayloadJson = newPayload,
            SubmissionId = submissionId,
        };
    }

    private async Task<AssistantResponse> HandleReplacePhoto(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var ctx = ParseTeamPayload(request.PayloadJson);
        var submissionId = ctx.TryGetValue("submissionId", out var sid) && sid != null
            ? (Guid.TryParse(sid is JsonElement side ? side.GetString() : sid.ToString(), out var g) ? g : (Guid?)null)
            : null;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;
        var currentPhotoTeam = ctx.TryGetValue("currentPhotoTeam", out var cpt) ? (cpt is JsonElement cpte ? cpte.GetInt32() : Convert.ToInt32(cpt)) : 1;

        // Expects message = "photoNumber,newPhotoId"
        var parts = request.Message?.Split(',') ?? Array.Empty<string>();
        if (parts.Length < 2 || !int.TryParse(parts[0].Trim(), out var photoNumber) || !Guid.TryParse(parts[1].Trim(), out var newPhotoId))
        {
            return new AssistantResponse
            {
                Type = "photo_replace_prompt",
                Message = "Which photo number would you like to replace? (Enter the number shown in the grid)",
                PayloadJson = request.PayloadJson,
                SubmissionId = submissionId,
            };
        }

        // Find team
        Guid? teamId = null;
        if (submissionId.HasValue)
        {
            var team = await _context.Teams
                .Where(t => t.PackageId == submissionId.Value && t.TeamNumber == currentPhotoTeam && !t.IsDeleted)
                .Select(t => new { t.Id })
                .FirstOrDefaultAsync(ct);
            teamId = team?.Id;
        }

        // Soft-delete old photo at that display order
        if (teamId.HasValue)
        {
            var oldPhoto = await _context.TeamPhotos
                .FirstOrDefaultAsync(p => p.TeamId == teamId.Value && p.DisplayOrder == photoNumber && !p.IsDeleted, ct);
            if (oldPhoto != null)
            {
                oldPhoto.IsDeleted = true;
                oldPhoto.UpdatedAt = DateTime.UtcNow;
            }
        }

        // Link new photo and re-run validation
        var newPhoto = await _context.TeamPhotos.FirstOrDefaultAsync(p => p.Id == newPhotoId && !p.IsDeleted, ct);
        if (newPhoto != null && teamId.HasValue)
        {
            newPhoto.TeamId = teamId.Value;
            newPhoto.PackageId = submissionId ?? newPhoto.PackageId;
            newPhoto.DisplayOrder = photoNumber;
            newPhoto.UpdatedAt = DateTime.UtcNow;

            var rules = RunPhotoValidationRules(newPhoto);
            newPhoto.IsFlaggedForReview = rules.Any(r => !r.Passed);

            var ruleJson = JsonSerializer.Serialize(rules.Select(r => new
            {
                ruleCode = r.RuleCode, type = r.Type, passed = r.Passed,
                isWarning = r.IsWarning, label = r.Label,
                extractedValue = r.ExtractedValue, message = r.Message,
            }));
            var existingVr = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.DocumentType == DocumentType.TeamPhoto && v.DocumentId == newPhotoId, ct);

            var photoValidationDetailsJson = BuildValidationDetailsJson("proactive", rules);

            if (existingVr != null)
            {
                existingVr.AllValidationsPassed = !newPhoto.IsFlaggedForReview;
                existingVr.RuleResultsJson = ruleJson;
                existingVr.ValidationDetailsJson = photoValidationDetailsJson;
                existingVr.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                _context.ValidationResults.Add(new Domain.Entities.ValidationResult
                {
                    Id = Guid.NewGuid(),
                    DocumentType = DocumentType.TeamPhoto,
                    DocumentId = newPhotoId,
                    AllValidationsPassed = !newPhoto.IsFlaggedForReview,
                    RuleResultsJson = ruleJson,
                    ValidationDetailsJson = photoValidationDetailsJson,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
        }
        await _context.SaveChangesAsync(ct);

        // Build photo validation results directly from all team photos (avoids double-count in HandlePhotosUploaded)
        var photoResults = new List<PhotoValidationResult>();
        if (teamId.HasValue)
        {
            var allPhotos = await _context.TeamPhotos
                .Where(p => p.TeamId == teamId.Value && !p.IsDeleted)
                .OrderBy(p => p.DisplayOrder)
                .ToListAsync(ct);

            foreach (var photo in allPhotos)
            {
                var rules = RunPhotoValidationRules(photo);
                bool allPassed = rules.All(r => r.Passed);
                photoResults.Add(new PhotoValidationResult
                {
                    PhotoId = photo.Id.ToString(),
                    DisplayOrder = photo.DisplayOrder,
                    FileName = photo.FileName,
                    Rules = rules,
                    AllPassed = allPassed,
                });
            }
        }

        int totalPhotos = photoResults.Count;
        int fullyPassed = photoResults.Count(p => p.AllPassed);
        int withIssues = photoResults.Count(p => !p.AllPassed);
        string summary = $"{totalPhotos} photo(s) for Team {currentPhotoTeam}. Photo {photoNumber} replaced.\n";
        if (withIssues > 0)
            summary += $"{fullyPassed} of {totalPhotos} passed. {withIssues} failed checks.";
        else
            summary += $"All {fullyPassed} passed AI analysis.";

        var newPayload = System.Text.Json.JsonSerializer.Serialize(new
        {
            submissionId = submissionId?.ToString(),
            totalTeams,
            currentPhotoTeam,
            totalPhotos,
        });

        return new AssistantResponse
        {
            Type = "photo_validation_results",
            Message = summary,
            TeamContext = new TeamContextDto { CurrentTeam = currentPhotoTeam, TotalTeams = totalTeams, TeamName = $"Team {currentPhotoTeam}" },
            PhotoResults = photoResults,
            PayloadJson = newPayload,
            SubmissionId = submissionId,
        };
    }

    private async Task<AssistantResponse> HandleAddMorePhotos(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var ctx = ParseTeamPayload(request.PayloadJson);
        var submissionId = ctx.TryGetValue("submissionId", out var sid) && sid != null
            ? (Guid.TryParse(sid is JsonElement side ? side.GetString() : sid.ToString(), out var g) ? g : (Guid?)null)
            : null;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;
        var currentPhotoTeam = ctx.TryGetValue("currentPhotoTeam", out var cpt) ? (cpt is JsonElement cpte ? cpte.GetInt32() : Convert.ToInt32(cpt)) : 1;
        var totalPhotos = ctx.TryGetValue("totalPhotos", out var tp) ? (tp is JsonElement tpe ? tpe.GetInt32() : Convert.ToInt32(tp)) : 0;

        return new AssistantResponse
        {
            Type = "photo_upload",
            Message = $"You have {totalPhotos} photo(s) so far. Upload more (max 10 total):",
            TeamContext = new TeamContextDto { CurrentTeam = currentPhotoTeam, TotalTeams = totalTeams },
            PayloadJson = request.PayloadJson,
            SubmissionId = submissionId,
        };
    }

    private async Task<AssistantResponse> HandleDoneTeamPhotos(
        AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        var ctx = ParseTeamPayload(request.PayloadJson);
        var submissionId = ctx.TryGetValue("submissionId", out var sid) && sid != null
            ? (Guid.TryParse(sid is JsonElement side ? side.GetString() : sid.ToString(), out var g) ? g : (Guid?)null)
            : null;
        var totalTeams = ctx.TryGetValue("totalTeams", out var tt) ? (tt is JsonElement tte ? tte.GetInt32() : Convert.ToInt32(tt)) : 1;
        var currentPhotoTeam = ctx.TryGetValue("currentPhotoTeam", out var cpt) ? (cpt is JsonElement cpte ? cpte.GetInt32() : Convert.ToInt32(cpt)) : 1;

        // Enforce minimum 3 photos
        int photoCount = 0;
        if (submissionId.HasValue)
        {
            var team = await _context.Teams
                .Where(t => t.PackageId == submissionId.Value && t.TeamNumber == currentPhotoTeam && !t.IsDeleted)
                .Select(t => new { t.Id })
                .FirstOrDefaultAsync(ct);
            if (team != null)
                photoCount = await _context.TeamPhotos.CountAsync(p => p.TeamId == team.Id && !p.IsDeleted, ct);
        }

        if (photoCount < 3)
        {
            return new AssistantResponse
            {
                Type = "photo_validation_results",
                Message = $"Minimum 3 photos required per team. Please upload at least {3 - photoCount} more photo(s).",
                TeamContext = new TeamContextDto { CurrentTeam = currentPhotoTeam, TotalTeams = totalTeams, TeamName = $"Team {currentPhotoTeam}" },
                PayloadJson = request.PayloadJson,
                SubmissionId = submissionId,
            };
        }

        // Move to next team's photos or show final summary
        if (currentPhotoTeam < totalTeams)
        {
            int nextPhotoTeam = currentPhotoTeam + 1;
            var nextPayload = System.Text.Json.JsonSerializer.Serialize(new
            {
                submissionId = submissionId?.ToString(),
                totalTeams,
                currentPhotoTeam = nextPhotoTeam,
            });
            return new AssistantResponse
            {
                Type = "photo_upload",
                Message = await BuildPhotoUploadMessage(submissionId, nextPhotoTeam, totalTeams, ct),
                TeamContext = new TeamContextDto { CurrentTeam = nextPhotoTeam, TotalTeams = totalTeams },
                PayloadJson = nextPayload,
                SubmissionId = submissionId,
            };
        }

        // All teams done — build final summary
        return await BuildFinalTeamSummary(submissionId, totalTeams, ct);
    }

    private async Task<AssistantResponse> BuildFinalTeamSummary(Guid? submissionId, int totalTeams, CancellationToken ct)
    {
        var teamSummaries = new List<TeamSummaryItem>();
        if (submissionId.HasValue)
        {
            var teams = await _context.Teams
                .Where(t => t.PackageId == submissionId.Value && !t.IsDeleted)
                .OrderBy(t => t.TeamNumber)
                .ToListAsync(ct);

            foreach (var team in teams)
            {
                var photoCount = await _context.TeamPhotos.CountAsync(p => p.TeamId == team.Id && !p.IsDeleted, ct);
                var passedPhotos = await _context.TeamPhotos
                    .Where(p => p.TeamId == team.Id && !p.IsDeleted && !p.IsFlaggedForReview)
                    .CountAsync(ct);

                teamSummaries.Add(new TeamSummaryItem
                {
                    TeamNumber = team.TeamNumber ?? 0,
                    TeamName = team.CampaignName ?? $"Team {team.TeamNumber}",
                    DealerName = team.DealershipName ?? "",
                    City = team.DealershipAddress ?? "",
                    State = team.State ?? "",
                    StartDate = team.StartDate?.ToString("dd-MMM-yyyy") ?? "",
                    EndDate = team.EndDate?.ToString("dd-MMM-yyyy") ?? "",
                    WorkingDays = team.WorkingDays ?? 0,
                    PhotoCount = photoCount,
                    PhotosPassed = passedPhotos,
                });
            }
        }

        return new AssistantResponse
        {
            Type = "team_summary",
            Message = $"All {totalTeams} team(s) and photo proofs submitted successfully!\n\nHere's a summary of all teams:",
            TeamSummaries = teamSummaries,
            SubmissionId = submissionId,
            PayloadJson = System.Text.Json.JsonSerializer.Serialize(new { submissionId = submissionId?.ToString() }),
        };
    }

    // ── Phase 10: Enquiry Dump Upload ─────────────────────────────────────

    private static AssistantResponse HandleEnquiryDumpUpload()
    {
        return new AssistantResponse
        {
            Type = "enquiry_dump_upload",
            Message = "Please upload Enquiry Dump Document.",
            AllowedFormats = new List<string> { "XLSX", "CSV", "PDF" },
        };
    }

    private async Task<AssistantResponse> HandleEnquiryDumpUploaded(
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
            return new AssistantResponse { Type = "error", Message = "Enquiry Dump upload confirmation missing. Please try uploading again." };

        _logger.LogInformation("=== ENQUIRY DUMP VALIDATION === DocumentId: {DocId}", docId);

        var enquiryDoc = await _context.EnquiryDocuments
            .FirstOrDefaultAsync(e => e.Id == docId && !e.IsDeleted, ct);

        if (enquiryDoc == null)
            return new AssistantResponse { Type = "error", Message = "Enquiry Dump document not found. Please try uploading again." };

        // Wait for background extraction to complete (up to 60s)
        if (string.IsNullOrEmpty(enquiryDoc.ExtractedDataJson))
        {
            _logger.LogInformation("Waiting for enquiry dump extraction to complete for {DocId}", docId);
            for (int i = 0; i < 30; i++)
            {
                await Task.Delay(2000, ct);
                var refreshed = await _context.EnquiryDocuments
                    .AsNoTracking()
                    .FirstOrDefaultAsync(e => e.Id == docId && !e.IsDeleted, ct);
                if (!string.IsNullOrEmpty(refreshed?.ExtractedDataJson))
                {
                    enquiryDoc = refreshed;
                    break;
                }
            }
        }

        // Parse extracted records
        List<Application.DTOs.Documents.EnquiryRecord> records = new();
        if (!string.IsNullOrEmpty(enquiryDoc.ExtractedDataJson))
        {
            try
            {
                var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var data = JsonSerializer.Deserialize<Application.DTOs.Documents.EnquiryDumpData>(enquiryDoc.ExtractedDataJson, opts);
                records = data?.Records ?? new();
            }
            catch { }
        }

        int totalRecords = records.Count;
        int missingPhone = records.Count(r => string.IsNullOrWhiteSpace(r.CustomerNumber));

        // Run 9 validation rules — ≥80% threshold per field
        var rules = RunEnquiryDumpValidationRules(records);

        int passCount = rules.Count(r => r.Passed);
        int failCount = rules.Count(r => !r.Passed);

        string botMessage = $"ClaimsIQ Enquiry Dump processed:\n• {totalRecords} enquiry records found\n• {missingPhone} records with missing Customer Phone";

        // Persist to ValidationResults
        try
        {
            var ruleResultsJson = JsonSerializer.Serialize(rules.Select(r => new
            {
                ruleCode = r.RuleCode, type = r.Type, passed = r.Passed,
                isWarning = r.IsWarning, label = r.Label,
                extractedValue = r.ExtractedValue, message = r.Message,
            }));

            var enquiryValidationDetailsJson = BuildValidationDetailsJson("proactive", rules);

            var existing = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (existing != null)
            {
                existing.AllValidationsPassed = failCount == 0;
                existing.RuleResultsJson = ruleResultsJson;
                existing.ValidationDetailsJson = enquiryValidationDetailsJson;
                existing.FailureReason = failCount > 0 ? string.Join("; ", rules.Where(r => !r.Passed).Select(r => r.Message ?? r.Label)) : null;
                existing.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                _context.ValidationResults.Add(new Domain.Entities.ValidationResult
                {
                    Id = Guid.NewGuid(),
                    DocumentType = DocumentType.EnquiryDocument,
                    DocumentId = docId,
                    AllValidationsPassed = failCount == 0,
                    RuleResultsJson = ruleResultsJson,
                    ValidationDetailsJson = enquiryValidationDetailsJson,
                    FailureReason = failCount > 0 ? string.Join("; ", rules.Where(r => !r.Passed).Select(r => r.Message ?? r.Label)) : null,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                });
            }
            await _context.SaveChangesAsync(ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to persist enquiry dump validation for {DocId}", docId);
        }

        // Read back from DB
        List<ValidationRuleResult> responseRules = rules;
        try
        {
            var saved = await _context.ValidationResults.AsNoTracking()
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);
            if (saved?.RuleResultsJson != null)
            {
                var dbRules = JsonSerializer.Deserialize<List<ValidationRuleResult>>(
                    saved.RuleResultsJson, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                if (dbRules != null && dbRules.Count > 0)
                {
                    responseRules = dbRules;
                    passCount = responseRules.Count(r => r.Passed);
                    failCount = responseRules.Count(r => !r.Passed);
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to read back enquiry dump validation from DB for {DocId}", docId);
        }

        return new AssistantResponse
        {
            Type = "enquiry_dump_validation",
            Message = botMessage,
            ValidationRules = responseRules,
            PassedCount = passCount,
            FailedCount = failCount,
            WarningCount = 0,
            TotalRecords = totalRecords,
            MissingPhoneCount = missingPhone,
            SubmissionId = submissionIdFromPayload ?? enquiryDoc.PackageId,
        };
    }

    private static List<ValidationRuleResult> RunEnquiryDumpValidationRules(
        List<Application.DTOs.Documents.EnquiryRecord> records)
    {
        var rules = new List<ValidationRuleResult>();
        if (records.Count == 0)
        {
            // No records — all fail
            var fields = new[] {
                ("EQ_CUSTOMER_PHONE", "Customer Phone"),
                ("EQ_STATE", "State"),
                ("EQ_DATE", "Date"),
                ("EQ_DEALER_CODE", "Dealer Code"),
                ("EQ_DEALER_NAME", "Dealer Name"),
                ("EQ_DISTRICT", "District"),
                ("EQ_PINCODE", "Pincode"),
                ("EQ_CUSTOMER_NAME", "Customer Name"),
                ("EQ_TEST_RIDE", "Test Ride"),
            };
            foreach (var (code, label) in fields)
                rules.Add(new ValidationRuleResult { RuleCode = code, Type = "Required", Passed = false, IsWarning = false, Label = label, Message = "No records found" });
            return rules;
        }

        int total = records.Count;
        double threshold = 0.8;

        int phonePresent = records.Count(r => !string.IsNullOrWhiteSpace(r.CustomerNumber));
        int statePresent = records.Count(r => !string.IsNullOrWhiteSpace(r.State));
        int datePresent = records.Count(r => r.Date.HasValue);
        int dealerCodePresent = records.Count(r => !string.IsNullOrWhiteSpace(r.DealerCode));
        int dealerNamePresent = records.Count(r => !string.IsNullOrWhiteSpace(r.DealerName));
        int districtPresent = records.Count(r => !string.IsNullOrWhiteSpace(r.District));
        int pincodePresent = records.Count(r => !string.IsNullOrWhiteSpace(r.Pincode));
        int customerNamePresent = records.Count(r => !string.IsNullOrWhiteSpace(r.CustomerName));
        int testRidePresent = records.Count(r => !string.IsNullOrWhiteSpace(r.TestRideTaken));

        (string code, string label, int count)[] checks = {
            ("EQ_CUSTOMER_PHONE", "Customer Phone", phonePresent),
            ("EQ_STATE", "State", statePresent),
            ("EQ_DATE", "Date", datePresent),
            ("EQ_DEALER_CODE", "Dealer Code", dealerCodePresent),
            ("EQ_DEALER_NAME", "Dealer Name", dealerNamePresent),
            ("EQ_DISTRICT", "District", districtPresent),
            ("EQ_PINCODE", "Pincode", pincodePresent),
            ("EQ_CUSTOMER_NAME", "Customer Name", customerNamePresent),
            ("EQ_TEST_RIDE", "Test Ride", testRidePresent),
        };

        foreach (var (code, label, count) in checks)
        {
            double pct = (double)count / total;
            bool passed = pct >= threshold;
            rules.Add(new ValidationRuleResult
            {
                RuleCode = code,
                Type = "Required",
                Passed = passed,
                IsWarning = false,
                Label = label,
                ExtractedValue = $"{count}/{total} records ({pct:P0})",
                Message = passed ? null : $"Only {pct:P0} of records have {label} (min 80% required)",
            });
        }

        return rules;
    }

    private static AssistantResponse HandleContinueAfterEnquiry()
    {
        return new AssistantResponse
        {
            Type = "text",
            Message = "✅ Enquiry Dump accepted. Your submission is complete. Thank you!",
        };
    }

    private async Task<AssistantResponse> HandleFinalReview(AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        Guid? submissionId = null;
        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var p = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (p.TryGetProperty("submissionId", out var sp) && Guid.TryParse(sp.GetString(), out var sid))
                    submissionId = sid;
            }
            catch { }
        }

        if (submissionId == null)
            return new AssistantResponse { Type = "error", Message = "Submission ID missing for final review." };

        var package = await _context.DocumentPackages
            .AsNoTracking()
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.CostSummary)
            .Include(p => p.ActivitySummary)
            .Include(p => p.EnquiryDocument)
            .Include(p => p.Teams.Where(t => !t.IsDeleted))
            .AsSplitQuery()
            .FirstOrDefaultAsync(p => p.Id == submissionId.Value && !p.IsDeleted, ct);

        if (package == null)
            return new AssistantResponse { Type = "error", Message = "Submission not found." };

        // Load selected PO via SelectedPOId (chatbot flow — no uploaded PO document)
        Domain.Entities.PO? selectedPo = null;
        if (package.SelectedPOId.HasValue)
            selectedPo = await _context.POs.AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == package.SelectedPOId.Value && !p.IsDeleted, ct);

        // Helper: get validation status for a document
        async Task<bool?> GetValidationPassed(Guid docId)
        {
            var vr = await _context.ValidationResults.AsNoTracking()
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);
            return vr?.AllValidationsPassed;
        }

        // PO
        var poSection = selectedPo == null ? null : new FinalReviewSection
        {
            Title = "Purchase Order",
            Icon = "description",
            Passed = true,
            Fields = new List<FinalReviewField>
            {
                new() { Label = "PO Number", Value = selectedPo.PONumber ?? "—" },
                new() { Label = "PO Date", Value = selectedPo.PODate?.ToString("dd MMM yyyy") ?? "—" },
                new() { Label = "Vendor", Value = selectedPo.VendorName ?? "—" },
                new() { Label = "Amount", Value = selectedPo.TotalAmount.HasValue ? $"₹{selectedPo.TotalAmount:N2}" : "—" },
            }
        };

        // Invoice (latest)
        var latestInvoice = package.Invoices.OrderByDescending(i => i.CreatedAt).FirstOrDefault();
        bool? invPassed = latestInvoice != null ? await GetValidationPassed(latestInvoice.Id) : null;
        var invoiceSection = latestInvoice == null ? null : new FinalReviewSection
        {
            Title = "Invoice",
            Icon = "receipt_long",
            Passed = invPassed ?? true,
            Fields = new List<FinalReviewField>
            {
                new() { Label = "Invoice No", Value = latestInvoice.InvoiceNumber ?? "—" },
                new() { Label = "Invoice Date", Value = latestInvoice.InvoiceDate?.ToString("dd MMM yyyy") ?? "—" },
                new() { Label = "Amount", Value = latestInvoice.TotalAmount.HasValue ? $"₹{latestInvoice.TotalAmount:N2}" : "—" },
                new() { Label = "GST No", Value = latestInvoice.GSTNumber ?? "—" },
            }
        };

        // Cost Summary
        bool? csPassed = package.CostSummary != null ? await GetValidationPassed(package.CostSummary.Id) : null;
        var csSection = package.CostSummary == null ? null : new FinalReviewSection
        {
            Title = "Cost Summary",
            Icon = "table_chart",
            Passed = csPassed ?? true,
            Fields = new List<FinalReviewField>
            {
                new() { Label = "State", Value = package.CostSummary.PlaceOfSupply ?? package.ActivityState ?? "—" },
                new() { Label = "No. of Teams", Value = package.CostSummary.NumberOfTeams?.ToString() ?? "—" },
                new() { Label = "No. of Days", Value = package.CostSummary.NumberOfDays?.ToString() ?? "—" },
                new() { Label = "Total Cost", Value = package.CostSummary.TotalCost.HasValue ? $"₹{package.CostSummary.TotalCost:N2}" : "—" },
            }
        };

        // Activity Summary
        bool? actPassed = package.ActivitySummary != null ? await GetValidationPassed(package.ActivitySummary.Id) : null;
        var actSection = package.ActivitySummary == null ? null : new FinalReviewSection
        {
            Title = "Activity Summary",
            Icon = "event_note",
            Passed = actPassed ?? true,
            Fields = new List<FinalReviewField>
            {
                new() { Label = "Dealer", Value = package.ActivitySummary.DealerName ?? "—" },
                new() { Label = "Total Days", Value = package.ActivitySummary.TotalDays?.ToString() ?? "—" },
                new() { Label = "Working Days", Value = package.ActivitySummary.TotalWorkingDays?.ToString() ?? "—" },
            }
        };

        // Teams
        var teamFields = package.Teams.OrderBy(t => t.TeamNumber).Select(t => new FinalReviewField
        {
            Label = $"Team {t.TeamNumber}",
            Value = $"{t.CampaignName ?? "—"} | {t.DealershipName ?? "—"} | {t.StartDate?.ToString("dd MMM") ?? "?"} – {t.EndDate?.ToString("dd MMM yyyy") ?? "?"}",
        }).ToList();
        var teamsSection = new FinalReviewSection
        {
            Title = "Teams",
            Icon = "groups",
            Passed = true,
            Fields = teamFields
        };

        // Enquiry Dump
        bool? enqPassed = package.EnquiryDocument != null ? await GetValidationPassed(package.EnquiryDocument.Id) : null;
        int enqTotal = 0;
        int enqMissingPhone = 0;
        if (package.EnquiryDocument?.ExtractedDataJson != null)
        {
            try
            {
                var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var enqData = JsonSerializer.Deserialize<Application.DTOs.Documents.EnquiryDumpData>(package.EnquiryDocument.ExtractedDataJson, opts);
                enqTotal = enqData?.TotalRecords ?? enqData?.Records?.Count ?? 0;
                enqMissingPhone = enqData?.Records?.Count(r => string.IsNullOrWhiteSpace(r.CustomerNumber)) ?? 0;
            }
            catch { }
        }
        var enqSection = package.EnquiryDocument == null ? null : new FinalReviewSection
        {
            Title = "Enquiry Dump",
            Icon = "people_alt",
            Passed = enqPassed ?? true,
            Fields = new List<FinalReviewField>
            {
                new() { Label = "Total Records", Value = enqTotal > 0 ? enqTotal.ToString() : "—" },
                new() { Label = "Missing Phone", Value = enqMissingPhone.ToString() },
            }
        };

        var sections = new List<FinalReviewSection>();
        if (poSection != null) sections.Add(poSection);
        if (invoiceSection != null) sections.Add(invoiceSection);
        if (csSection != null) sections.Add(csSection);
        if (actSection != null) sections.Add(actSection);
        sections.Add(teamsSection);
        if (enqSection != null) sections.Add(enqSection);

        return new AssistantResponse
        {
            Type = "final_review",
            Message = "Please review your submission details below.",
            SubmissionId = submissionId,
            ReviewSections = sections,
        };
    }

    private async Task<AssistantResponse> HandleSubmitFromChat(AssistantRequest request, Guid agencyId, CancellationToken ct)
    {
        Guid? submissionId = null;
        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var p = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (p.TryGetProperty("submissionId", out var sp) && Guid.TryParse(sp.GetString(), out var sid))
                    submissionId = sid;
            }
            catch { }
        }

        if (submissionId == null)
            return new AssistantResponse { Type = "error", Message = "Submission ID missing." };

        var userId = GetUserIdSync();
        if (userId == null)
            return new AssistantResponse { Type = "error", Message = "User not found." };

        var package = await _context.DocumentPackages
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.Teams.Where(t => !t.IsDeleted))
                .ThenInclude(t => t.Photos.Where(ph => !ph.IsDeleted))
            .Include(p => p.CostSummary)
            .Include(p => p.ActivitySummary)
            .Include(p => p.EnquiryDocument)
            .AsSplitQuery()
            .FirstOrDefaultAsync(p => p.Id == submissionId.Value && !p.IsDeleted, ct);

        if (package == null)
            return new AssistantResponse { Type = "error", Message = "Submission not found." };

        if (package.SubmittedByUserId != userId.Value)
            return new AssistantResponse { Type = "error", Message = "You are not authorised to submit this package." };

        if (package.State != Domain.Enums.PackageState.Draft && package.State != Domain.Enums.PackageState.Uploaded)
            return new AssistantResponse { Type = "error", Message = $"Package is already in {package.State} state." };

        // Validate required docs — PO is selected via SelectedPOId in chatbot flow
        if (!package.SelectedPOId.HasValue) return new AssistantResponse { Type = "error", Message = "PO is required." };
        if (!package.Invoices.Any()) return new AssistantResponse { Type = "error", Message = "Invoice document is required." };
        if (package.CostSummary == null) return new AssistantResponse { Type = "error", Message = "Cost Summary is required." };
        if (package.ActivitySummary == null) return new AssistantResponse { Type = "error", Message = "Activity Summary is required." };
        if (package.EnquiryDocument == null) return new AssistantResponse { Type = "error", Message = "Enquiry Dump is required." };
        if (!package.Teams.Any(t => t.Photos.Count >= 3)) return new AssistantResponse { Type = "error", Message = "At least one team with 3+ photos is required." };

        // Generate submission number
        var submissionNumber = await _submissionNumberService.GenerateAsync(ct);
        package.SubmissionNumber = submissionNumber;

        // Do NOT set state to PendingCH here — let WorkflowOrchestrator handle state transition,
        // CH assignment, Teams notification, email, and SignalR push.
        package.CurrentStep = 10;
        package.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation("Package {PackageId} submitted from chat by user {UserId}. SubmissionNumber: {SubNum} — triggering orchestrator",
            submissionId, userId, submissionNumber);

        // Queue workflow via background processor (proper scoped execution, avoids disposed context issues)
        await _backgroundQueue.QueueWorkflowAsync(package.Id);

        return new AssistantResponse
        {
            Type = "submit_success",
            Message = "Your submission has been submitted successfully!",
            SubmissionId = submissionId,
        };
    }

    private static AssistantResponse HandleSaveDraftFromChat()
    {
        return new AssistantResponse
        {
            Type = "draft_saved",
            Message = "Your submission has been saved as a draft.",
        };
    }

    private static List<ValidationRuleResult> RunPhotoValidationRules(Domain.Entities.TeamPhotos photo)    {
        var rules = new List<ValidationRuleResult>();

        // Prefer dedicated columns (populated by DocumentService after extraction)
        // Fall back to parsing ExtractedMetadataJson if columns are null

        // --- Date ---
        bool dateVisible = photo.DateVisible ?? photo.PhotoTimestamp.HasValue;
        string? dateVal = photo.PhotoTimestamp?.ToString("dd-MMM-yyyy HH:mm") ?? photo.PhotoDateOverlay;

        // --- GPS (Lat/Long columns) ---
        bool gpsVisible = photo.Latitude.HasValue && photo.Longitude.HasValue;
        string? gpsVal = gpsVisible ? $"{photo.Latitude:F4}, {photo.Longitude:F4}" : null;

        // --- AI detection columns ---
        bool blueTshirt = photo.BlueTshirtPresent ?? false;
        bool threeWheeler = photo.ThreeWheelerPresent ?? false;

        // Fallback: parse ExtractedMetadataJson if dedicated columns are still null
        if (photo.DateVisible == null && photo.BlueTshirtPresent == null && !string.IsNullOrEmpty(photo.ExtractedMetadataJson))
        {
            try
            {
                var json = JsonSerializer.Deserialize<JsonElement>(photo.ExtractedMetadataJson,
                    new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                if (!dateVisible)
                {
                    if (json.TryGetProperty("timestamp", out var ts) && ts.ValueKind != JsonValueKind.Null)
                    { dateVal = ts.GetString(); dateVisible = !string.IsNullOrEmpty(dateVal); }
                    if (json.TryGetProperty("photoDateFromOverlay", out var ov) && ov.ValueKind != JsonValueKind.Null)
                    { dateVal ??= ov.GetString(); dateVisible = dateVisible || !string.IsNullOrEmpty(dateVal); }
                }

                if (!gpsVisible)
                {
                    if (json.TryGetProperty("latitude", out var lat) && json.TryGetProperty("longitude", out var lon)
                        && lat.ValueKind == JsonValueKind.Number && lon.ValueKind == JsonValueKind.Number)
                    { gpsVisible = true; gpsVal = $"{lat.GetDouble():F4}, {lon.GetDouble():F4}"; }
                }

                if (!blueTshirt)
                {
                    if (json.TryGetProperty("hasBlueTshirtPerson", out var bt)) blueTshirt = bt.GetBoolean();
                    else if (json.TryGetProperty("blueTshirtPresent", out var bt2)) blueTshirt = bt2.GetBoolean();
                }

                if (!threeWheeler)
                {
                    if (json.TryGetProperty("has3WVehicle", out var tw)) threeWheeler = tw.GetBoolean();
                    else if (json.TryGetProperty("threeWheelerPresent", out var tw2)) threeWheeler = tw2.GetBoolean();
                }
            }
            catch { }
        }

        rules.Add(new ValidationRuleResult
        {
            RuleCode = "PHOTO_DATE_VISIBLE",
            Type = "Required",
            Passed = dateVisible,
            IsWarning = false,
            Label = "Date",
            ExtractedValue = dateVal,
            Message = dateVisible ? null : "Date not visible in photo",
        });

        rules.Add(new ValidationRuleResult
        {
            RuleCode = "PHOTO_GPS_VISIBLE",
            Type = "Required",
            Passed = gpsVisible,
            IsWarning = false,
            Label = "GPS",
            ExtractedValue = gpsVal,
            Message = gpsVisible ? null : "GPS coordinates not detected",
        });

        rules.Add(new ValidationRuleResult
        {
            RuleCode = "PHOTO_BLUE_TSHIRT",
            Type = "Required",
            Passed = blueTshirt,
            IsWarning = false,
            Label = "Blue T-shirt",
            ExtractedValue = blueTshirt ? "Present ✓" : null,
            Message = blueTshirt ? null : "Person with blue T-shirt not detected",
        });

        rules.Add(new ValidationRuleResult
        {
            RuleCode = "PHOTO_3W_VEHICLE",
            Type = "Required",
            Passed = threeWheeler,
            IsWarning = false,
            Label = "3W Vehicle",
            ExtractedValue = threeWheeler ? "Present ✓" : null,
            Message = threeWheeler ? null : "3-wheel vehicle not detected",
        });

        return rules;
    }

    /// <summary>
    /// Calculates working days between two dates, excluding Sundays and Indian public holidays.
    /// </summary>
    private static int CalculateWorkingDays(DateTime start, DateTime end)
    {
        // Indian public holidays (hardcoded for 2025 and 2026)
        var holidays = new HashSet<DateTime>
        {
            // 2025
            new(2025, 1, 26), // Republic Day
            new(2025, 3, 14), // Holi
            new(2025, 4, 14), // Dr. Ambedkar Jayanti / Baisakhi
            new(2025, 4, 18), // Good Friday
            new(2025, 5, 12), // Buddha Purnima
            new(2025, 8, 15), // Independence Day
            new(2025, 8, 27), // Janmashtami
            new(2025, 10, 2), // Gandhi Jayanti
            new(2025, 10, 2), // Dussehra (same day)
            new(2025, 10, 20), // Diwali
            new(2025, 11, 5), // Guru Nanak Jayanti
            new(2025, 12, 25), // Christmas
            // 2026
            new(2026, 1, 26), // Republic Day
            new(2026, 3, 3),  // Holi
            new(2026, 4, 3),  // Good Friday
            new(2026, 4, 14), // Dr. Ambedkar Jayanti
            new(2026, 5, 31), // Buddha Purnima
            new(2026, 8, 15), // Independence Day
            new(2026, 8, 16), // Janmashtami
            new(2026, 10, 2), // Gandhi Jayanti
            new(2026, 10, 20), // Dussehra
            new(2026, 11, 8), // Diwali
            new(2026, 11, 24), // Guru Nanak Jayanti
            new(2026, 12, 25), // Christmas
        };

        int count = 0;
        for (var d = start.Date; d <= end.Date; d = d.AddDays(1))
        {
            if (d.DayOfWeek != DayOfWeek.Sunday && !holidays.Contains(d))
                count++;
        }
        return count;
    }

    private static Dictionary<string, object?> ParseTeamPayload(string? payloadJson)
    {
        if (string.IsNullOrEmpty(payloadJson))
            return new Dictionary<string, object?>();
        try
        {
            var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var elem = JsonSerializer.Deserialize<JsonElement>(payloadJson, opts);
            var dict = new Dictionary<string, object?>();
            foreach (var prop in elem.EnumerateObject())
            {
                dict[prop.Name] = prop.Value.ValueKind switch
                {
                    JsonValueKind.String => (object?)prop.Value.GetString(),
                    JsonValueKind.Number => prop.Value.TryGetInt32(out var i) ? i : prop.Value.GetDecimal(),
                    JsonValueKind.True => true,
                    JsonValueKind.False => false,
                    JsonValueKind.Null => null,
                    _ => prop.Value, // keep as JsonElement for objects/arrays
                };
            }
            return dict;
        }
        catch
        {
            return new Dictionary<string, object?>();
        }
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

        // Wait for background extraction to complete (up to 60s)
        if (string.IsNullOrEmpty(costSummary.ExtractedDataJson))
        {
            _logger.LogInformation("Waiting for cost summary extraction to complete for {DocId}", docId);
            for (int i = 0; i < 30; i++)
            {
                await Task.Delay(2000, ct);
                var refreshed = await _context.CostSummaries
                    .AsNoTracking()
                    .FirstOrDefaultAsync(c => c.Id == docId && !c.IsDeleted, ct);
                if (!string.IsNullOrEmpty(refreshed?.ExtractedDataJson))
                {
                    costSummary = refreshed;
                    break;
                }
            }
        }

        _logger.LogInformation(
            "=== CS VALIDATION STATE === DocId: {DocId} | ExtractedDataJson null: {JsonNull} | PlaceOfSupply: {Pos} | Days: {Days} | Activations: {Act} | Teams: {Teams} | TotalCost: {Cost} | ElementWiseCosts null: {EwcNull}",
            docId,
            string.IsNullOrEmpty(costSummary.ExtractedDataJson),
            costSummary.PlaceOfSupply,
            costSummary.NumberOfDays,
            costSummary.NumberOfActivations,
            costSummary.NumberOfTeams,
            costSummary.TotalCost,
            string.IsNullOrEmpty(costSummary.ElementWiseCostsJson));

        // Fetch latest invoice for the same package (for CS_TOTAL_VS_INVOICE check)
        var latestInvoice = await _context.Invoices
            .Where(i => i.PackageId == costSummary.PackageId && !i.IsDeleted)
            .OrderByDescending(i => i.CreatedAt)
            .FirstOrDefaultAsync(ct);

        var rules = RunCostSummaryValidationRules(costSummary, latestInvoice?.TotalAmount);

        int passCount = rules.Count(r => r.Passed && !r.IsWarning);
        int failCount = rules.Count(r => !r.Passed && !r.IsWarning);
        int warnCount = rules.Count(r => r.IsWarning);

        string botMessage = failCount == 0 && warnCount == 0
            ? $"Cost Summary analysed. All {rules.Count} checks passed!"
            : $"Cost Summary analysed. {passCount} of {rules.Count} checks passed.{(failCount > 0 ? $" {failCount} failed." : "")} Review below and continue or re-upload.";

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

            var costValidationDetailsJson = BuildValidationDetailsJson("proactive", rules);

            var existing = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.DocumentId == docId, ct);

            if (existing != null)
            {
                existing.AllValidationsPassed = failCount == 0;
                existing.RuleResultsJson = ruleResultsJson;
                existing.ValidationDetailsJson = costValidationDetailsJson;
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
                    ValidationDetailsJson = costValidationDetailsJson,
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
            PayloadJson = JsonSerializer.Serialize(new
            {
                submissionId = (submissionIdFromPayload ?? costSummary.PackageId).ToString(),
                costSummaryDocumentId = docId.ToString(),
            }),
        };
    }

    private List<ValidationRuleResult> RunCostSummaryValidationRules(Domain.Entities.CostSummary costSummary, decimal? invoiceAmount = null)
    {
        var rules = new List<ValidationRuleResult>();

        string? placeOfSupply = costSummary.PlaceOfSupply;
        int? numberOfDays = costSummary.NumberOfDays;
        int? numberOfActivations = costSummary.NumberOfActivations;
        int? numberOfTeams = costSummary.NumberOfTeams;
        string? elementWiseCosts = costSummary.ElementWiseCostsJson;
        string? elementWiseQuantity = costSummary.ElementWiseQuantityJson;
        decimal? totalCost = costSummary.TotalCost;

        // Fallback: parse from ExtractedDataJson if dedicated columns are empty
        bool needsFallback = string.IsNullOrWhiteSpace(placeOfSupply)
            || numberOfDays == null
            || numberOfActivations == null
            || numberOfTeams == null
            || string.IsNullOrWhiteSpace(elementWiseCosts)
            || string.IsNullOrWhiteSpace(elementWiseQuantity)
            || totalCost == null;

        if (needsFallback && !string.IsNullOrEmpty(costSummary.ExtractedDataJson))
        {
            try
            {
                var opts = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var json = JsonSerializer.Deserialize<JsonElement>(costSummary.ExtractedDataJson, opts);

                if (string.IsNullOrWhiteSpace(placeOfSupply))
                {
                    if (json.TryGetProperty("placeOfSupply", out var pos) && pos.ValueKind != JsonValueKind.Null)
                        placeOfSupply = pos.GetString();
                    if (string.IsNullOrWhiteSpace(placeOfSupply))
                        if (json.TryGetProperty("state", out var st) && st.ValueKind != JsonValueKind.Null)
                            placeOfSupply = st.GetString();
                }

                if (numberOfDays == null)
                    if (json.TryGetProperty("numberOfDays", out var nd) && nd.ValueKind == JsonValueKind.Number)
                        try { numberOfDays = nd.GetInt32(); } catch { }

                if (numberOfActivations == null)
                    if (json.TryGetProperty("numberOfActivations", out var na) && na.ValueKind == JsonValueKind.Number)
                        try { numberOfActivations = na.GetInt32(); } catch { }

                if (numberOfTeams == null)
                    if (json.TryGetProperty("numberOfTeams", out var nt) && nt.ValueKind == JsonValueKind.Number)
                        try { numberOfTeams = nt.GetInt32(); } catch { }

                if (totalCost == null)
                    if (json.TryGetProperty("totalCost", out var tc) && tc.ValueKind == JsonValueKind.Number)
                        try { totalCost = tc.GetDecimal(); } catch { }

                // CostBreakdowns array → build elementWiseCosts and elementWiseQuantity
                if ((string.IsNullOrWhiteSpace(elementWiseCosts) || string.IsNullOrWhiteSpace(elementWiseQuantity))
                    && json.TryGetProperty("costBreakdowns", out var breakdowns)
                    && breakdowns.ValueKind == JsonValueKind.Array
                    && breakdowns.GetArrayLength() > 0)
                {
                    var costsArr = new System.Text.StringBuilder("[");
                    var qtyArr = new System.Text.StringBuilder("[");
                    bool first = true;
                    foreach (var b in breakdowns.EnumerateArray())
                    {
                        if (!first) { costsArr.Append(','); qtyArr.Append(','); }
                        first = false;
                        var cat = b.TryGetProperty("category", out var c) ? c.GetString() : "";
                        var elem = b.TryGetProperty("elementName", out var e) ? e.GetString() : cat;
                        var amt = b.TryGetProperty("amount", out var a) && a.ValueKind == JsonValueKind.Number ? a.GetDecimal() : 0;
                        var qty = b.TryGetProperty("quantity", out var q) && q.ValueKind == JsonValueKind.Number ? q.GetInt32() : 0;
                        var unit = b.TryGetProperty("unit", out var u) ? u.GetString() : "";
                        costsArr.Append($"{{\"category\":\"{cat}\",\"elementName\":\"{elem}\",\"amount\":{amt}}}");
                        qtyArr.Append($"{{\"category\":\"{cat}\",\"quantity\":{qty},\"unit\":\"{unit}\"}}");
                    }
                    costsArr.Append(']');
                    qtyArr.Append(']');
                    if (string.IsNullOrWhiteSpace(elementWiseCosts)) elementWiseCosts = costsArr.ToString();
                    if (string.IsNullOrWhiteSpace(elementWiseQuantity)) elementWiseQuantity = qtyArr.ToString();
                }
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
            ExtractedValue = null,
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
            ExtractedValue = null,
            Message = qtyPresent ? null : "Element-wise quantity breakdown not detected",
        });

        // CS_TOTAL_VS_INVOICE: Total Cost <= Invoice Amount
        if (totalCost == null || invoiceAmount == null)
        {
            rules.Add(new ValidationRuleResult
            {
                RuleCode = "CS_TOTAL_VS_INVOICE",
                Type = "Required",
                Passed = false,
                IsWarning = true,
                Label = "Total Cost vs Invoice Amount",
                ExtractedValue = totalCost.HasValue ? $"₹{totalCost.Value:F2}" : null,
                Message = totalCost == null
                    ? "Cost Summary total amount not detected — cannot compare with invoice"
                    : "Invoice amount not available — cannot compare",
            });
        }
        else
        {
            bool withinLimit = totalCost.Value <= invoiceAmount.Value;
            decimal diff = totalCost.Value - invoiceAmount.Value;
            rules.Add(new ValidationRuleResult
            {
                RuleCode = "CS_TOTAL_VS_INVOICE",
                Type = "Required",
                Passed = withinLimit,
                IsWarning = false,
                Label = "Total Cost vs Invoice Amount",
                ExtractedValue = $"Cost: ₹{totalCost.Value:F2} | Invoice: ₹{invoiceAmount.Value:F2}",
                Message = withinLimit
                    ? null
                    : $"Cost Summary (₹{totalCost.Value:F2}) exceeds Invoice (₹{invoiceAmount.Value:F2}) by ₹{diff:F2}",
            });
        }

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

        // Preserve costSummaryDocumentId through the payload chain
        string? costSummaryDocumentId = null;
        if (!string.IsNullOrEmpty(request.PayloadJson))
        {
            try
            {
                var pl = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
                if (pl.TryGetProperty("costSummaryDocumentId", out var csdProp))
                    costSummaryDocumentId = csdProp.GetString();
            }
            catch { }
        }

        var payloadJson = JsonSerializer.Serialize(new
        {
            submissionId = submissionId?.ToString(),
            costSummaryDocumentId,
        });

        return new AssistantResponse
        {
            Type = "activity_summary_upload",
            Message = "Cost Summary accepted. Now please upload the Activity Summary document.",
            AllowedFormats = new List<string> { "PDF", "JPG", "PNG", "XLS", "XLSX" },
            SubmissionId = submissionId,
            PayloadJson = payloadJson,
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
    /// Upload team photos. Returns list of photo IDs for use with photos_uploaded action.
    /// </summary>
    [HttpPost("/api/assistant/upload-photos")]
    [Authorize(Roles = "Agency")]
    [RequestSizeLimit(104857600)] // 100 MB total
    public async Task<IActionResult> UploadTeamPhotos(
        [FromForm] List<IFormFile> files,
        [FromForm] string? submissionId,
        [FromForm] int teamNumber = 1,
        CancellationToken ct = default)
    {
        var agencyId = await GetAgencyIdAsync(ct);
        if (agencyId == null) return Forbid();

        if (files == null || files.Count == 0)
            return BadRequest(new { error = "No files provided." });

        if (files.Count > 10)
            return BadRequest(new { error = "Maximum 10 photos per upload." });

        Guid? packageId = Guid.TryParse(submissionId, out var pid) ? pid : null;

        // Resolve user ID
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (!Guid.TryParse(userIdClaim, out var userId))
            return Unauthorized();

        // Find team to get teamId and existing photo count
        Guid? teamId = null;
        if (packageId.HasValue)
        {
            var team = await _context.Teams
                .Where(t => t.PackageId == packageId.Value && t.TeamNumber == teamNumber && !t.IsDeleted)
                .Select(t => new { t.Id })
                .FirstOrDefaultAsync(ct);
            teamId = team?.Id;
        }

        int existingCount = teamId.HasValue
            ? await _context.TeamPhotos.CountAsync(p => p.TeamId == teamId.Value && !p.IsDeleted, ct)
            : 0;

        // Allow +1 overage for single-photo replace operations (the old photo gets soft-deleted after)
        var effectiveLimit = files.Count == 1 ? 11 : 10;
        if (existingCount + files.Count > effectiveLimit)
            return BadRequest(new { error = $"Maximum 10 photos per team. You already have {existingCount}." });

        // Route each photo through DocumentService so blob upload + EXIF/AI extraction runs
        var documentService = HttpContext.RequestServices.GetRequiredService<IDocumentService>();
        var photoIds = new List<string>();
        int displayOrder = existingCount + 1;

        foreach (var file in files)
        {
            var allowed = new[] { ".jpg", ".jpeg", ".png", ".webp" };
            var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (!allowed.Contains(ext)) continue;

            try
            {
                // Upload via DocumentService — saves to TeamPhotos, uploads to blob, triggers background EXIF+AI extraction
                var uploadResult = await documentService.UploadDocumentAsync(
                    file, DocumentType.TeamPhoto, packageId, userId);

                // Link to the correct team and set display order
                var photo = await _context.TeamPhotos.FindAsync(uploadResult.DocumentId);
                if (photo != null)
                {
                    photo.TeamId = teamId ?? Guid.Empty;
                    photo.DisplayOrder = displayOrder++;
                    photo.UpdatedAt = DateTime.UtcNow;
                }

                photoIds.Add(uploadResult.DocumentId.ToString());
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to upload photo {FileName} for team {TeamNumber}", file.FileName, teamNumber);
            }
        }

        await _context.SaveChangesAsync(ct);
        return Ok(new { photoIds });
    }

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
        // Check Invoices first
        var invoice = await _context.Invoices
            .AsNoTracking()
            .Where(i => i.Id == id && !i.IsDeleted)
            .Select(i => new { i.Id, i.ExtractedDataJson, i.ExtractionConfidence, i.InvoiceNumber })
            .FirstOrDefaultAsync(ct);

        if (invoice != null)
        {
            var isExtracted = !string.IsNullOrEmpty(invoice.ExtractedDataJson) || !string.IsNullOrEmpty(invoice.InvoiceNumber);
            return Ok(new { documentId = invoice.Id, status = isExtracted ? "extracted" : "processing", extractionConfidence = invoice.ExtractionConfidence });
        }

        // Check TeamPhotos
        var photo = await _context.TeamPhotos
            .AsNoTracking()
            .Where(p => p.Id == id && !p.IsDeleted)
            .Select(p => new { p.Id, p.ExtractedMetadataJson, p.ExtractionConfidence })
            .FirstOrDefaultAsync(ct);

        if (photo != null)
        {
            var isExtracted = !string.IsNullOrEmpty(photo.ExtractedMetadataJson);
            return Ok(new { documentId = photo.Id, status = isExtracted ? "extracted" : "processing", extractionConfidence = photo.ExtractionConfidence });
        }

        // Check CostSummaries
        var cs = await _context.CostSummaries
            .AsNoTracking()
            .Where(c => c.Id == id && !c.IsDeleted)
            .Select(c => new { c.Id, c.ExtractedDataJson, c.ExtractionConfidence })
            .FirstOrDefaultAsync(ct);

        if (cs != null)
        {
            var isExtracted = !string.IsNullOrEmpty(cs.ExtractedDataJson);
            return Ok(new { documentId = cs.Id, status = isExtracted ? "extracted" : "processing", extractionConfidence = cs.ExtractionConfidence });
        }

        // Check ActivitySummaries
        var act = await _context.ActivitySummaries
            .AsNoTracking()
            .Where(a => a.Id == id && !a.IsDeleted)
            .Select(a => new { a.Id, a.ExtractedDataJson, a.ExtractionConfidence })
            .FirstOrDefaultAsync(ct);

        if (act != null)
        {
            var isExtracted = !string.IsNullOrEmpty(act.ExtractedDataJson);
            return Ok(new { documentId = act.Id, status = isExtracted ? "extracted" : "processing", extractionConfidence = act.ExtractionConfidence });
        }

        // Check EnquiryDocuments
        var enq = await _context.EnquiryDocuments
            .AsNoTracking()
            .Where(e => e.Id == id && !e.IsDeleted)
            .Select(e => new { e.Id, e.ExtractedDataJson })
            .FirstOrDefaultAsync(ct);

        if (enq != null)
        {
            var isExtracted = !string.IsNullOrEmpty(enq.ExtractedDataJson);
            return Ok(new { documentId = enq.Id, status = isExtracted ? "extracted" : "processing" });
        }

        return NotFound(new { status = "not_found" });
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

    private Guid? GetUserIdSync()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : null;
    }

    /// <summary>
    /// Builds a unified ValidationDetailsJson combining source info and rule results.
    /// Used by both proactive (assistant) and reactive (ValidationAgent) flows.
    /// </summary>
    private static string BuildValidationDetailsJson(string source, List<ValidationRuleResult> rules)
    {
        var details = new
        {
            source,
            validatedAt = DateTime.UtcNow.ToString("o"),
            totalRules = rules.Count,
            passed = rules.Count(r => r.Passed && !r.IsWarning),
            failed = rules.Count(r => !r.Passed && !r.IsWarning),
            warnings = rules.Count(r => r.IsWarning),
            rules = rules.Select(r => new
            {
                ruleCode = r.RuleCode,
                type = r.Type,
                passed = r.Passed,
                isWarning = r.IsWarning,
                label = r.Label,
                extractedValue = r.ExtractedValue,
                message = r.Message,
            })
        };

        return JsonSerializer.Serialize(details, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
        });
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

    [JsonPropertyName("dealers")]
    public List<DealerItem>? Dealers { get; init; }

    [JsonPropertyName("teamContext")]
    public TeamContextDto? TeamContext { get; init; }

    [JsonPropertyName("payloadJson")]
    public string? PayloadJson { get; init; }

    [JsonPropertyName("photoResults")]
    public List<PhotoValidationResult>? PhotoResults { get; init; }

    [JsonPropertyName("teamSummaries")]
    public List<TeamSummaryItem>? TeamSummaries { get; init; }

    [JsonPropertyName("totalRecords")]
    public int? TotalRecords { get; init; }

    [JsonPropertyName("missingPhoneCount")]
    public int? MissingPhoneCount { get; init; }

    [JsonPropertyName("reviewSections")]
    public List<FinalReviewSection>? ReviewSections { get; init; }

    [JsonPropertyName("fileName")]
    public string? FileName { get; init; }
}

public class PhotoValidationResult
{
    [JsonPropertyName("photoId")]
    public required string PhotoId { get; init; }

    [JsonPropertyName("displayOrder")]
    public int DisplayOrder { get; init; }

    [JsonPropertyName("fileName")]
    public string FileName { get; init; } = "";

    [JsonPropertyName("rules")]
    public List<ValidationRuleResult> Rules { get; init; } = new();

    [JsonPropertyName("allPassed")]
    public bool AllPassed { get; init; }
}

public class TeamSummaryItem
{
    [JsonPropertyName("teamNumber")]
    public int TeamNumber { get; init; }

    [JsonPropertyName("teamName")]
    public required string TeamName { get; init; }

    [JsonPropertyName("dealerName")]
    public required string DealerName { get; init; }

    [JsonPropertyName("city")]
    public required string City { get; init; }

    [JsonPropertyName("state")]
    public required string State { get; init; }

    [JsonPropertyName("startDate")]
    public required string StartDate { get; init; }

    [JsonPropertyName("endDate")]
    public required string EndDate { get; init; }

    [JsonPropertyName("workingDays")]
    public int WorkingDays { get; init; }

    [JsonPropertyName("photoCount")]
    public int PhotoCount { get; init; }

    [JsonPropertyName("photosPassed")]
    public int PhotosPassed { get; init; }
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

public class DealerItem
{
    [JsonPropertyName("dealerCode")]
    public required string DealerCode { get; init; }

    [JsonPropertyName("dealerName")]
    public required string DealerName { get; init; }

    [JsonPropertyName("city")]
    public required string City { get; init; }

    [JsonPropertyName("state")]
    public required string State { get; init; }
}

public class TeamContextDto
{
    [JsonPropertyName("currentTeam")]
    public int CurrentTeam { get; init; }

    [JsonPropertyName("totalTeams")]
    public int TotalTeams { get; init; }

    [JsonPropertyName("teamName")]
    public string? TeamName { get; init; }
}

public class FinalReviewSection
{
    [JsonPropertyName("title")]
    public required string Title { get; init; }

    [JsonPropertyName("icon")]
    public required string Icon { get; init; }

    [JsonPropertyName("passed")]
    public bool Passed { get; init; }

    [JsonPropertyName("fields")]
    public List<FinalReviewField> Fields { get; init; } = new();
}

public class FinalReviewField
{
    [JsonPropertyName("label")]
    public required string Label { get; init; }

    [JsonPropertyName("value")]
    public required string Value { get; init; }
}
