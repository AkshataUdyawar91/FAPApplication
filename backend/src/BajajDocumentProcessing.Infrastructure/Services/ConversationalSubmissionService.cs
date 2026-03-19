using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Conversation;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// State-machine service that drives the 10-step conversational submission chatbot flow.
/// Each step handler processes a user action and returns a structured bot response.
/// </summary>
public class ConversationalSubmissionService : IConversationalSubmissionService
{
    private readonly IApplicationDbContext _db;
    private readonly IDocumentAgent _documentAgent;
    private readonly IProactiveValidationService _proactiveValidation;
    private readonly ISubmissionNumberService _submissionNumber;
    private readonly ILogger<ConversationalSubmissionService> _logger;

    /// <summary>
    /// Progress percentage per step (0-based index maps to percent).
    /// </summary>
    private static readonly int[] StepProgress = { 0, 10, 20, 30, 45, 55, 65, 75, 85, 95, 100 };

    public ConversationalSubmissionService(
        IApplicationDbContext db,
        IDocumentAgent documentAgent,
        IProactiveValidationService proactiveValidation,
        ISubmissionNumberService submissionNumber,
        ILogger<ConversationalSubmissionService> logger)
    {
        _db = db;
        _documentAgent = documentAgent;
        _proactiveValidation = proactiveValidation;
        _submissionNumber = submissionNumber;
        _logger = logger;
    }

    // ────────────────────────────────────────────────────────────────
    // Public API
    // ────────────────────────────────────────────────────────────────

    public async Task<ConversationResponse> ProcessMessageAsync(
        ConversationRequest request,
        Guid userId,
        Guid agencyId,
        CancellationToken ct = default)
    {
        // Determine current step from existing submission or start at Greeting
        if (request.SubmissionId is null || request.SubmissionId == Guid.Empty)
        {
            return await HandleGreetingAsync(request, userId, agencyId, ct);
        }

        var package = await _db.DocumentPackages
            .Include(p => p.Agency)
            .Include(p => p.PO)
            .Include(p => p.Invoices)
            .Include(p => p.Teams).ThenInclude(t => t.Photos)
            .Include(p => p.CostSummary)
            .Include(p => p.ActivitySummary)
            .Include(p => p.EnquiryDocument)
            .Include(p => p.AdditionalDocuments)
            .FirstOrDefaultAsync(p => p.Id == request.SubmissionId && !p.IsDeleted, ct);

        if (package is null)
        {
            return ErrorResponse(Guid.Empty, 0, "Submission not found.");
        }

        var step = (ConversationStep)package.CurrentStep;

        return step switch
        {
            ConversationStep.Greeting => await HandleGreetingAsync(request, userId, agencyId, ct),
            ConversationStep.POSelection => await HandlePOSelectionAsync(request, package, agencyId, ct),
            ConversationStep.StateSelection => await HandleStateSelectionAsync(request, package, agencyId, ct),
            ConversationStep.InvoiceUpload => await HandleInvoiceUploadAsync(request, package, ct),
            ConversationStep.ActivitySummaryUpload => await HandleActivitySummaryUploadAsync(request, package, ct),
            ConversationStep.CostSummaryUpload => await HandleCostSummaryUploadAsync(request, package, ct),
            ConversationStep.TeamDetailsLoop => await HandleTeamDetailsLoopAsync(request, package, ct),
            ConversationStep.EnquiryDumpUpload => await HandleEnquiryDumpUploadAsync(request, package, ct),
            ConversationStep.AdditionalDocsUpload => await HandleAdditionalDocsUploadAsync(request, package, ct),
            ConversationStep.FinalReview => await HandleFinalReviewAsync(request, package, userId, ct),
            _ => ErrorResponse(package.Id, package.CurrentStep, $"Invalid step: {step}")
        };
    }

    public async Task<ConversationResponse> ResumeAsync(
        Guid submissionId,
        Guid userId,
        Guid agencyId,
        CancellationToken ct = default)
    {
        var package = await _db.DocumentPackages
            .Include(p => p.Agency)
            .Include(p => p.PO)
            .Include(p => p.Invoices)
            .Include(p => p.Teams).ThenInclude(t => t.Photos)
            .Include(p => p.CostSummary)
            .Include(p => p.ActivitySummary)
            .Include(p => p.EnquiryDocument)
            .Include(p => p.AdditionalDocuments)
            .FirstOrDefaultAsync(p => p.Id == submissionId && !p.IsDeleted, ct);

        if (package is null)
        {
            return ErrorResponse(submissionId, 0, "Submission not found.");
        }

        if (package.State != PackageState.Draft)
        {
            return ErrorResponse(submissionId, package.CurrentStep, "Only draft submissions can be resumed.");
        }

        // Return the response for the current (last incomplete) step
        return BuildStepResponse(package);
    }

    public async Task<ConversationResponse> GetStateAsync(
        Guid submissionId,
        CancellationToken ct = default)
    {
        var package = await _db.DocumentPackages
            .Include(p => p.Agency)
            .Include(p => p.PO)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == submissionId && !p.IsDeleted, ct);

        if (package is null)
        {
            return ErrorResponse(submissionId, 0, "Submission not found.");
        }

