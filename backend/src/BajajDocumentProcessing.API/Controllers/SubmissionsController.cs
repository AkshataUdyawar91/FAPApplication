using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Common;
using BajajDocumentProcessing.Application.DTOs.Submissions;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Text.Json;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Submissions controller for document package management and approval workflow
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SubmissionsController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly IWorkflowOrchestrator _orchestrator;
    private readonly IBackgroundWorkflowQueue _backgroundQueue;
    private readonly ILogger<SubmissionsController> _logger;
    private readonly ISubmissionNumberService _submissionNumberService;
    private readonly ICircleHeadAssignmentService _circleHeadAssignmentService;
    private readonly IRAAssignmentService _raAssignmentService;
    private readonly ISubmissionNotificationService _submissionNotificationService;
    private readonly IEmailAgent _emailAgent;

    public SubmissionsController(
        IApplicationDbContext context,
        IWorkflowOrchestrator orchestrator,
        IBackgroundWorkflowQueue backgroundQueue,
        ILogger<SubmissionsController> logger,
        ISubmissionNumberService submissionNumberService,
        ICircleHeadAssignmentService circleHeadAssignmentService,
        ISubmissionNotificationService submissionNotificationService,
        IEmailAgent emailAgent)
    {
        _context = context;
        _orchestrator = orchestrator;
        _backgroundQueue = backgroundQueue;
        _logger = logger;
        _submissionNumberService = submissionNumberService;
        _circleHeadAssignmentService = circleHeadAssignmentService;
        _raAssignmentService = raAssignmentService;
        _submissionNotificationService = submissionNotificationService;
        _emailAgent = emailAgent;
    }

    /// <summary>
    /// Create a new document submission package (Agency role only)
    /// </summary>
    /// <param name="request">Submission creation request</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Created submission with ID and initial status</returns>
    /// <response code="201">Submission created and queued for processing</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - Agency role required</response>
    /// <response code="500">Internal server error</response>
    [HttpPost]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status201Created)]
    public async Task<IActionResult> CreateSubmission(
        [FromBody] CreateSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Try both claim types for compatibility
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
            {
                _logger.LogWarning("User ID claim not found in token");
                return Unauthorized(new { error = "User ID not found in token" });
            }

            var userId = Guid.Parse(userIdClaim);

            // Look up the user's AgencyId so the FK constraint is satisfied
            var user = await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);

            if (user?.AgencyId == null)
            {
                _logger.LogWarning("User {UserId} has no AgencyId — cannot create submission", userId);
                return BadRequest(new { error = "User is not linked to an agency" });
            }

            // Create document package
            var package = new Domain.Entities.DocumentPackage
            {
                Id = Guid.NewGuid(),
                SubmittedByUserId = userId,
                AgencyId = user.AgencyId.Value,
                SelectedPOId = request.SelectedPoId,
                State = PackageState.Uploaded,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.DocumentPackages.Add(package);
            await _context.SaveChangesAsync(cancellationToken);

            // Queue workflow for background processing (non-blocking)
            await _backgroundQueue.QueueWorkflowAsync(package.Id);
            
            _logger.LogInformation("Submission {PackageId} created and queued for processing", package.Id);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Submission received and is being processed"
            };

            return CreatedAtAction(
                nameof(GetSubmission),
                new { id = package.Id },
                response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating submission");
            return StatusCode(500, new { error = "An error occurred while creating the submission" });
        }
    }

    /// <summary>
    /// Create a draft submission from the conversational flow (Agency role only)
    /// </summary>
    /// <param name="request">Draft creation request with PO ID and Agency ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Created draft submission ID</returns>
    /// <response code="201">Draft submission created</response>
    /// <response code="400">Bad request - invalid PO</response>
    /// <response code="401">Unauthorized</response>
    [HttpPost("draft")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(CreateDraftResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateDraft(
        [FromBody] CreateDraftRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
            {
                return Unauthorized(new { error = "User ID not found in token" });
            }

            var userId = Guid.Parse(userIdClaim);

            // Verify PO exists
            var po = await _context.POs.FirstOrDefaultAsync(p => p.Id == request.PoId, cancellationToken);
            if (po == null)
            {
                return BadRequest(new { error = "PO not found" });
            }

            var package = new Domain.Entities.DocumentPackage
            {
                Id = Guid.NewGuid(),
                SubmittedByUserId = userId,
                AgencyId = request.AgencyId,
                State = PackageState.Draft,
                SelectedPOId = request.PoId,
                CurrentStep = 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.DocumentPackages.Add(package);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Draft submission {PackageId} created for PO {PoId} by user {UserId}",
                package.Id, request.PoId, userId);

            var response = new CreateDraftResponse
            {
                SubmissionId = package.Id,
                SubmissionNumber = null // Generated at submit time
            };

            return CreatedAtAction(nameof(GetSubmission), new { id = package.Id }, response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating draft submission");
            return StatusCode(500, new { error = "An error occurred while creating the draft submission" });
        }
    }

    /// <summary>
    /// Update submission fields such as activity state (Agency role only)
    /// </summary>
    /// <param name="id">Submission ID</param>
    /// <param name="request">Fields to update</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>204 No Content on success</returns>
    /// <response code="204">Submission updated</response>
    /// <response code="400">Bad request</response>
    /// <response code="404">Submission not found</response>
    [HttpPatch("{id}")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> PatchSubmission(
        Guid id,
        [FromBody] PatchSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
            {
                return Unauthorized(new { error = "User ID not found in token" });
            }

            var userId = Guid.Parse(userIdClaim);

            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Verify ownership
            if (package.SubmittedByUserId != userId)
            {
                return Forbid();
            }

            // Only allow patching Draft submissions
            if (package.State != PackageState.Draft)
            {
                return BadRequest(new { error = $"Can only update Draft submissions. Current state: {package.State}" });
            }

            package.ActivityState = request.State;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} state updated to {State} by user {UserId}", id, request.State, userId);

            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error patching submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while updating the submission" });
        }
    }

    /// <summary>
    /// Get detailed information about a specific submission including documents, validation, confidence scores, and recommendations
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Complete submission details with all related data</returns>
    /// <response code="200">Returns submission details</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="404">Not found - submission does not exist or user does not have access</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(SubmissionDetailResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetSubmission(Guid id, CancellationToken cancellationToken)
    {
        try
        {
            // Try both claim types for compatibility
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
            {
                return Unauthorized(new { error = "User ID not found in token" });
            }
            
            var userId = Guid.Parse(userIdClaim);
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value ?? User.FindFirst("role")?.Value;

            var query = _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.ConfidenceScore)
                .Include(p => p.Recommendation)
                .Include(p => p.SubmittedBy)
                .Include(p => p.Teams)
                    .ThenInclude(c => c.Photos)
                .Include(p => p.CostSummary)
                .Include(p => p.ActivitySummary)
                .Include(p => p.EnquiryDocument)
                .Include(p => p.RequestApprovalHistory)
                .AsSplitQuery()
                .AsQueryable();

            // Agency users can only see submissions belonging to their agency
            if (userRole == "Agency")
            {
                var agencyId = await ResolveUserAgencyIdAsync(userId, cancellationToken);
                if (agencyId == null)
                {
                    return NotFound(new { error = "Submission not found" });
                }
                query = query.Where(p => p.AgencyId == agencyId.Value);
            }
            else if (userRole == "ASM")
            {
                // ASM/Circle Head users can only see FAPs whose ActivityState matches their assigned states
                var assignedStates = await ResolveAssignedStatesAsync(userId, cancellationToken);
                if (assignedStates == null)
                {
                    return NotFound(new { error = "Submission not found" });
                }
                query = query.Where(p => p.ActivityState != null && assignedStates.Contains(p.ActivityState));
            }
            else if (userRole == "RA")
            {
                // RA users can only see FAPs whose ActivityState matches their assigned states
                var assignedStates = await ResolveRAAssignedStatesAsync(userId, cancellationToken);
                if (assignedStates == null)
                {
                    return NotFound(new { error = "Submission not found" });
                }
                query = query.Where(p => p.ActivityState != null && assignedStates.Contains(p.ActivityState));
            }

            var package = await query.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                _logger.LogWarning("Submission not found: {Id}", id);
                return NotFound(new { error = "Submission not found" });
            }

            _logger.LogInformation("Retrieved submission {Id} successfully", id);

            // Get approval history for review fields
            var asmApproval = package.RequestApprovalHistory
                .Where(h => h.ApproverRole == Domain.Enums.UserRole.ASM)
                .OrderByDescending(h => h.ActionDate)
                .FirstOrDefault();
            var raApproval = package.RequestApprovalHistory
                .Where(h => h.ApproverRole == Domain.Enums.UserRole.RA)
                .OrderByDescending(h => h.ActionDate)
                .FirstOrDefault();

            var response = new SubmissionDetailResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                CreatedAt = package.CreatedAt,
                UpdatedAt = package.UpdatedAt,
                ASMReviewedAt = asmApproval?.ActionDate,
                ASMReviewNotes = asmApproval?.Comments,
                HQReviewedAt = raApproval?.ActionDate,
                HQReviewNotes = raApproval?.Comments,
                ReviewedAt = asmApproval?.ActionDate,
                ReviewNotes = asmApproval?.Comments,
                Documents = BuildDocumentDtos(package),
                Campaigns = package.Teams.Where(c => !c.IsDeleted).Select(c => new CampaignDto
                {
                    Id = c.Id,
                    CampaignName = c.CampaignName,
                    TeamCode = c.TeamCode,
                    StartDate = c.StartDate,
                    EndDate = c.EndDate,
                    WorkingDays = c.WorkingDays,
                    DealershipName = c.DealershipName,
                    DealershipAddress = c.DealershipAddress,
                    TotalCost = package.CostSummary?.TotalCost,
                    CostSummaryFileName = package.CostSummary?.FileName,
                    CostSummaryBlobUrl = package.CostSummary?.BlobUrl,
                    ActivitySummaryFileName = package.ActivitySummary?.FileName,
                    ActivitySummaryBlobUrl = package.ActivitySummary?.BlobUrl,
                    Photos = c.Photos.Where(p2 => !p2.IsDeleted).OrderBy(p2 => p2.DisplayOrder).Select(p2 => new CampaignPhotoDto
                    {
                        Id = p2.Id,
                        FileName = p2.FileName,
                        BlobUrl = p2.BlobUrl,
                        Caption = p2.Caption
                    }).ToList()
                }).ToList(),
                ValidationResult = package.ValidationResult != null ? new ValidationResultDto
                {
                    AllValidationsPassed = package.ValidationResult.AllValidationsPassed,
                    FailureReason = package.ValidationResult.FailureReason
                } : null,
                ConfidenceScore = package.ConfidenceScore != null ? new ConfidenceScoreDto
                {
                    OverallConfidence = package.ConfidenceScore.OverallConfidence,
                    PoConfidence = package.ConfidenceScore.PoConfidence,
                    InvoiceConfidence = package.ConfidenceScore.InvoiceConfidence,
                    CostSummaryConfidence = package.ConfidenceScore.CostSummaryConfidence,
                    ActivityConfidence = package.ConfidenceScore.ActivityConfidence,
                    PhotosConfidence = package.ConfidenceScore.PhotosConfidence
                } : null,
                Recommendation = package.Recommendation != null ? new RecommendationDto
                {
                    Type = package.Recommendation.Type.ToString(),
                    Evidence = package.Recommendation.Evidence
                } : null,
                CurrentStep = package.CurrentStep,
                SubmissionNumber = package.SubmissionNumber,
                AssignedCircleHeadUserId = package.AssignedCircleHeadUserId,
                ActivityState = package.ActivityState,
                SelectedPOId = package.SelectedPOId
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting submission {Id}. Exception: {Message}, StackTrace: {StackTrace}", 
                id, ex.Message, ex.StackTrace);
            return StatusCode(500, new { 
                error = "An error occurred while retrieving the submission",
                details = ex.Message,
                innerException = ex.InnerException?.Message
            });
        }
    }

    /// <summary>
    /// Get enhanced validation report for a submission (ASM and RA roles only)
    /// </summary>
    /// <param name="id">Submission package ID</param>
    /// <param name="enhancedValidationReportService">Enhanced validation report service</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Enhanced validation report with detailed evidence and recommendations</returns>
    /// <response code="200">Returns enhanced validation report</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - ASM or RA role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("{id}/validation-report")]
    [Authorize(Roles = "ASM,HQ")]
    [ProducesResponseType(typeof(EnhancedValidationReportDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetValidationReport(
        Guid id,
        [FromServices] IEnhancedValidationReportService enhancedValidationReportService,
        CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Generating enhanced validation report for package {PackageId}", id);

            var report = await enhancedValidationReportService.GenerateReportAsync(id, cancellationToken);

            return Ok(report);
        }
        catch (Domain.Exceptions.NotFoundException ex)
        {
            _logger.LogWarning(ex, "Package {PackageId} not found", id);
            return NotFound(new { error = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating validation report for package {PackageId}", id);
            return StatusCode(500, new { error = "An error occurred while generating the validation report" });
        }
    }

    /// <summary>
    /// List submissions with filtering and pagination (Agency users see only their own submissions)
    /// </summary>
    /// <param name="state">Optional filter by package state (Uploaded, PendingASMApproval, PendingHQApproval, Approved, etc.)</param>
    /// <param name="page">Page number for pagination (default: 1)</param>
    /// <param name="pageSize">Number of items per page (default: 20, max: 100)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Paginated list of submissions with summary information</returns>
    /// <response code="200">Returns paginated submission list</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="500">Internal server error</response>
    [HttpGet]
    [ProducesResponseType(typeof(SubmissionListResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> ListSubmissions(
        [FromQuery] string? state = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? throw new System.UnauthorizedAccessException());
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            
            _logger.LogInformation("ListSubmissions - UserId: {UserId}, Role: {Role}", userId, userRole);

            var query = _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.ConfidenceScore)
                .Include(p => p.Teams.Where(c => !c.IsDeleted))
                    .ThenInclude(c => c.Photos.Where(ph => !ph.IsDeleted))
                .AsSplitQuery()
                .AsQueryable();

            // Agency users can only see submissions belonging to their agency
            if (userRole == "Agency" || userRole == "0")
            {
                var agencyId = await ResolveUserAgencyIdAsync(userId, cancellationToken);
                if (agencyId == null)
                {
                    _logger.LogWarning("Agency user {UserId} has no associated agency", userId);
                    return Ok(new SubmissionListResponse { Total = 0, Page = page, PageSize = pageSize, Items = new List<SubmissionListItemDto>() });
                }
                _logger.LogInformation("Filtering submissions for Agency {AgencyId} (user: {UserId})", agencyId, userId);
                query = query.Where(p => p.AgencyId == agencyId.Value);
            }
            else if (userRole == "ASM")
            {
                // ASM/Circle Head users see only FAPs whose ActivityState matches their assigned states via StateMapping
                var assignedStates = await ResolveAssignedStatesAsync(userId, cancellationToken);
                if (assignedStates == null)
                {
                    _logger.LogWarning("ASM user {UserId} has no assigned states in StateMapping", userId);
                    return Ok(new SubmissionListResponse { Total = 0, Page = page, PageSize = pageSize, Items = new List<SubmissionListItemDto>() });
                }
                _logger.LogInformation("Filtering submissions for ASM {UserId} with assigned states: {States}", userId, string.Join(", ", assignedStates));
                query = query.Where(p => p.ActivityState != null && assignedStates.Contains(p.ActivityState));
            }
            else if (userRole == "RA")
            {
                // RA users see only FAPs whose ActivityState matches their assigned states via StateMapping.RAUserId
                var assignedStates = await ResolveRAAssignedStatesAsync(userId, cancellationToken);
                if (assignedStates == null)
                {
                    _logger.LogWarning("RA user {UserId} has no assigned states in StateMapping", userId);
                    return Ok(new SubmissionListResponse { Total = 0, Page = page, PageSize = pageSize, Items = new List<SubmissionListItemDto>() });
                }
                _logger.LogInformation("Filtering submissions for RA {UserId} with assigned states: {States}", userId, string.Join(", ", assignedStates));
                query = query.Where(p => p.ActivityState != null && assignedStates.Contains(p.ActivityState));
            }
            else
            {
                _logger.LogInformation("Showing all submissions for role: {Role}", userRole);
            }

            // Filter by state if provided
            if (!string.IsNullOrEmpty(state) && Enum.TryParse<PackageState>(state, true, out var packageState))
            {
                query = query.Where(p => p.State == packageState);
            }

            // Order by creation date descending
            query = query.OrderByDescending(p => p.CreatedAt);

            // Pagination
            var total = await query.CountAsync(cancellationToken);
            
            _logger.LogInformation("Total submissions found: {Total}", total);
            
            var packages = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            var items = packages.Select(p =>
            {
                // Extract invoice data from Invoices (linked to PO)
                var firstInvoice = p.Invoices
                    .Where(i => !i.IsDeleted)
                    .FirstOrDefault();
                
                string? invoiceNumber = firstInvoice?.InvoiceNumber;
                decimal? invoiceAmount = firstInvoice?.TotalAmount;

                // Calculate total invoice amount across all invoices
                var totalInvoiceAmount = p.Invoices
                    .Where(i => !i.IsDeleted && i.TotalAmount != null && i.TotalAmount > 0)
                    .Sum(i => i.TotalAmount ?? 0);
                
                if (totalInvoiceAmount > 0)
                    invoiceAmount = totalInvoiceAmount;

                // Extract PO data from dedicated PO entity
                string? poNumber = p.PO?.PONumber;
                decimal? poAmount = p.PO?.TotalAmount;

                // Fallback: try ExtractedDataJson if typed fields are empty
                if (p.PO != null && string.IsNullOrEmpty(poNumber) && !string.IsNullOrEmpty(p.PO.ExtractedDataJson))
                {
                    try
                    {
                        var poData = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(p.PO.ExtractedDataJson);
                        
                        if (poData.TryGetProperty("PONumber", out var poNum))
                            poNumber = poNum.GetString();
                        else if (poData.TryGetProperty("poNumber", out var poNum2))
                            poNumber = poNum2.GetString();

                        if (poAmount == null || poAmount == 0)
                        {
                            if (poData.TryGetProperty("TotalAmount", out var amt) && amt.ValueKind == System.Text.Json.JsonValueKind.Number)
                                poAmount = amt.GetDecimal();
                            else if (poData.TryGetProperty("totalAmount", out var amt2) && amt2.ValueKind == System.Text.Json.JsonValueKind.Number)
                                poAmount = amt2.GetDecimal();
                        }
                    }
                    catch { }
                }

                // Count documents: PO + invoices + team photos
                var campaignPhotoCount = p.Teams.Where(c => !c.IsDeleted).SelectMany(c => c.Photos).Count(ph => !ph.IsDeleted);
                var totalDocCount = (p.PO != null ? 1 : 0) + p.Invoices.Count(i => !i.IsDeleted) + campaignPhotoCount;

                return new SubmissionListItemDto
                {
                    Id = p.Id,
                    State = p.State.ToString(),
                    CreatedAt = p.CreatedAt,
                    UpdatedAt = p.UpdatedAt,
                    DocumentCount = totalDocCount,
                    InvoiceNumber = invoiceNumber,
                    InvoiceAmount = invoiceAmount,
                    PoNumber = poNumber,
                    PoAmount = poAmount,
                    OverallConfidence = p.ConfidenceScore != null ? (decimal?)p.ConfidenceScore.OverallConfidence : null,
                    SubmissionNumber = p.SubmissionNumber
                };
            }).ToList();

            var response = new SubmissionListResponse
            {
                Total = total,
                Page = page,
                PageSize = pageSize,
                Items = items
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing submissions");
            return StatusCode(500, new { error = "An error occurred while listing submissions" });
        }
    }

    /// <summary>
    /// Approve a submission at ASM level and move to HQ approval queue (ASM role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Optional approval notes</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Submission approved by ASM, moved to HQ approval</response>
    /// <response code="400">Bad request - submission not in correct state</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - ASM role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/asm-approve")]
    [Authorize(Roles = "ASM")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> ASMApproveSubmission(
        Guid id,
        [FromBody] ApproveSubmissionRequest? request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Allow approval from PendingASM or RARejected states
            if (package.State != PackageState.PendingASM && 
                package.State != PackageState.RARejected)
            {
                return BadRequest(new { error = $"Submission is not in a state that can be approved by ASM. Current state: {package.State}" });
            }

            package.State = PackageState.PendingRA;

            // Auto-assign RA user based on submission's activity state
            var raUserId = await _raAssignmentService.AssignAsync(package.ActivityState ?? string.Empty, cancellationToken);
            package.AssignedRAUserId = raUserId;
            if (raUserId == null)
            {
                _logger.LogWarning("No RA user found for state '{ActivityState}' on submission {Id}. Manual RA assignment required.", package.ActivityState, id);
            }

            // Record approval in RequestApprovalHistory
            var approvalHistory = new Domain.Entities.RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                ApproverId = userId,
                ApproverRole = Domain.Enums.UserRole.ASM,
                Action = Domain.Enums.ApprovalAction.Approved,
                Comments = request?.Notes ?? "Approved by ASM",
                ActionDate = DateTime.UtcNow,
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.RequestApprovalHistories.Add(approvalHistory);
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Push SubmissionStatusChanged event via SignalR
            await _submissionNotificationService.SendSubmissionStatusChangedAsync(
                id,
                new { submissionId = id, newStatus = PackageState.PendingRA.ToString(), assignedTo = (Guid?)null },
                cancellationToken);

            // Send circleHead_approved email to agency
            _ = Task.Run(async () =>
            {
                var result = await _emailAgent.SendCircleHeadApprovedEmailAsync(id, CancellationToken.None);
                if (!result.Success)
                    _logger.LogWarning("circleHead_approved email failed for package {PackageId}: {Error}", id, result.ErrorMessage);
            });

            _logger.LogInformation("Submission {Id} approved by ASM {UserId}, moved to RA approval", id, userId);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Approved by ASM, pending RA approval"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error approving submission {Id} by ASM", id);
            return StatusCode(500, new { error = "An error occurred while approving the submission" });
        }
    }

    /// <summary>
    /// Reject a submission at ASM level and send back to Agency (ASM role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Rejection reason (required)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Submission rejected by ASM</response>
    /// <response code="400">Bad request - submission not in correct state</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - ASM role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/asm-reject")]
    [Authorize(Roles = "ASM")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> ASMRejectSubmission(
        Guid id,
        [FromBody] RejectSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Allow rejection from PendingASM or RARejected states
            if (package.State != PackageState.PendingASM && 
                package.State != PackageState.RARejected)
            {
                return BadRequest(new { error = $"Submission is not in a state that can be rejected by ASM. Current state: {package.State}" });
            }

            package.State = PackageState.ASMRejected;
            // Record rejection in RequestApprovalHistory
            var rejectionHistory = new Domain.Entities.RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                ApproverId = userId,
                ApproverRole = Domain.Enums.UserRole.ASM,
                Action = Domain.Enums.ApprovalAction.Rejected,
                Comments = request.Reason,
                ActionDate = DateTime.UtcNow,
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.RequestApprovalHistories.Add(rejectionHistory);
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Push SubmissionStatusChanged event via SignalR
            await _submissionNotificationService.SendSubmissionStatusChangedAsync(
                id,
                new { submissionId = id, newStatus = PackageState.ASMRejected.ToString(), assignedTo = (Guid?)null },
                cancellationToken);

            // Send circleHead_rejected email to agency
            _ = Task.Run(async () =>
            {
                var result = await _emailAgent.SendCircleHeadRejectedEmailAsync(id, request.Reason, CancellationToken.None);
                if (!result.Success)
                    _logger.LogWarning("circleHead_rejected email failed for package {PackageId}: {Error}", id, result.ErrorMessage);
            });

            _logger.LogInformation("Submission {Id} rejected by ASM {UserId} with reason: {Reason}", id, userId, request.Reason);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Rejected by ASM"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error rejecting submission {Id} by ASM", id);
            return StatusCode(500, new { error = "An error occurred while rejecting the submission" });
        }
    }

    /// <summary>
    /// Approve a submission at HQ level - final approval (HQ role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Optional approval notes</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Submission approved by HQ - final approval</response>
    /// <response code="400">Bad request - submission not in correct state</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/hq-approve")]
    [Authorize(Roles = "HQ")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> HQApproveSubmission(
        Guid id,
        [FromBody] ApproveSubmissionRequest? request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            if (package.State != PackageState.PendingRA)
            {
                return BadRequest(new { error = $"Submission is not in pending RA approval state. Current state: {package.State}" });
            }

            package.State = PackageState.Approved;
            // Record approval in RequestApprovalHistory
            var approvalHistory = new Domain.Entities.RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                ApproverId = userId,
                ApproverRole = Domain.Enums.UserRole.RA,
                Action = Domain.Enums.ApprovalAction.Approved,
                Comments = request?.Notes ?? "Approved by RA",
                ActionDate = DateTime.UtcNow,
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.RequestApprovalHistories.Add(approvalHistory);
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Push SubmissionStatusChanged event via SignalR
            await _submissionNotificationService.SendSubmissionStatusChangedAsync(
                id,
                new { submissionId = id, newStatus = PackageState.Approved.ToString(), assignedTo = (Guid?)null },
                cancellationToken);

            // Send ra_approved email to agency
            _ = Task.Run(async () =>
            {
                var result = await _emailAgent.SendRaApprovedEmailAsync(id, CancellationToken.None);
                if (!result.Success)
                    _logger.LogWarning("ra_approved email failed for package {PackageId}: {Error}", id, result.ErrorMessage);
            });

            _logger.LogInformation("Submission {Id} approved by RA {UserId} - final approval", id, userId);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Final approval by RA"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error approving submission {Id} by HQ", id);
            return StatusCode(500, new { error = "An error occurred while approving the submission" });
        }
    }

    /// <summary>
    /// Reject a submission at HQ level and send back to ASM (HQ role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Rejection reason (required)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Submission rejected by HQ, sent back to ASM</response>
    /// <response code="400">Bad request - submission not in correct state</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - HQ role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/hq-reject")]
    [Authorize(Roles = "HQ")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> HQRejectSubmission(
        Guid id,
        [FromBody] RejectSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            if (package.State != PackageState.PendingRA)
            {
                return BadRequest(new { error = $"Submission is not in pending RA approval state. Current state: {package.State}" });
            }

            package.State = PackageState.RARejected;
            // Record rejection in RequestApprovalHistory
            var rejectionHistory = new Domain.Entities.RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                ApproverId = userId,
                ApproverRole = Domain.Enums.UserRole.RA,
                Action = Domain.Enums.ApprovalAction.Rejected,
                Comments = request.Reason,
                ActionDate = DateTime.UtcNow,
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.RequestApprovalHistories.Add(rejectionHistory);
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Push SubmissionStatusChanged event via SignalR
            await _submissionNotificationService.SendSubmissionStatusChangedAsync(
                id,
                new { submissionId = id, newStatus = PackageState.RARejected.ToString(), assignedTo = (Guid?)null },
                cancellationToken);

            // Send ra_rejected email to agency
            _ = Task.Run(async () =>
            {
                var result = await _emailAgent.SendRaRejectedEmailAsync(id, request.Reason, CancellationToken.None);
                if (!result.Success)
                    _logger.LogWarning("ra_rejected email failed for package {PackageId}: {Error}", id, result.ErrorMessage);
            });

            _logger.LogInformation("Submission {Id} rejected by HQ {UserId} with reason: {Reason}", id, userId, request.Reason);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Rejected by RA, sent back to Agency"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error rejecting submission {Id} by HQ", id);
            return StatusCode(500, new { error = "An error occurred while rejecting the submission" });
        }
    }

    /// <summary>
    /// Legacy approve endpoint - redirects to ASM approve for backward compatibility (ASM role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    [HttpPatch("{id}/approve")]
    [Authorize(Roles = "ASM")]
    public async Task<IActionResult> ApproveSubmission(Guid id, CancellationToken cancellationToken)
    {
        // Redirect to ASM approve
        return await ASMApproveSubmission(id, null, cancellationToken);
    }

    /// <summary>
    /// Legacy reject endpoint - redirects to ASM reject for backward compatibility (ASM role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Rejection reason</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    [HttpPatch("{id}/reject")]
    [Authorize(Roles = "ASM")]
    public async Task<IActionResult> RejectSubmission(
        Guid id,
        [FromBody] RejectSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        // Redirect to ASM reject
        return await ASMRejectSubmission(id, request, cancellationToken);
    }

    /// <summary>
    /// Agency resubmits a rejected package for review after making corrections (Agency role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status with resubmission count</returns>
    /// <response code="200">Package resubmitted successfully and workflow triggered</response>
    /// <response code="400">Bad request - can only resubmit packages rejected by ASM</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - Agency role required or user does not own package</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/resubmit")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> ResubmitPackage(
        Guid id,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Can only resubmit if rejected by ASM or rejected by RA
            if (package.State != PackageState.ASMRejected && 
                package.State != PackageState.RARejected)
            {
                return BadRequest(new { error = $"Can only resubmit packages rejected by ASM or RA. Current state: {package.State}" });
            }

            // Verify the package belongs to the user
            if (package.SubmittedByUserId != userId)
            {
                return Forbid();
            }

            // Track resubmission via VersionNumber
            package.VersionNumber += 1;
            
            // Reset to uploaded state to trigger workflow
            package.State = PackageState.Uploaded;
            // Record resubmission in RequestApprovalHistory
            var resubmitHistory = new Domain.Entities.RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                ApproverId = userId,
                ApproverRole = Domain.Enums.UserRole.Agency,
                Action = Domain.Enums.ApprovalAction.Resubmitted,
                Comments = "Resubmitted by Agency",
                ActionDate = DateTime.UtcNow,
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.RequestApprovalHistories.Add(resubmitHistory);
            package.UpdatedAt = DateTime.UtcNow;
            
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Package {Id} resubmitted by Agency user {UserId} (Version #{Version})", 
                id, userId, package.VersionNumber);

            // Trigger workflow processing
            try
            {
                await _orchestrator.ProcessSubmissionAsync(id, cancellationToken);
                _logger.LogInformation("Workflow triggered for resubmitted package {Id}", id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error triggering workflow for resubmitted package {Id}", id);
                // Don't fail the resubmit if workflow fails - it can be triggered manually
            }

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                ResubmissionCount = package.VersionNumber - 1,
                Message = "Package resubmitted successfully and workflow triggered"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resubmitting package {Id}", id);
            return StatusCode(500, new { error = "An error occurred while resubmitting the package" });
        }
    }

    /// <summary>
    /// ASM resubmits a package to HQ after HQ rejection with additional notes (ASM role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Resubmission notes explaining changes or clarifications (required)</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status with HQ resubmission count</returns>
    /// <response code="200">Package resubmitted to HQ successfully</response>
    /// <response code="400">Bad request - can only resubmit packages rejected by HQ</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - ASM role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/resubmit-to-hq")]
    [Authorize(Roles = "ASM")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> ResubmitToHQ(
        Guid id,
        [FromBody] ResubmitToHQRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Can only resubmit if rejected by RA
            if (package.State != PackageState.RARejected)
            {
                return BadRequest(new { error = $"Can only resubmit packages rejected by RA. Current state: {package.State}" });
            }

            // Track HQ resubmission via VersionNumber
            package.VersionNumber += 1;
            
            // Move back to pending RA approval
            package.State = PackageState.PendingRA;
            
            // Record resubmission in RequestApprovalHistory
            var resubmitHistory = new Domain.Entities.RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                ApproverId = userId,
                ApproverRole = Domain.Enums.UserRole.ASM,
                Action = Domain.Enums.ApprovalAction.Resubmitted,
                Comments = request.Notes,
                ActionDate = DateTime.UtcNow,
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.RequestApprovalHistories.Add(resubmitHistory);
            
            package.UpdatedAt = DateTime.UtcNow;
            
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Package {Id} resubmitted to RA by ASM user {UserId} (Version #{Version})", 
                id, userId, package.VersionNumber);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                HQResubmissionCount = package.VersionNumber - 1,
                Message = "Package resubmitted to RA successfully"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resubmitting package {Id} to HQ", id);
            return StatusCode(500, new { error = "An error occurred while resubmitting to HQ" });
        }
    }

    /// <summary>
    /// ASM sends an RA-rejected package back to Agency for corrections (ASM role only)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Reason for sending back to Agency</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Package sent back to Agency</response>
    /// <response code="400">Bad request - can only send back packages rejected by HQ</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - ASM role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/send-back-to-agency")]
    [Authorize(Roles = "ASM")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> SendBackToAgency(
        Guid id,
        [FromBody] RejectSubmissionRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());

            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            if (package.State != PackageState.RARejected)
            {
                return BadRequest(new { error = $"Can only send back packages rejected by RA. Current state: {package.State}" });
            }

            // Move to ASMRejected so Agency can edit and resubmit
            package.State = PackageState.ASMRejected;
            // Record in RequestApprovalHistory
            var sendBackHistory = new Domain.Entities.RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = package.Id,
                ApproverId = userId,
                ApproverRole = Domain.Enums.UserRole.ASM,
                Action = Domain.Enums.ApprovalAction.Rejected,
                Comments = $"Sent back to Agency: {request.Reason}",
                ActionDate = DateTime.UtcNow,
                VersionNumber = package.VersionNumber,
                CreatedAt = DateTime.UtcNow
            };
            _context.RequestApprovalHistories.Add(sendBackHistory);

            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Package {Id} sent back to Agency by ASM {UserId}. Reason: {Reason}",
                id, userId, request.Reason);

            return Ok(new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Package sent back to Agency for corrections"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending package {Id} back to Agency", id);
            return StatusCode(500, new { error = "An error occurred while sending back to Agency" });
        }
    }

    /// <summary>
    /// Request document re-upload from Agency user (ASM role only, deprecated endpoint)
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">List of fields/documents that need to be reuploaded</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Re-upload requested</response>
    /// <response code="400">Bad request - submission not in correct state</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - ASM role required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/request-reupload")]
    [Authorize(Roles = "ASM")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> RequestReupload(
        Guid id,
        [FromBody] RequestReuploadRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            if (package.State != PackageState.PendingASM)
            {
                return BadRequest(new { error = "Submission is not in pending approval state" });
            }

            package.State = PackageState.ASMRejected;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Re-upload requested for submission {Id}, Fields: {Fields}", 
                id, string.Join(", ", request.Fields));

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Re-upload requested"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error requesting reupload for submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while requesting reupload" });
        }
    }

    /// <summary>
    /// Submit/finalize a package for AI processing workflow (Agency role only).
    /// For Draft packages (conversational flow): validates completeness, generates submission number,
    /// auto-assigns CIRCLE HEAD, transitions Draft → Uploaded, and queues workflow.
    /// For Uploaded packages (legacy flow): validates minimum docs and queues workflow.
    /// </summary>
    /// <param name="packageId">Unique identifier of the package to submit</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Submission status indicating package is queued for processing</returns>
    /// <response code="200">Package submitted for processing</response>
    /// <response code="400">Bad request - missing required documents or package not in correct state</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - Agency role required or user does not own package</response>
    /// <response code="404">Not found - package does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPost("{packageId}/submit")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> SubmitPackage(Guid packageId, CancellationToken cancellationToken)
    {
        try
        {
            // Try both claim types for compatibility
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
            {
                _logger.LogWarning("User ID claim not found in token");
                return Unauthorized(new { error = "User ID not found in token" });
            }

            var userId = Guid.Parse(userIdClaim);
            _logger.LogInformation("User {UserId} submitting package {PackageId}", userId, packageId);

            var package = await _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.Teams.Where(c => !c.IsDeleted))
                    .ThenInclude(c => c.Photos.Where(ph => !ph.IsDeleted))
                .Include(p => p.CostSummary)
                .Include(p => p.ActivitySummary)
                .Include(p => p.EnquiryDocument)
                .AsSplitQuery()
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogWarning("Package {PackageId} not found", packageId);
                return NotFound(new { error = "Package not found" });
            }

            // Verify ownership
            if (package.SubmittedByUserId != userId)
            {
                _logger.LogWarning("User {UserId} attempted to submit package {PackageId} owned by {OwnerId}", 
                    userId, packageId, package.SubmittedByUserId);
                return Forbid();
            }

            // State enforcement: only Draft or Uploaded can be submitted
            if (package.State != PackageState.Draft && package.State != PackageState.Uploaded)
            {
                _logger.LogWarning("Package {PackageId} is in state {State}, cannot submit", packageId, package.State);
                return BadRequest(new { error = $"Package is already in {package.State} state. Only Draft or Uploaded packages can be submitted." });
            }

            // Verify minimum required documents
            var hasPO = package.PO != null;
            var hasInvoice = package.Invoices.Any(i => !i.IsDeleted);
            var hasCostSummary = package.CostSummary != null;

            var invoiceCount = package.Invoices.Count(i => !i.IsDeleted);
            _logger.LogInformation("Package {PackageId} document check: PO={HasPO}, Invoice={HasInvoice} (InvoiceCount={InvoiceCount}), CostSummary={HasCostSummary}", 
                packageId, hasPO, hasInvoice, invoiceCount, hasCostSummary);

            if (!hasPO)
            {
                return BadRequest(new { error = "PO document is required" });
            }

            if (!hasInvoice)
            {
                return BadRequest(new { error = "Invoice document is required" });
            }

            if (!hasCostSummary)
            {
                return BadRequest(new { error = "Cost Summary document is required" });
            }

            // Conversational flow (Draft) additional validations
            if (package.State == PackageState.Draft)
            {
                // Activity Summary is mandatory
                if (package.ActivitySummary == null)
                {
                    return BadRequest(new { error = "Activity Summary document is required" });
                }

                // Enquiry Dump is mandatory
                if (package.EnquiryDocument == null)
                {
                    return BadRequest(new { error = "Enquiry Dump document is required" });
                }

                // At least 1 team with at least 3 photos
                var teamsWithPhotos = package.Teams.Where(t => t.Photos.Count(p => !p.IsDeleted) >= 3).ToList();
                if (!teamsWithPhotos.Any())
                {
                    return BadRequest(new { error = "At least one team with a minimum of 3 photos is required" });
                }

                // State must be set
                if (string.IsNullOrEmpty(package.ActivityState))
                {
                    return BadRequest(new { error = "Activity state/region must be set before submission" });
                }

                // Generate submission number
                var submissionNumber = await _submissionNumberService.GenerateAsync(cancellationToken);
                package.SubmissionNumber = submissionNumber;

                // Auto-assign CIRCLE HEAD
                var circleHeadUserId = await _circleHeadAssignmentService.AssignAsync(package.ActivityState, cancellationToken);
                package.AssignedCircleHeadUserId = circleHeadUserId;

                if (circleHeadUserId == null)
                {
                    _logger.LogWarning("No CIRCLE HEAD found for state {State}, flagging for manual assignment", package.ActivityState);
                    _context.AuditLogs.Add(new Domain.Entities.AuditLog
                    {
                        Id = Guid.NewGuid(),
                        UserId = userId,
                        Action = "ManualAssignmentRequired",
                        EntityType = "DocumentPackage",
                        EntityId = package.Id,
                        NewValuesJson = JsonSerializer.Serialize(new { State = package.ActivityState, Reason = "No CIRCLE HEAD found" }),
                        IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                        UserAgent = Request.Headers.UserAgent.ToString(),
                        CreatedAt = DateTime.UtcNow
                    });
                }

                // Transition Draft → Uploaded (triggers workflow)
                package.State = PackageState.Uploaded;
                package.CurrentStep = 10; // Submitted step
            }

            var docCount = (package.PO != null ? 1 : 0) + package.Invoices.Count(i => !i.IsDeleted) + (package.CostSummary != null ? 1 : 0);
            _logger.LogInformation("Submitting package {PackageId} for processing with {Count} documents", 
                packageId, docCount);

            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Push SubmissionStatusChanged event via SignalR
            await _submissionNotificationService.SendSubmissionStatusChangedAsync(
                packageId,
                new
                {
                    submissionId = packageId,
                    newStatus = package.State.ToString(),
                    assignedTo = package.AssignedCircleHeadUserId
                },
                cancellationToken);

            // Queue workflow for background processing
            await _backgroundQueue.QueueWorkflowAsync(packageId);
            
            _logger.LogInformation("Package {PackageId} queued for background processing", packageId);

            var response = new SubmissionStatusResponse
            {
                Id = packageId,
                State = package.State.ToString(),
                DocumentCount = docCount,
                Status = "Queued for processing",
                Message = package.SubmissionNumber != null 
                    ? $"Package submitted successfully. Submission number: {package.SubmissionNumber}" 
                    : "Package submitted for processing"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error submitting package {PackageId}", packageId);
            return StatusCode(500, new { error = "An error occurred while submitting the package" });
        }
    }

    /// <summary>
    /// Manually move submission to PendingApproval state for testing without Azure services
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Submission moved to PendingApproval</response>
    /// <response code="400">Bad request - submission not in correct state</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/move-to-pending")]
    [Authorize]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> MoveToPendingApproval(Guid id, CancellationToken cancellationToken)
    {
        try
        {
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Only allow moving from Uploaded state
            if (package.State != PackageState.Uploaded)
            {
                return BadRequest(new { error = $"Cannot move submission from {package.State} to PendingASM" });
            }

            package.State = PackageState.PendingASM;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} manually moved to PendingASM", id);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Moved to PendingASM"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error moving submission {Id} to pending approval", id);
            return StatusCode(500, new { error = "An error occurred while updating submission state" });
        }
    }

    /// <summary>
    /// Update campaign and dealership details for a submission
    /// </summary>
    /// <param name="id">Unique identifier of the submission</param>
    /// <param name="request">Campaign and dealership data to update</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Updated submission status</returns>
    /// <response code="200">Campaign data updated successfully</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="404">Not found - submission does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPatch("{id}/campaign-dates")]
    [HttpPatch("{id}/campaign-data")] // Alias route
    [Authorize] // Allow any authenticated user
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> UpdateCampaignData(Guid id, [FromBody] UpdateCampaignDataRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var package = await _context.DocumentPackages
                .Include(p => p.Teams)
                .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);
            
            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Update first team's campaign fields (or create a team if none exists)
            var team = package.Teams.FirstOrDefault();
            if (team == null)
            {
                team = new Domain.Entities.Teams
                {
                    Id = Guid.NewGuid(),
                    PackageId = id,
                    CreatedAt = DateTime.UtcNow
                };
                _context.Teams.Add(team);
            }

            // Update campaign fields on team
            if (request.CampaignStartDate.HasValue)
                team.StartDate = request.CampaignStartDate.Value;
            if (request.CampaignEndDate.HasValue)
                team.EndDate = request.CampaignEndDate.Value;
            if (request.CampaignWorkingDays.HasValue)
                team.WorkingDays = request.CampaignWorkingDays.Value;

            // Update dealership fields on team
            if (!string.IsNullOrEmpty(request.DealershipName))
                team.DealershipName = request.DealershipName;
            if (!string.IsNullOrEmpty(request.DealershipAddress))
                team.DealershipAddress = request.DealershipAddress;
            if (!string.IsNullOrEmpty(request.GpsLocation))
                team.GPSLocation = request.GpsLocation;

            team.UpdatedAt = DateTime.UtcNow;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Campaign/dealership data updated for submission {Id}: Dealership={Dealership}, GPS={GPS}",
                id, request.DealershipName, request.GpsLocation);

            return Ok(new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Campaign and dealership data updated successfully"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating campaign data for submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while updating campaign data" });
        }
    }

    /// <summary>
    /// Queue package for background processing (fast - returns immediately)
    /// </summary>
    /// <param name="packageId">Unique identifier of the package to process</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Acknowledgment that processing has been queued</returns>
    [HttpPost("{packageId}/process-async")]
    [Authorize]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status202Accepted)]
    public async Task<IActionResult> ProcessPackageAsync(Guid packageId, CancellationToken cancellationToken)
    {
        try
        {
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Package not found" });
            }

            // Queue for background processing - returns immediately
            await _backgroundQueue.QueueWorkflowAsync(packageId);
            
            _logger.LogInformation("Package {PackageId} queued for background processing", packageId);

            return Accepted(new SubmissionStatusResponse
            {
                Id = packageId,
                Success = true,
                CurrentState = package.State.ToString(),
                Message = "Submission received. Processing in background."
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error queuing package {PackageId}", packageId);
            return StatusCode(500, new { error = "An error occurred" });
        }
    }

    /// <summary>
    /// Manually trigger synchronous workflow processing for a package (for testing and debugging)
    /// </summary>
    /// <param name="packageId">Unique identifier of the package to process</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Workflow execution result with success status and current package state</returns>
    /// <response code="200">Workflow completed (check success flag and message for result)</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="404">Not found - package does not exist</response>
    /// <response code="500">Internal server error</response>
    [HttpPost("{packageId}/process-now")]
    [Authorize]
    [ProducesResponseType(typeof(SubmissionStatusResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> ProcessPackageNow(Guid packageId, CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Manual workflow trigger requested for package {PackageId}", packageId);

            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Package not found" });
            }

            _logger.LogInformation("Starting synchronous workflow for package {PackageId}", packageId);
            
            // Run workflow synchronously for testing
            var result = await _orchestrator.ProcessSubmissionAsync(packageId, cancellationToken);
            
            _logger.LogInformation("Workflow completed for package {PackageId}, Result: {Result}", packageId, result);

            // Reload package to get updated state
            package = await _context.DocumentPackages
                .Include(p => p.ConfidenceScore)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            var response = new SubmissionStatusResponse
            {
                Id = packageId,
                Success = result,
                CurrentState = package?.State.ToString() ?? "Unknown",
                Message = result ? "Workflow completed successfully" : "Workflow failed - check logs"
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing package {PackageId}", packageId);
            return StatusCode(500, new { error = "An error occurred while processing the package" });
        }
    }

    // CHANGE: Added BuildValidationDetails to show all validation checks with meaningful messages
    // CHANGE: Rewritten BuildValidationDetails to use boolean fields only (ValidationDetailsJson removed)
    /// <summary>
    /// Builds a single string showing the 6 core validation checks with pass/fail status.
    /// Detailed per-field results are available via RuleResultsJson on each ValidationResult row.
    /// </summary>
    private static string BuildValidationDetails(Domain.Entities.ValidationResult vr)
    {
        var checks = new List<string>
        {
            vr.SapVerificationPassed
                ? "SAP Verification: Pass - PO verified against SAP records"
                : "SAP Verification: Fail - PO could not be verified in SAP",

            vr.AmountConsistencyPassed
                ? "Amount Consistency: Pass - Invoice and Cost Summary amounts are consistent"
                : "Amount Consistency: Fail - Invoice and Cost Summary amounts do not match",

            vr.LineItemMatchingPassed
                ? "Line Item Matching: Pass - All PO line items found in Invoice"
                : "Line Item Matching: Fail - Some PO line items missing in Invoice",

            vr.CompletenessCheckPassed
                ? "Completeness Check: Pass - All required documents are present"
                : "Completeness Check: Fail - Some required documents are missing",

            vr.DateValidationPassed
                ? "Date Validation: Pass - All dates are valid and consistent"
                : "Date Validation: Fail - Date inconsistencies found",

            vr.VendorMatchingPassed
                ? "Vendor Matching: Pass - Vendor name matches across PO and Invoice"
                : "Vendor Matching: Fail - Vendor name mismatch between PO and Invoice",
        };

        if (!string.IsNullOrWhiteSpace(vr.FailureReason))
            checks.Add($"Failure Details: {vr.FailureReason}");

        return string.Join("; ", checks);
    }

    /// <summary>
    /// Builds a list of SubmissionDocumentDto from dedicated entity navigation properties
    /// </summary>
    /// <summary>
    /// Resolves the list of activity states assigned to the current ASM/Circle Head user via StateMapping.
    /// Returns null if the user has no state assignments.
    /// </summary>
    private async Task<List<string>?> ResolveAssignedStatesAsync(Guid userId, CancellationToken cancellationToken)
    {
        var states = await _context.StateMappings
            .AsNoTracking()
            .Where(sm => sm.CircleHeadUserId == userId && sm.IsActive)
            .Select(sm => sm.State)
            .Distinct()
            .ToListAsync(cancellationToken);

        return states.Count > 0 ? states : null;
    }

    /// <summary>
    /// Resolves the list of activity states assigned to the current RA user via StateMapping.
    /// Returns null if the user has no state assignments.
    /// </summary>
    private async Task<List<string>?> ResolveRAAssignedStatesAsync(Guid userId, CancellationToken cancellationToken)
    {
        var states = await _context.StateMappings
            .AsNoTracking()
            .Where(sm => sm.RAUserId == userId && sm.IsActive)
            .Select(sm => sm.State)
            .Distinct()
            .ToListAsync(cancellationToken);

        return states.Count > 0 ? states : null;
    }

    /// <summary>
    /// Resolves the AgencyId for the current authenticated Agency user from the database.
    /// Returns null for non-Agency roles or if the user has no associated agency.
    /// </summary>
    private async Task<Guid?> ResolveUserAgencyIdAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId && !u.IsDeleted)
            .Select(u => new { u.AgencyId })
            .FirstOrDefaultAsync(cancellationToken);

        return user?.AgencyId;
    }

    private static List<SubmissionDocumentDto> BuildDocumentDtos(Domain.Entities.DocumentPackage package)
    {
        var docs = new List<SubmissionDocumentDto>();

        if (package.PO != null)
        {
            docs.Add(new SubmissionDocumentDto
            {
                Id = package.PO.Id,
                Type = DocumentType.PO.ToString(),
                Filename = package.PO.FileName,
                BlobUrl = package.PO.BlobUrl,
                ExtractionConfidence = package.PO.ExtractionConfidence,
                ExtractedData = package.PO.ExtractedDataJson
            });
        }

        foreach (var invoice in package.Invoices.Where(i => !i.IsDeleted))
        {
            docs.Add(new SubmissionDocumentDto
            {
                Id = invoice.Id,
                Type = DocumentType.Invoice.ToString(),
                Filename = invoice.FileName,
                BlobUrl = invoice.BlobUrl,
                ExtractionConfidence = invoice.ExtractionConfidence,
                ExtractedData = invoice.ExtractedDataJson
            });
        }

        return docs;
    }
}

