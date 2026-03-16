using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
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

    public AssistantController(
        IApplicationDbContext context,
        ILogger<AssistantController> logger)
    {
        _context = context;
        _logger = logger;
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
                "search_state" => await HandleSearchState(request, ct),
                "list_states" => HandleListAllStates(),
                "invoice_uploaded" => await HandleInvoiceUploaded(request, agencyId.Value, ct),
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
        // Frontend sends documentId after uploading via /api/documents/upload
        string? documentId = request.Message?.Trim();
        if (string.IsNullOrEmpty(documentId) && !string.IsNullOrEmpty(request.PayloadJson))
        {
            var payload = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(request.PayloadJson);
            if (payload.TryGetProperty("documentId", out var docProp))
                documentId = docProp.GetString();
        }

        if (string.IsNullOrWhiteSpace(documentId))
        {
            return new AssistantResponse
            {
                Type = "error",
                Message = "Invoice upload confirmation missing. Please try uploading again.",
            };
        }

        return new AssistantResponse
        {
            Type = "invoice_upload_success",
            Message = "Invoice uploaded successfully! Processing document...",
        };
    }

    private async Task<AssistantResponse> HandleSearchState(
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