        var step = package.CurrentStep;
        var progress = step >= 0 && step < StepProgress.Length ? StepProgress[step] : 0;

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = step,
            BotMessage = $"You are on step {step} ({(ConversationStep)step}).",
            Buttons = new List<ActionButton>(),
            RequiresFileUpload = false,
            ProgressPercent = progress
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 0 — Greeting
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleGreetingAsync(
        ConversationRequest request,
        Guid userId,
        Guid agencyId,
        CancellationToken ct)
    {
        // Draft detection: check for existing Draft packages for this agency
        var existingDraft = await _db.DocumentPackages
            .Include(p => p.PO)
            .Where(p => p.AgencyId == agencyId
                        && p.State == PackageState.Draft
                        && !p.IsDeleted)
            .OrderByDescending(p => p.UpdatedAt ?? p.CreatedAt)
            .FirstOrDefaultAsync(ct);

        var agency = await _db.Agencies
            .AsNoTracking()
            .FirstOrDefaultAsync(a => a.Id == agencyId, ct);

        var agencyName = agency?.SupplierName ?? "your agency";

        if (existingDraft is not null && request.Action != "start_new")
        {
            var poLabel = existingDraft.PO?.PONumber ?? "unknown PO";
            return new ConversationResponse
            {
                SubmissionId = existingDraft.Id,
                CurrentStep = (int)ConversationStep.Greeting,
                BotMessage = $"Welcome back, {agencyName}! You have a draft submission for PO {poLabel}.",
                Buttons = new List<ActionButton>
                {
                    new() { Label = "Resume", Action = "resume", PayloadJson = JsonSerializer.Serialize(new { submissionId = existingDraft.Id }) },
                    new() { Label = "Start over", Action = "start_new" }
                },
                RequiresFileUpload = false,
                ProgressPercent = StepProgress[(int)ConversationStep.Greeting]
            };
        }

        // If user chose "resume" on the draft detection prompt
        if (request.Action == "resume" && existingDraft is not null)
        {
            return BuildStepResponse(existingDraft);
        }

        // User tapped "Submit New Claim" or "Start over" — create a draft and go to PO selection
        if (request.Action == "start" || request.Action == "start_new")
        {
            // Soft-delete any existing draft so we start fresh
            if (existingDraft is not null && request.Action == "start_new")
            {
                existingDraft.IsDeleted = true;
                await _db.SaveChangesAsync(ct);
            }

            var newPackage = new DocumentPackage
            {
                Id = Guid.NewGuid(),
                AgencyId = agencyId,
                SubmittedByUserId = userId,
                State = PackageState.Draft,
                CurrentStep = (int)ConversationStep.POSelection,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _db.DocumentPackages.Add(newPackage);
            await _db.SaveChangesAsync(ct);

            return await HandlePOSelectionAsync(
                new ConversationRequest { Action = "show_pos", SubmissionId = newPackage.Id },
                newPackage,
                agencyId,
                ct);
        }

        return new ConversationResponse
        {
            SubmissionId = Guid.Empty,
            CurrentStep = (int)ConversationStep.Greeting,
            BotMessage = $"Hello, {agencyName}! How can I help you today?",
            Buttons = new List<ActionButton>
            {
                new() { Label = "Submit New Claim", Action = "start" },
                new() { Label = "Check Status", Action = "check_status" },
                new() { Label = "My Submissions", Action = "my_submissions" }
            },
            RequiresFileUpload = false,
            ProgressPercent = StepProgress[(int)ConversationStep.Greeting]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 1 — PO Selection
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandlePOSelectionAsync(
        ConversationRequest request,
        DocumentPackage package,
        Guid agencyId,
        CancellationToken ct)
    {
        if (request.Action == "select_po" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("poId", out var poIdProp) && Guid.TryParse(poIdProp.GetString(), out var poId))
            {
                var po = await _db.POs.FirstOrDefaultAsync(p => p.Id == poId && !p.IsDeleted, ct);
                if (po is null)
                {
                    return ErrorResponse(package.Id, package.CurrentStep, "Selected PO not found.");
                }

                // Create draft DocumentPackage if this is a fresh start (package was placeholder)
                if (package.State != PackageState.Draft)
                {
                    package.State = PackageState.Draft;
                }

                package.SelectedPOId = poId;
                await TransitionStepAsync(package, ConversationStep.StateSelection, ct);

                return await BuildStateSelectionPromptAsync(package, agencyId, ct);
            }
        }

        // Default: show PO search prompt
        // Fetch recent POs for the agency
        var recentPOs = await _db.POs
            .Where(p => p.AgencyId == agencyId
                        && !p.IsDeleted
                        && (p.POStatus == "Open" || p.POStatus == "PartiallyConsumed"))
            .OrderByDescending(p => p.PODate)
            .Take(5)
            .Select(p => new POSearchResult
            {
                Id = p.Id,
                PONumber = p.PONumber ?? "",
                PODate = p.PODate ?? DateTime.MinValue,
                VendorName = p.VendorName ?? "",
                TotalAmount = p.TotalAmount ?? 0,
                RemainingBalance = p.RemainingBalance,
                POStatus = p.POStatus
            })
            .ToListAsync(ct);

        CardData? card = recentPOs.Count > 0 ? new POListCard { Items = recentPOs } : null;

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.POSelection,
            BotMessage = recentPOs.Count > 0
                ? "Here are your recent open POs. Select one or search by PO number."
                : "No open POs found. POs sync from SAP every 4 hours.",
            Buttons = recentPOs.Count > 0
                ? new List<ActionButton> { new() { Label = "Search by PO number", Action = "search_po" } }
                : new List<ActionButton>
                {
                    new() { Label = "Check sync status", Action = "check_status" },
                    new() { Label = "Contact support", Action = "contact_support" }
                },
            Card = card,
            RequiresFileUpload = false,
            ProgressPercent = StepProgress[(int)ConversationStep.POSelection]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 2 — State Selection
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleStateSelectionAsync(
        ConversationRequest request,
        DocumentPackage package,
        Guid agencyId,
        CancellationToken ct)
    {
        if (request.Action == "select_state" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("state", out var stateProp))
            {
                var selectedState = stateProp.GetString();
                if (string.IsNullOrWhiteSpace(selectedState))
                {
                    return ErrorResponse(package.Id, package.CurrentStep, "State cannot be empty.");
                }

                package.ActivityState = selectedState;
                await TransitionStepAsync(package, ConversationStep.InvoiceUpload, ct);

                return new ConversationResponse
                {
                    SubmissionId = package.Id,
                    CurrentStep = (int)ConversationStep.InvoiceUpload,
                    BotMessage = $"State set to {selectedState}. Now please upload your Invoice.",
                    Buttons = new List<ActionButton>(),
                    RequiresFileUpload = true,
                    FileUploadType = "Invoice",
                    ProgressPercent = StepProgress[(int)ConversationStep.InvoiceUpload]
                };
            }
        }

        // Default: show state selection prompt
        return await BuildStateSelectionPromptAsync(package, agencyId, ct);
    }

    private async Task<ConversationResponse> BuildStateSelectionPromptAsync(
        DocumentPackage package,
        Guid agencyId,
        CancellationToken ct)
    {
        // Query top 4 frequent states for this agency
        var frequentStates = await _db.DocumentPackages
            .Where(p => p.AgencyId == agencyId && p.ActivityState != null && !p.IsDeleted)
            .GroupBy(p => p.ActivityState!)
            .OrderByDescending(g => g.Count())
            .Take(4)
            .Select(g => g.Key)
            .ToListAsync(ct);

        var buttons = frequentStates
            .Select(s => new ActionButton
            {
                Label = s,
                Action = "select_state",
                PayloadJson = JsonSerializer.Serialize(new { state = s })
            })
            .ToList();

        buttons.Add(new ActionButton { Label = "More states...", Action = "list_states" });

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.StateSelection,
            BotMessage = "Which state was the activity performed in?",
            Buttons = buttons,
            RequiresFileUpload = false,
            ProgressPercent = StepProgress[(int)ConversationStep.StateSelection]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 3 — Invoice Upload
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleInvoiceUploadAsync(
        ConversationRequest request,
        DocumentPackage package,
        CancellationToken ct)
    {
        if (request.Action == "upload_confirmed" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("documentId", out var docIdProp)
                && Guid.TryParse(docIdProp.GetString(), out var documentId))
            {
                // Duplicate detection: check for existing PO + invoice number combination
                var invoice = await _db.Invoices
                    .FirstOrDefaultAsync(i => i.Id == documentId && !i.IsDeleted, ct);

                if (invoice?.InvoiceNumber is not null && package.SelectedPOId is not null)
                {
                    var po = await _db.POs.FirstOrDefaultAsync(p => p.Id == package.SelectedPOId && !p.IsDeleted, ct);
                    if (po?.PONumber is not null)
                    {
                        var duplicate = await _db.DocumentPackages
                            .Include(dp => dp.Invoices)
                            .Where(dp => dp.PO != null
                                         && dp.PO.PONumber == po.PONumber
                                         && dp.Invoices.Any(i => i.InvoiceNumber == invoice.InvoiceNumber)
                                         && !dp.IsDeleted
                                         && dp.Id != package.Id
                                         && dp.State != PackageState.ASMRejected
                                         && dp.State != PackageState.RARejected)
                            .FirstOrDefaultAsync(ct);

                        if (duplicate is not null)
                        {
                            return new ConversationResponse
                            {
                                SubmissionId = package.Id,
                                CurrentStep = (int)ConversationStep.InvoiceUpload,
                                BotMessage = $"Submission {duplicate.SubmissionNumber ?? duplicate.Id.ToString()} already exists for this PO with invoice {invoice.InvoiceNumber}.",
                                Buttons = new List<ActionButton>
                                {
                                    new() { Label = "View existing", Action = "view_existing", PayloadJson = JsonSerializer.Serialize(new { submissionId = duplicate.Id }) },
                                    new() { Label = "Submit anyway (new version)", Action = "submit_anyway" }
                                },
                                RequiresFileUpload = false,
                                ProgressPercent = StepProgress[(int)ConversationStep.InvoiceUpload]
                            };
                        }
                    }
                }

                // Trigger proactive validation
                var validation = await _proactiveValidation.ValidateDocumentAsync(
                    documentId, DocumentType.Invoice, package.Id, ct);

                await TransitionStepAsync(package, ConversationStep.ActivitySummaryUpload, ct);

                return BuildValidationResponse(package, validation, "Invoice",
                    ConversationStep.ActivitySummaryUpload, "ActivitySummary");
            }
        }

        if (request.Action == "submit_anyway")
        {
            // Increment version number for duplicate override
            var invoiceForVersion = package.Invoices.FirstOrDefault(i => !i.IsDeleted);
            var poNumber = package.PO?.PONumber;

            var maxVersion = 1;
            if (poNumber is not null && invoiceForVersion?.InvoiceNumber is not null)
            {
                maxVersion = await _db.DocumentPackages
                    .Include(dp => dp.PO)
                    .Include(dp => dp.Invoices)
                    .Where(dp => dp.PO != null
                                 && dp.PO.PONumber == poNumber
                                 && dp.Invoices.Any(i => i.InvoiceNumber == invoiceForVersion.InvoiceNumber)
                                 && !dp.IsDeleted)
                    .MaxAsync(dp => (int?)dp.VersionNumber, ct) ?? 0;
            }

            package.VersionNumber = maxVersion + 1;
            await _db.SaveChangesAsync(ct);

            // Proceed normally: run proactive validation on the uploaded invoice and advance
            if (invoiceForVersion is not null)
            {
                var validation = await _proactiveValidation.ValidateDocumentAsync(
                    invoiceForVersion.Id, DocumentType.Invoice, package.Id, ct);

                await TransitionStepAsync(package, ConversationStep.ActivitySummaryUpload, ct);

                return BuildValidationResponse(package, validation, "Invoice",
                    ConversationStep.ActivitySummaryUpload, "ActivitySummary");
            }

            // Fallback: if no invoice found yet, prompt for upload
            await TransitionStepAsync(package, ConversationStep.ActivitySummaryUpload, ct);
            return BuildUploadPrompt(package, "ActivitySummary");
        }

        if (request.Action == "view_existing" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var viewPayload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (viewPayload.TryGetProperty("submissionId", out var existingIdProp)
                && Guid.TryParse(existingIdProp.GetString(), out var existingId))
            {
                var existing = await _db.DocumentPackages
                    .Include(dp => dp.PO)
                    .Include(dp => dp.Invoices)
                    .Include(dp => dp.Teams).ThenInclude(t => t.Photos)
                    .FirstOrDefaultAsync(dp => dp.Id == existingId && !dp.IsDeleted, ct);

                if (existing is not null)
                {
                    var existingInvoice = existing.Invoices.FirstOrDefault(i => !i.IsDeleted);
                    var teamCount = existing.Teams.Count(t => !t.IsDeleted);
                    var statusText = existing.State.ToString();

                    return new ConversationResponse
                    {
                        SubmissionId = package.Id,
                        CurrentStep = (int)ConversationStep.InvoiceUpload,
                        BotMessage = $"Existing submission {existing.SubmissionNumber ?? existing.Id.ToString()}:\n" +
                                     $"• PO: {existing.PO?.PONumber ?? "N/A"}\n" +
                                     $"• Invoice: {existingInvoice?.InvoiceNumber ?? "N/A"}\n" +
                                     $"• Status: {statusText}\n" +
                                     $"• Teams: {teamCount}\n" +
                                     $"• Version: {existing.VersionNumber}",
                        Buttons = new List<ActionButton>
                        {
                            new() { Label = "Submit anyway (new version)", Action = "submit_anyway" },
                            new() { Label = "Cancel", Action = "upload_prompt" }
                        },
                        RequiresFileUpload = false,
                        ProgressPercent = StepProgress[(int)ConversationStep.InvoiceUpload]
                    };
                }
            }
        }

        // Allow continuing past validation warnings without re-uploading
        if (request.Action == "continue_with_warnings")
        {
            await TransitionStepAsync(package, ConversationStep.ActivitySummaryUpload, ct);
            return BuildUploadPrompt(package, "ActivitySummary");
        }

        // Default: prompt for invoice upload
        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.InvoiceUpload,
            BotMessage = "Please upload your Invoice document.",
            Buttons = new List<ActionButton>(),
            RequiresFileUpload = true,
            FileUploadType = "Invoice",
            ProgressPercent = StepProgress[(int)ConversationStep.InvoiceUpload]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 4 — Activity Summary Upload
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleActivitySummaryUploadAsync(
        ConversationRequest request,
        DocumentPackage package,
        CancellationToken ct)
    {
        if (request.Action == "upload_confirmed" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("documentId", out var docIdProp)
                && Guid.TryParse(docIdProp.GetString(), out var documentId))
            {
                var validation = await _proactiveValidation.ValidateDocumentAsync(
                    documentId, DocumentType.ActivitySummary, package.Id, ct);

                await TransitionStepAsync(package, ConversationStep.CostSummaryUpload, ct);

                return BuildValidationResponse(package, validation, "Activity Summary",
                    ConversationStep.CostSummaryUpload, "CostSummary");
            }
        }

        // Allow continuing past warnings without re-uploading
        if (request.Action == "continue_with_warnings")
        {
            await TransitionStepAsync(package, ConversationStep.CostSummaryUpload, ct);
            return BuildUploadPrompt(package, "CostSummary");
        }

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.ActivitySummaryUpload,
            BotMessage = "Please upload your Activity Summary document.",
            Buttons = new List<ActionButton>(),
            RequiresFileUpload = true,
            FileUploadType = "ActivitySummary",
            ProgressPercent = StepProgress[(int)ConversationStep.ActivitySummaryUpload]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 5 — Cost Summary Upload
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleCostSummaryUploadAsync(
        ConversationRequest request,
        DocumentPackage package,
        CancellationToken ct)
    {
        if (request.Action == "upload_confirmed" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("documentId", out var docIdProp)
                && Guid.TryParse(docIdProp.GetString(), out var documentId))
            {
                var validation = await _proactiveValidation.ValidateDocumentAsync(
                    documentId, DocumentType.CostSummary, package.Id, ct);

                await TransitionStepAsync(package, ConversationStep.TeamDetailsLoop, ct);

                return BuildValidationResponse(package, validation, "Cost Summary",
                    ConversationStep.TeamDetailsLoop, null);
            }
        }

        // Allow continuing past warnings without re-uploading
        if (request.Action == "continue_with_warnings")
        {
            await TransitionStepAsync(package, ConversationStep.TeamDetailsLoop, ct);
            return new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = (int)ConversationStep.TeamDetailsLoop,
                BotMessage = "Let's add your team details. Provide team name, dealer, dates, and working days.",
                Buttons = new List<ActionButton>
                {
                    new() { Label = "Add team", Action = "prompt_team" }
                },
                RequiresFileUpload = false,
                ProgressPercent = StepProgress[(int)ConversationStep.TeamDetailsLoop]
            };
        }

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.CostSummaryUpload,
            BotMessage = "Please upload your Cost Summary document.",
            Buttons = new List<ActionButton>(),
            RequiresFileUpload = true,
            FileUploadType = "CostSummary",
            ProgressPercent = StepProgress[(int)ConversationStep.CostSummaryUpload]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 6 — Team Details Loop
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleTeamDetailsLoopAsync(
        ConversationRequest request,
        DocumentPackage package,
        CancellationToken ct)
    {
        var existingTeams = package.Teams.Where(t => !t.IsDeleted).ToList();

        if (request.Action == "add_team" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            var team = new Teams
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                CampaignName = GetStringProp(payload, "teamName"),
                DealershipName = GetStringProp(payload, "dealerName"),
                TeamCode = GetStringProp(payload, "dealerCode"),
                State = package.ActivityState,
                DealershipAddress = GetStringProp(payload, "city"),
                StartDate = GetDateProp(payload, "startDate"),
                EndDate = GetDateProp(payload, "endDate"),
                WorkingDays = GetIntProp(payload, "workingDays"),
                CreatedAt = DateTime.UtcNow
            };

            _db.Teams.Add(team);
            await _db.SaveChangesAsync(ct);

            existingTeams.Add(team);

            return BuildTeamLoopResponse(package, existingTeams, team,
                "Team added! Upload photos for this team (min 3, max 10).");
        }

        if (request.Action == "upload_photo" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            // Photo upload confirmation — just acknowledge, validation happens via ProactiveValidationService
            var currentTeam = existingTeams.LastOrDefault();
            var photoCount = currentTeam?.Photos.Count(p => !p.IsDeleted) ?? 0;

            return BuildTeamLoopResponse(package, existingTeams, currentTeam,
                $"Photo uploaded ({photoCount} total). Add more or finish this team.");
        }

        if (request.Action == "done_team")
        {
            var currentTeam = existingTeams.LastOrDefault();
            var photoCount = currentTeam?.Photos.Count(p => !p.IsDeleted) ?? 0;

            if (photoCount < 3)
            {
                return BuildTeamLoopResponse(package, existingTeams, currentTeam,
                    $"Each team needs at least 3 photos. Currently {photoCount}. Please upload more.");
            }

            return new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = (int)ConversationStep.TeamDetailsLoop,
                BotMessage = $"Team {existingTeams.Count} complete. Add another team or continue.",
                Buttons = new List<ActionButton>
                {
                    new() { Label = "Add another team", Action = "prompt_team" },
                    new() { Label = "Done with teams", Action = "done_all_teams" }
                },
                RequiresFileUpload = false,
                ProgressPercent = StepProgress[(int)ConversationStep.TeamDetailsLoop]
            };
        }

        if (request.Action == "done_all_teams")
        {
            if (existingTeams.Count == 0)
            {
                return new ConversationResponse
                {
                    SubmissionId = package.Id,
                    CurrentStep = (int)ConversationStep.TeamDetailsLoop,
                    BotMessage = "You need at least one team. Please add team details.",
                    Buttons = new List<ActionButton>
                    {
                        new() { Label = "Add team", Action = "prompt_team" }
                    },
                    RequiresFileUpload = false,
                    ProgressPercent = StepProgress[(int)ConversationStep.TeamDetailsLoop]
                };
            }

            await TransitionStepAsync(package, ConversationStep.EnquiryDumpUpload, ct);

            return new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = (int)ConversationStep.EnquiryDumpUpload,
                BotMessage = "All teams recorded. Now please upload the Enquiry Dump (Excel or PDF). This is mandatory.",
                Buttons = new List<ActionButton>(),
                RequiresFileUpload = true,
                FileUploadType = "EnquiryDump",
                ProgressPercent = StepProgress[(int)ConversationStep.EnquiryDumpUpload]
            };
        }