/// <summary>
/// Request to create a new submission
/// </summary>
/// <param name="CampaignStartDate">Campaign start date</param>
/// <param name="CampaignEndDate">Campaign end date</param>
/// <param name="CampaignWorkingDays">Number of working days (excluding weekends)</param>
public record CreateSubmissionRequest(
    DateTime? CampaignStartDate = null,
    DateTime? CampaignEndDate = null,
    int? CampaignWorkingDays = null,
    Guid? SelectedPoId = null
);

/// <summary>
/// Request to approve a submission
/// </summary>
/// <param name="Notes">Optional approval notes</param>
public record ApproveSubmissionRequest(
    [StringLength(500, ErrorMessage = "Notes cannot exceed 500 characters")]
    string? Notes
);

/// <summary>
/// Request to reject a submission
/// </summary>
/// <param name="Reason">Reason for rejection</param>
public record RejectSubmissionRequest(
    [Required(ErrorMessage = "Reason is required")]
    [StringLength(500, MinimumLength = 10, ErrorMessage = "Reason must be between 10 and 500 characters")]
    string Reason
);

/// <summary>
/// Request to resubmit to HQ
/// </summary>
/// <param name="Notes">Notes for HQ resubmission</param>
public record ResubmitToHQRequest(
    [Required(ErrorMessage = "Notes are required")]
    [StringLength(500, MinimumLength = 10, ErrorMessage = "Notes must be between 10 and 500 characters")]
    string Notes
);

/// <summary>
/// Request to request document reupload
/// </summary>
/// <param name="Fields">List of fields/documents that need to be reuploaded</param>
public record RequestReuploadRequest(
    [Required(ErrorMessage = "Fields list is required")]
    [MinLength(1, ErrorMessage = "At least one field must be specified")]
    List<string> Fields
);

/// <summary>
/// Request to update campaign and dealership data
/// </summary>
/// <param name="CampaignStartDate">Campaign start date</param>
/// <param name="CampaignEndDate">Campaign end date</param>
/// <param name="CampaignWorkingDays">Number of working days</param>
/// <param name="DealershipName">Dealership/dealer name</param>
/// <param name="DealershipAddress">Full address of the dealership</param>
/// <param name="GpsLocation">GPS coordinates of the location</param>
public record UpdateCampaignDataRequest(
    DateTime? CampaignStartDate = null,
    DateTime? CampaignEndDate = null,
    int? CampaignWorkingDays = null,
    string? DealershipName = null,
    string? DealershipAddress = null,
    string? GpsLocation = null
);