        // Default: prompt to add a team
        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.TeamDetailsLoop,
            BotMessage = existingTeams.Count > 0
                ? $"You have {existingTeams.Count} team(s). Add another or continue."
                : "Let's add your team details. Provide team name, dealer, dates, and working days.",
            Buttons = new List<ActionButton>
            {
                new() { Label = "Add team", Action = "prompt_team" },
            }.Concat(existingTeams.Count > 0
                ? new[] { new ActionButton { Label = "Done with teams", Action = "done_all_teams" } }
                : Array.Empty<ActionButton>())
            .ToList(),
            RequiresFileUpload = false,
            ProgressPercent = StepProgress[(int)ConversationStep.TeamDetailsLoop]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 7 — Enquiry Dump Upload (mandatory, hard-block skip)
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleEnquiryDumpUploadAsync(
        ConversationRequest request,
        DocumentPackage package,
        CancellationToken ct)
    {
        // Hard-block skip
        if (request.Action == "skip")
        {
            return new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = (int)ConversationStep.EnquiryDumpUpload,
                BotMessage = "The Enquiry Dump is mandatory and cannot be skipped. Please upload it to continue.",
                Buttons = new List<ActionButton>(),
                RequiresFileUpload = true,
                FileUploadType = "EnquiryDump",
                ProgressPercent = StepProgress[(int)ConversationStep.EnquiryDumpUpload]
            };
        }

        if (request.Action == "upload_confirmed" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("documentId", out var docIdProp)
                && Guid.TryParse(docIdProp.GetString(), out var documentId))
            {
                // Load the enquiry document to show summary
                var enquiryDoc = await _db.EnquiryDocuments
                    .FirstOrDefaultAsync(e => e.Id == documentId && !e.IsDeleted, ct);

                var totalRecords = 0;
                var completeRecords = 0;
                if (enquiryDoc?.ExtractedDataJson is not null)
                {
                    try
                    {
                        var data = JsonSerializer.Deserialize<JsonElement>(enquiryDoc.ExtractedDataJson);
                        if (data.TryGetProperty("totalRecords", out var totalProp))
                            totalRecords = totalProp.GetInt32();
                        if (data.TryGetProperty("completeRecords", out var completeProp))
                            completeRecords = completeProp.GetInt32();
                    }
                    catch { /* extraction data may not be available yet */ }
                }

                await TransitionStepAsync(package, ConversationStep.AdditionalDocsUpload, ct);

                return new ConversationResponse
                {
                    SubmissionId = package.Id,
                    CurrentStep = (int)ConversationStep.AdditionalDocsUpload,
                    BotMessage = totalRecords > 0
                        ? $"Enquiry Dump uploaded. {totalRecords} records found ({completeRecords} complete, {totalRecords - completeRecords} incomplete). Would you like to upload any additional documents?"
                        : "Enquiry Dump uploaded and processing. Would you like to upload any additional documents?",
                    Buttons = new List<ActionButton>
                    {
                        new() { Label = "Upload", Action = "upload_additional" },
                        new() { Label = "Skip →", Action = "skip" }
                    },
                    RequiresFileUpload = false,
                    ProgressPercent = StepProgress[(int)ConversationStep.AdditionalDocsUpload]
                };
            }
        }

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.EnquiryDumpUpload,
            BotMessage = "Please upload the Enquiry Dump (Excel .xlsx/.csv or PDF). This is mandatory.",
            Buttons = new List<ActionButton>(),
            RequiresFileUpload = true,
            FileUploadType = "EnquiryDump",
            ProgressPercent = StepProgress[(int)ConversationStep.EnquiryDumpUpload]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 8 — Additional Documents Upload (optional with skip)
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleAdditionalDocsUploadAsync(
        ConversationRequest request,
        DocumentPackage package,
        CancellationToken ct)
    {
        if (request.Action == "skip" || request.Action == "done_additional")
        {
            await TransitionStepAsync(package, ConversationStep.FinalReview, ct);
            return await BuildFinalReviewResponseAsync(package, ct);
        }

        if (request.Action == "upload_confirmed")
        {
            return new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = (int)ConversationStep.AdditionalDocsUpload,
                BotMessage = "Document uploaded. Add more or continue to review.",
                Buttons = new List<ActionButton>
                {
                    new() { Label = "Upload another", Action = "upload_additional" },
                    new() { Label = "Continue to review", Action = "done_additional" }
                },
                RequiresFileUpload = false,
                ProgressPercent = StepProgress[(int)ConversationStep.AdditionalDocsUpload]
            };
        }

        // Default: prompt
        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.AdditionalDocsUpload,
            BotMessage = "Would you like to upload any additional supporting documents?",
            Buttons = new List<ActionButton>
            {
                new() { Label = "Upload", Action = "upload_additional" },
                new() { Label = "Skip \u2192", Action = "skip" }
            },
            RequiresFileUpload = false,
            ProgressPercent = StepProgress[(int)ConversationStep.AdditionalDocsUpload]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Step 9 — Final Review
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> HandleFinalReviewAsync(
        ConversationRequest request,
        DocumentPackage package,
        Guid userId,
        CancellationToken ct)
    {
        if (request.Action == "edit" && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = JsonSerializer.Deserialize<JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("step", out var stepProp) && stepProp.TryGetInt32(out var targetStep))
            {
                if (targetStep < 0 || targetStep >= (int)ConversationStep.FinalReview)
                {
                    return ErrorResponse(package.Id, package.CurrentStep, "Invalid edit target step.");
                }

                package.CurrentStep = targetStep;
                await _db.SaveChangesAsync(ct);

                return BuildStepResponse(package);
            }
        }

        if (request.Action == "submit")
        {
            return await HandleSubmitAsync(package, userId, ct);
        }

        return await BuildFinalReviewResponseAsync(package, ct);
    }

    private async Task<ConversationResponse> HandleSubmitAsync(
        DocumentPackage package,
        Guid userId,
        CancellationToken ct)
    {
        // Completeness validation
        var errors = new List<string>();

        if (package.Invoices.All(i => i.IsDeleted))
            errors.Add("Invoice is required.");
        if (package.CostSummary is null || package.CostSummary.IsDeleted)
            errors.Add("Cost Summary is required.");
        if (package.ActivitySummary is null || package.ActivitySummary.IsDeleted)
            errors.Add("Activity Summary is required.");
        if (package.EnquiryDocument is null || package.EnquiryDocument.IsDeleted)
            errors.Add("Enquiry Dump is required.");
        if (string.IsNullOrWhiteSpace(package.ActivityState))
            errors.Add("State must be set.");

        var activeTeams = package.Teams.Where(t => !t.IsDeleted).ToList();
        if (activeTeams.Count == 0)
            errors.Add("At least one team is required.");
        foreach (var team in activeTeams)
        {
            var photoCount = team.Photos.Count(p => !p.IsDeleted);
            if (photoCount < 3)
                errors.Add($"Team '{team.CampaignName}' needs at least 3 photos (has {photoCount}).");
        }

        if (errors.Count > 0)
        {
            return new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = (int)ConversationStep.FinalReview,
                BotMessage = "Cannot submit. Please fix the following:\n" + string.Join("\n", errors.Select(e => $"• {e}")),
                Buttons = new List<ActionButton>
                {
                    new() { Label = "Edit something", Action = "edit" }
                },
                RequiresFileUpload = false,
                ProgressPercent = StepProgress[(int)ConversationStep.FinalReview],
                Error = "Completeness validation failed."
            };
        }

        // Generate submission number
        var submissionNumber = await _submissionNumber.GenerateAsync(ct);
        package.SubmissionNumber = submissionNumber;

        // CIRCLE HEAD auto-assignment via StateMapping
        var circleHeads = await _db.StateMappings
            .Where(sm => sm.State == package.ActivityState && sm.IsActive && !sm.IsDeleted)
            .Select(sm => sm.CircleHeadUserId)
            .Where(id => id != null)
            .Distinct()
            .ToListAsync(ct);

        if (circleHeads.Count == 1)
        {
            package.AssignedCircleHeadUserId = circleHeads[0];
        }
        else if (circleHeads.Count > 1)
        {
            // Load-balance: assign to CIRCLE HEAD with fewest pending submissions
            var leastLoaded = await _db.DocumentPackages
                .Where(dp => circleHeads.Contains(dp.AssignedCircleHeadUserId)
                              && (dp.State == PackageState.PendingASM || dp.State == PackageState.PendingRA)
                              && !dp.IsDeleted)
                .GroupBy(dp => dp.AssignedCircleHeadUserId)
                .Select(g => new { UserId = g.Key, Count = g.Count() })
                .OrderBy(x => x.Count)
                .FirstOrDefaultAsync(ct);

            package.AssignedCircleHeadUserId = leastLoaded?.UserId ?? circleHeads[0];
        }
        // else: no CIRCLE HEAD found — leave null for manual assignment

        // Transition to Submitted
        package.State = PackageState.Uploaded; // Draft -> Uploaded (Submitted)
        package.CurrentStep = (int)ConversationStep.Submitted;
        package.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        // Look up assigned reviewer name
        string? reviewerName = null;
        if (package.AssignedCircleHeadUserId is not null)
        {
            reviewerName = await _db.Users
                .Where(u => u.Id == package.AssignedCircleHeadUserId)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync(ct);
        }

        var confirmMsg = $"Submission {submissionNumber} has been submitted successfully!";
        if (reviewerName is not null)
            confirmMsg += $" Assigned to {reviewerName} for review.";
        else
            confirmMsg += " A reviewer will be assigned shortly.";
        confirmMsg += " Expected review timeline: 24-48 hours.";

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.Submitted,
            BotMessage = confirmMsg,
            Buttons = new List<ActionButton>
            {
                new() { Label = "Submit New Claim", Action = "start" },
                new() { Label = "My Submissions", Action = "my_submissions" }
            },
            RequiresFileUpload = false,
            ProgressPercent = 100
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: Build Final Review Response
    // ────────────────────────────────────────────────────────────────

    private async Task<ConversationResponse> BuildFinalReviewResponseAsync(
        DocumentPackage package,
        CancellationToken ct)
    {
        // Reload full data if needed
        var pkg = package;
        var poNumber = pkg.PO?.PONumber ?? "N/A";
        var state = pkg.ActivityState ?? "Not set";

        var invoice = pkg.Invoices.FirstOrDefault(i => !i.IsDeleted);
        var invoiceStatus = invoice is not null ? "Uploaded" : "Missing";

        var costStatus = pkg.CostSummary is not null && !pkg.CostSummary.IsDeleted ? "Uploaded" : "Missing";
        var activityStatus = pkg.ActivitySummary is not null && !pkg.ActivitySummary.IsDeleted ? "Uploaded" : "Missing";

        var activeTeams = pkg.Teams.Where(t => !t.IsDeleted).ToList();
        var teamCards = activeTeams.Select(t => new TeamSummaryCard
        {
            TeamName = t.CampaignName ?? "Unnamed",
            DealerName = t.DealershipName ?? "N/A",
            City = t.DealershipAddress ?? "N/A",
            StartDate = t.StartDate ?? DateTime.MinValue,
            EndDate = t.EndDate ?? DateTime.MinValue,
            WorkingDays = t.WorkingDays ?? 0,
            PhotoCount = t.Photos.Count(p => !p.IsDeleted),
            PhotosValidated = t.Photos.Count(p => !p.IsDeleted && p.ExtractionConfidence > 0)
        }).ToList();

        var enquiryCount = 0;
        if (pkg.EnquiryDocument?.ExtractedDataJson is not null)
        {
            try
            {
                var data = JsonSerializer.Deserialize<JsonElement>(pkg.EnquiryDocument.ExtractedDataJson);
                if (data.TryGetProperty("totalRecords", out var tr))
                    enquiryCount = tr.GetInt32();
            }
            catch { /* ignore parse errors */ }
        }

        var totalAmount = invoice?.TotalAmount ?? 0;

        var card = new FinalReviewCard
        {
            PONumber = poNumber,
            State = state,
            InvoiceStatus = invoiceStatus,
            CostSummaryStatus = costStatus,
            ActivitySummaryStatus = activityStatus,
            Teams = teamCards,
            EnquiryRecordCount = enquiryCount,
            TotalAmount = totalAmount
        };

        return new ConversationResponse
        {
            SubmissionId = pkg.Id,
            CurrentStep = (int)ConversationStep.FinalReview,
            BotMessage = "Here's your submission summary. Review everything and submit when ready.",
            Buttons = new List<ActionButton>
            {
                new() { Label = "Submit \u2705", Action = "submit" },
                new() { Label = "Edit something", Action = "edit" }
            },
            Card = card,
            RequiresFileUpload = false,
            ProgressPercent = StepProgress[(int)ConversationStep.FinalReview]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: Persist step transition
    // ────────────────────────────────────────────────────────────────

    private async Task TransitionStepAsync(
        DocumentPackage package,
        ConversationStep nextStep,
        CancellationToken ct)
    {
        package.CurrentStep = (int)nextStep;
        package.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: Build response for the current step (used by Resume)
    // ────────────────────────────────────────────────────────────────

    private ConversationResponse BuildStepResponse(DocumentPackage package)
    {
        var step = (ConversationStep)package.CurrentStep;
        var progress = package.CurrentStep >= 0 && package.CurrentStep < StepProgress.Length
            ? StepProgress[package.CurrentStep]
            : 0;

        return step switch
        {
            ConversationStep.POSelection => new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = package.CurrentStep,
                BotMessage = "Let's continue. Please select a Purchase Order.",
                Buttons = new List<ActionButton> { new() { Label = "Search by PO number", Action = "search_po" } },
                RequiresFileUpload = false,
                ProgressPercent = progress
            },
            ConversationStep.StateSelection => new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = package.CurrentStep,
                BotMessage = "Which state was the activity performed in?",
                Buttons = new List<ActionButton> { new() { Label = "More states...", Action = "list_states" } },
                RequiresFileUpload = false,
                ProgressPercent = progress
            },
            ConversationStep.InvoiceUpload => BuildUploadPrompt(package, "Invoice"),
            ConversationStep.ActivitySummaryUpload => BuildUploadPrompt(package, "ActivitySummary"),
            ConversationStep.CostSummaryUpload => BuildUploadPrompt(package, "CostSummary"),
            ConversationStep.TeamDetailsLoop => new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = package.CurrentStep,
                BotMessage = "Let's continue with team details.",
                Buttons = new List<ActionButton>
                {
                    new() { Label = "Add team", Action = "prompt_team" },
                    new() { Label = "Done with teams", Action = "done_all_teams" }
                },
                RequiresFileUpload = false,
                ProgressPercent = progress
            },
            ConversationStep.EnquiryDumpUpload => BuildUploadPrompt(package, "EnquiryDump"),
            ConversationStep.AdditionalDocsUpload => new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = package.CurrentStep,
                BotMessage = "Would you like to upload any additional supporting documents?",
                Buttons = new List<ActionButton>
                {
                    new() { Label = "Upload", Action = "upload_additional" },
                    new() { Label = "Skip \u2192", Action = "skip" }
                },
                RequiresFileUpload = false,
                ProgressPercent = progress
            },
            _ => new ConversationResponse
            {
                SubmissionId = package.Id,
                CurrentStep = package.CurrentStep,
                BotMessage = "Resuming your submission.",
                Buttons = new List<ActionButton>(),
                RequiresFileUpload = false,
                ProgressPercent = progress
            }
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: Build upload prompt response
    // ────────────────────────────────────────────────────────────────

    private static ConversationResponse BuildUploadPrompt(DocumentPackage package, string fileType)
    {
        var step = package.CurrentStep;
        var progress = step >= 0 && step < StepProgress.Length ? StepProgress[step] : 0;

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = step,
            BotMessage = $"Please upload your {fileType} document.",
            Buttons = new List<ActionButton>(),
            RequiresFileUpload = true,
            FileUploadType = fileType,
            ProgressPercent = progress
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: Build validation result response
    // ────────────────────────────────────────────────────────────────

    private static ConversationResponse BuildValidationResponse(
        DocumentPackage package,
        ProactiveValidationResponse validation,
        string docTypeName,
        ConversationStep nextStep,
        string? nextFileType)
    {
        var nextStepInt = (int)nextStep;
        var progress = nextStepInt >= 0 && nextStepInt < StepProgress.Length ? StepProgress[nextStepInt] : 0;

        var statusMsg = validation.AllPassed
            ? $"{docTypeName} validated — all checks passed!"
            : $"{docTypeName} validated — {validation.PassCount} passed, {validation.FailCount} failed, {validation.WarningCount} warnings.";

        var card = new ValidationResultCard
        {
            DocumentType = docTypeName,
            Rules = validation.Rules,
            AllPassed = validation.AllPassed
        };

        var buttons = new List<ActionButton>
        {
            new() { Label = "Re-upload", Action = "reupload" }
        };

        var requiresUpload = false;
        if (nextFileType is not null)
        {
            statusMsg += $" Next: upload your {nextFileType}.";
            requiresUpload = true;
        }

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = nextStepInt,
            BotMessage = statusMsg,
            Buttons = buttons,
            Card = card,
            RequiresFileUpload = requiresUpload,
            FileUploadType = nextFileType,
            ProgressPercent = progress
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: Build team loop response
    // ────────────────────────────────────────────────────────────────

    private static ConversationResponse BuildTeamLoopResponse(
        DocumentPackage package,
        List<Teams> allTeams,
        Teams? currentTeam,
        string message)
    {
        var photoCount = currentTeam?.Photos.Count(p => !p.IsDeleted) ?? 0;

        return new ConversationResponse
        {
            SubmissionId = package.Id,
            CurrentStep = (int)ConversationStep.TeamDetailsLoop,
            BotMessage = $"Team {allTeams.Count} of {allTeams.Count}: {message}",
            Buttons = new List<ActionButton>
            {
                new() { Label = "Done with team", Action = "done_team" }
            },
            Card = currentTeam is not null
                ? new TeamSummaryCard
                {
                    TeamName = currentTeam.CampaignName ?? "Unnamed",
                    DealerName = currentTeam.DealershipName ?? "N/A",
                    City = currentTeam.DealershipAddress ?? "N/A",
                    StartDate = currentTeam.StartDate ?? DateTime.MinValue,
                    EndDate = currentTeam.EndDate ?? DateTime.MinValue,
                    WorkingDays = currentTeam.WorkingDays ?? 0,
                    PhotoCount = photoCount,
                    PhotosValidated = currentTeam.Photos.Count(p => !p.IsDeleted && p.ExtractionConfidence > 0)
                }
                : null,
            RequiresFileUpload = true,
            FileUploadType = "TeamPhoto",
            ProgressPercent = StepProgress[(int)ConversationStep.TeamDetailsLoop]
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: Error response
    // ────────────────────────────────────────────────────────────────

    private static ConversationResponse ErrorResponse(Guid submissionId, int step, string error)
    {
        return new ConversationResponse
        {
            SubmissionId = submissionId,
            CurrentStep = step,
            BotMessage = error,
            Buttons = new List<ActionButton>(),
            RequiresFileUpload = false,
            ProgressPercent = 0,
            Error = error
        };
    }

    // ────────────────────────────────────────────────────────────────
    // Helper: JSON property extraction
    // ────────────────────────────────────────────────────────────────

    private static string? GetStringProp(JsonElement el, string name) =>
        el.TryGetProperty(name, out var prop) ? prop.GetString() : null;

    private static DateTime? GetDateProp(JsonElement el, string name) =>
        el.TryGetProperty(name, out var prop) && prop.TryGetDateTime(out var dt) ? dt : null;

    private static int? GetIntProp(JsonElement el, string name) =>
        el.TryGetProperty(name, out var prop) && prop.TryGetInt32(out var val) ? val : null;
}
