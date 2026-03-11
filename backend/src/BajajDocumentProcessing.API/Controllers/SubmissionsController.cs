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

    public SubmissionsController(
        IApplicationDbContext context,
        IWorkflowOrchestrator orchestrator,
        IBackgroundWorkflowQueue backgroundQueue,
        ILogger<SubmissionsController> logger)
    {
        _context = context;
        _orchestrator = orchestrator;
        _backgroundQueue = backgroundQueue;
        _logger = logger;
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

            // Create document package
            var package = new Domain.Entities.DocumentPackage
            {
                Id = Guid.NewGuid(),
                SubmittedByUserId = userId,
                State = PackageState.Uploaded,
                CampaignStartDate = request.CampaignStartDate,
                CampaignEndDate = request.CampaignEndDate,
                CampaignWorkingDays = request.CampaignWorkingDays,
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
                .Include(p => p.Documents)
                .Include(p => p.ValidationResult)
                .Include(p => p.ConfidenceScore)
                .Include(p => p.Recommendation)
                .Include(p => p.SubmittedBy)
                .Include(p => p.Campaigns)
                    .ThenInclude(c => c.Invoices)
                .Include(p => p.Campaigns)
                    .ThenInclude(c => c.Photos)
                .AsSplitQuery()
                .AsQueryable();

            // Agency users can only see their own submissions
            if (userRole == "Agency")
            {
                query = query.Where(p => p.SubmittedByUserId == userId);
            }

            var package = await query.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            var response = new SubmissionDetailResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                CreatedAt = package.CreatedAt,
                UpdatedAt = package.UpdatedAt,
                ASMReviewedAt = package.ASMReviewedAt,
                ASMReviewNotes = package.ASMReviewNotes,
                HQReviewedAt = package.HQReviewedAt,
                HQReviewNotes = package.HQReviewNotes,
                ReviewedAt = package.ReviewedAt,
                ReviewNotes = package.ReviewNotes,
                Documents = package.Documents.Select(d => new SubmissionDocumentDto
                {
                    Id = d.Id,
                    Type = d.Type.ToString(),
                    Filename = d.FileName,
                    BlobUrl = d.BlobUrl,
                    ExtractionConfidence = d.ExtractionConfidence,
                    ExtractedData = d.ExtractedDataJson
                }).ToList(),
                Campaigns = package.Campaigns.Where(c => !c.IsDeleted).Select(c => new CampaignDto
                {
                    Id = c.Id,
                    CampaignName = c.CampaignName,
                    TeamCode = c.TeamCode,
                    StartDate = c.StartDate,
                    EndDate = c.EndDate,
                    WorkingDays = c.WorkingDays,
                    DealershipName = c.DealershipName,
                    DealershipAddress = c.DealershipAddress,
                    TotalCost = c.TotalCost,
                    CostSummaryFileName = c.CostSummaryFileName,
                    CostSummaryBlobUrl = c.CostSummaryBlobUrl,
                    ActivitySummaryFileName = c.ActivitySummaryFileName,
                    ActivitySummaryBlobUrl = c.ActivitySummaryBlobUrl,
                    Invoices = c.Invoices.Where(i => !i.IsDeleted).Select(i => new CampaignInvoiceDto
                    {
                        Id = i.Id,
                        InvoiceNumber = i.InvoiceNumber,
                        InvoiceDate = i.InvoiceDate,
                        VendorName = i.VendorName,
                        GSTNumber = i.GSTNumber,
                        TotalAmount = i.TotalAmount,
                        FileName = i.FileName,
                        BlobUrl = i.BlobUrl
                    }).ToList(),
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
                } : null
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while retrieving the submission" });
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
                .Include(p => p.Documents)
                .Include(p => p.ConfidenceScore)
                .Include(p => p.Campaigns.Where(c => !c.IsDeleted))
                    .ThenInclude(c => c.Invoices.Where(i => !i.IsDeleted))
                .Include(p => p.Campaigns.Where(c => !c.IsDeleted))
                    .ThenInclude(c => c.Photos.Where(ph => !ph.IsDeleted))
                .AsSplitQuery()
                .AsQueryable();

            // Agency users can only see their own submissions
            if (userRole == "Agency" || userRole == "0")
            {
                _logger.LogInformation("Filtering submissions for Agency user: {UserId}", userId);
                query = query.Where(p => p.SubmittedByUserId == userId);
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
                // Extract invoice data from CampaignInvoices (hierarchical model)
                var firstInvoice = p.Campaigns
                    .Where(c => !c.IsDeleted)
                    .SelectMany(c => c.Invoices)
                    .Where(i => !i.IsDeleted)
                    .FirstOrDefault();
                
                string? invoiceNumber = firstInvoice?.InvoiceNumber;
                decimal? invoiceAmount = firstInvoice?.TotalAmount;

                // Fallback: check old Documents table if no CampaignInvoice found
                if (string.IsNullOrEmpty(invoiceNumber) && invoiceAmount == null)
                {
                    var invoiceDoc = p.Documents.FirstOrDefault(d => d.Type == DocumentType.Invoice);
                    if (invoiceDoc != null && !string.IsNullOrEmpty(invoiceDoc.ExtractedDataJson))
                    {
                        try
                        {
                            var invoiceData = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(invoiceDoc.ExtractedDataJson);
                            if (invoiceData.TryGetProperty("InvoiceNumber", out var invNum))
                                invoiceNumber = invNum.GetString();
                            else if (invoiceData.TryGetProperty("invoiceNumber", out var invNum2))
                                invoiceNumber = invNum2.GetString();

                            if (invoiceData.TryGetProperty("TotalAmount", out var amt) && amt.ValueKind == System.Text.Json.JsonValueKind.Number)
                                invoiceAmount = amt.GetDecimal();
                            else if (invoiceData.TryGetProperty("totalAmount", out var amt2) && amt2.ValueKind == System.Text.Json.JsonValueKind.Number)
                                invoiceAmount = amt2.GetDecimal();
                        }
                        catch { }
                    }
                }

                // Calculate total invoice amount across all campaigns
                var totalInvoiceAmount = p.Campaigns
                    .Where(c => !c.IsDeleted)
                    .SelectMany(c => c.Invoices)
                    .Where(i => !i.IsDeleted && i.TotalAmount != null && i.TotalAmount > 0)
                    .Sum(i => i.TotalAmount ?? 0);
                
                if (totalInvoiceAmount > 0)
                    invoiceAmount = totalInvoiceAmount;

                // Extract PO data from documents
                var poDoc = p.Documents.FirstOrDefault(d => d.Type == DocumentType.PO);
                string? poNumber = null;
                decimal? poAmount = null;

                if (poDoc != null && !string.IsNullOrEmpty(poDoc.ExtractedDataJson))
                {
                    try
                    {
                        var poData = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(poDoc.ExtractedDataJson);
                        
                        if (poData.TryGetProperty("PONumber", out var poNum))
                            poNumber = poNum.GetString();
                        else if (poData.TryGetProperty("poNumber", out var poNum2))
                            poNumber = poNum2.GetString();

                        if (poData.TryGetProperty("TotalAmount", out var amt) && amt.ValueKind == System.Text.Json.JsonValueKind.Number)
                            poAmount = amt.GetDecimal();
                        else if (poData.TryGetProperty("totalAmount", out var amt2) && amt2.ValueKind == System.Text.Json.JsonValueKind.Number)
                            poAmount = amt2.GetDecimal();
                    }
                    catch { }
                }

                // Count documents: PO docs + campaign invoices + campaign photos
                var campaignInvoiceCount = p.Campaigns.Where(c => !c.IsDeleted).SelectMany(c => c.Invoices).Count(i => !i.IsDeleted);
                var campaignPhotoCount = p.Campaigns.Where(c => !c.IsDeleted).SelectMany(c => c.Photos).Count(ph => !ph.IsDeleted);
                var totalDocCount = p.Documents.Count + campaignInvoiceCount + campaignPhotoCount;

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
                    OverallConfidence = p.ConfidenceScore != null ? (decimal?)p.ConfidenceScore.OverallConfidence : null
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

            // Allow approval from PendingASMApproval, PendingApproval (legacy), or RejectedByRA states
            if (package.State != PackageState.PendingASMApproval && 
                package.State != PackageState.PendingApproval &&
                package.State != PackageState.RejectedByRA)
            {
                return BadRequest(new { error = $"Submission is not in a state that can be approved by ASM. Current state: {package.State}" });
            }

            package.State = PackageState.PendingHQApproval;
            package.ASMReviewedByUserId = userId;
            package.ASMReviewedAt = DateTime.UtcNow;
            package.ASMReviewNotes = request?.Notes ?? "Approved by ASM";
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} approved by ASM {UserId}, moved to HQ approval", id, userId);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Approved by ASM, pending HQ approval"
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

            // Allow rejection from PendingASMApproval, PendingApproval (legacy), or RejectedByRA states
            if (package.State != PackageState.PendingASMApproval && 
                package.State != PackageState.PendingApproval &&
                package.State != PackageState.RejectedByRA)
            {
                return BadRequest(new { error = $"Submission is not in a state that can be rejected by ASM. Current state: {package.State}" });
            }

            package.State = PackageState.RejectedByASM;
            package.ASMReviewedByUserId = userId;
            package.ASMReviewedAt = DateTime.UtcNow;
            package.ASMReviewNotes = request.Reason;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

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

            if (package.State != PackageState.PendingHQApproval)
            {
                return BadRequest(new { error = $"Submission is not in pending HQ approval state. Current state: {package.State}" });
            }

            package.State = PackageState.Approved;
            package.HQReviewedByUserId = userId;
            package.HQReviewedAt = DateTime.UtcNow;
            package.HQReviewNotes = request?.Notes ?? "Approved by HQ";
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} approved by HQ {UserId} - final approval", id, userId);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Final approval by HQ"
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

            if (package.State != PackageState.PendingHQApproval)
            {
                return BadRequest(new { error = $"Submission is not in pending HQ approval state. Current state: {package.State}" });
            }

            package.State = PackageState.RejectedByRA;
            package.HQReviewedByUserId = userId;
            package.HQReviewedAt = DateTime.UtcNow;
            package.HQReviewNotes = request.Reason;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

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
            if (package.State != PackageState.RejectedByASM && 
                package.State != PackageState.RejectedByRA)
            {
                return BadRequest(new { error = $"Can only resubmit packages rejected by ASM or RA. Current state: {package.State}" });
            }

            // Verify the package belongs to the user
            if (package.SubmittedByUserId != userId)
            {
                return Forbid();
            }

            // Track resubmission
            package.ResubmissionCount = (package.ResubmissionCount ?? 0) + 1;
            
            // Reset to uploaded state to trigger workflow
            package.State = PackageState.Uploaded;
            package.ASMReviewNotes = null;
            package.ASMReviewedAt = null;
            package.ASMReviewedByUserId = null;
            // Clear HQ review fields if resubmitting from RA rejection
            package.HQReviewNotes = null;
            package.HQReviewedAt = null;
            package.HQReviewedByUserId = null;
            package.UpdatedAt = DateTime.UtcNow;
            
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Package {Id} resubmitted by Agency user {UserId} (Resubmission #{Count})", 
                id, userId, package.ResubmissionCount);

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
                ResubmissionCount = package.ResubmissionCount,
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
            if (package.State != PackageState.RejectedByRA)
            {
                return BadRequest(new { error = $"Can only resubmit packages rejected by HQ. Current state: {package.State}" });
            }

            // Track HQ resubmission
            package.HQResubmissionCount = (package.HQResubmissionCount ?? 0) + 1;
            
            // Move back to pending HQ approval
            package.State = PackageState.PendingHQApproval;
            
            // Append resubmission notes to ASM notes
            var resubmissionNote = $"\n\n[Resubmission #{package.HQResubmissionCount} - {DateTime.UtcNow:yyyy-MM-dd HH:mm}]\n{request.Notes}";
            package.ASMReviewNotes = (package.ASMReviewNotes ?? "") + resubmissionNote;
            
            // Clear HQ rejection (but keep history in notes)
            package.HQReviewNotes = null;
            package.HQReviewedAt = null;
            package.HQReviewedByUserId = null;
            
            package.UpdatedAt = DateTime.UtcNow;
            
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Package {Id} resubmitted to HQ by ASM user {UserId} (HQ Resubmission #{Count})", 
                id, userId, package.HQResubmissionCount);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                HQResubmissionCount = package.HQResubmissionCount,
                Message = "Package resubmitted to HQ successfully"
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

            if (package.State != PackageState.RejectedByRA)
            {
                return BadRequest(new { error = $"Can only send back packages rejected by RA. Current state: {package.State}" });
            }

            // Move to RejectedByASM so Agency can edit and resubmit
            package.State = PackageState.RejectedByASM;
            package.ASMReviewedByUserId = userId;
            package.ASMReviewedAt = DateTime.UtcNow;
            package.ASMReviewNotes = $"Sent back to Agency: {request.Reason}";

            // Clear HQ review fields
            package.HQReviewNotes = null;
            package.HQReviewedAt = null;
            package.HQReviewedByUserId = null;

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

            if (package.State != PackageState.PendingApproval)
            {
                return BadRequest(new { error = "Submission is not in pending approval state" });
            }

            package.State = PackageState.Rejected;
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
    /// Submit/finalize a package for AI processing workflow (Agency role only)
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
                .Include(p => p.Documents)
                .Include(p => p.Campaigns.Where(c => !c.IsDeleted))
                    .ThenInclude(c => c.Invoices.Where(i => !i.IsDeleted))
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

            if (package.State != PackageState.Uploaded)
            {
                _logger.LogWarning("Package {PackageId} is in state {State}, cannot submit", packageId, package.State);
                return BadRequest(new { error = $"Package is already in {package.State} state" });
            }

            // Verify minimum required documents
            var hasPO = package.Documents.Any(d => d.Type == DocumentType.PO);
            // Check both old Documents table and new CampaignInvoices table
            var hasInvoice = package.Documents.Any(d => d.Type == DocumentType.Invoice) ||
                             package.Campaigns.Any(c => c.Invoices.Any());
            var hasCostSummary = package.Documents.Any(d => d.Type == DocumentType.CostSummary) ||
                                 package.Campaigns.Any(c => !string.IsNullOrEmpty(c.CostSummaryBlobUrl));

            var campaignInvoiceCount = package.Campaigns.SelectMany(c => c.Invoices).Count();
            _logger.LogInformation("Package {PackageId} document check: PO={HasPO}, Invoice={HasInvoice} (CampaignInvoices={CampaignInvCount}), CostSummary={HasCostSummary}", 
                packageId, hasPO, hasInvoice, campaignInvoiceCount, hasCostSummary);

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

            _logger.LogInformation("Submitting package {PackageId} for processing with {Count} documents", 
                packageId, package.Documents.Count);

            // Queue workflow for background processing
            await _backgroundQueue.QueueWorkflowAsync(packageId);
            
            _logger.LogInformation("Package {PackageId} queued for background processing", packageId);

            var response = new SubmissionStatusResponse
            {
                Id = packageId,
                State = package.State.ToString(),
                DocumentCount = package.Documents.Count,
                Status = "Queued for processing",
                Message = "Package submitted for processing"
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
                return BadRequest(new { error = $"Cannot move submission from {package.State} to PendingApproval" });
            }

            package.State = PackageState.PendingApproval;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} manually moved to PendingApproval", id);

            var response = new SubmissionStatusResponse
            {
                Id = package.Id,
                State = package.State.ToString(),
                Message = "Moved to PendingApproval"
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
            var package = await _context.DocumentPackages.FindAsync(new object[] { id }, cancellationToken);
            if (package == null)
            {
                return NotFound(new { error = "Submission not found" });
            }

            // Update campaign fields
            if (request.CampaignStartDate.HasValue)
                package.CampaignStartDate = request.CampaignStartDate.Value;
            if (request.CampaignEndDate.HasValue)
                package.CampaignEndDate = request.CampaignEndDate.Value;
            if (request.CampaignWorkingDays.HasValue)
                package.CampaignWorkingDays = request.CampaignWorkingDays.Value;

            // Update dealership fields
            if (!string.IsNullOrEmpty(request.DealershipName))
                package.DealershipName = request.DealershipName;
            if (!string.IsNullOrEmpty(request.DealershipAddress))
                package.DealershipAddress = request.DealershipAddress;
            if (!string.IsNullOrEmpty(request.GpsLocation))
                package.GPSLocation = request.GpsLocation;
            
            // Note: TeamsJson is now stored at Campaign level, not DocumentPackage level

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
                .Include(p => p.Documents)
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
                .Include(p => p.Documents)
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
    // CHANGE: Rewritten BuildValidationDetails to show all 43+ checks individually, line by line
    /// <summary>
    /// Builds a single string showing ALL individual validation checks (43+) with pass/fail status
    /// </summary>
    private static string BuildValidationDetails(Domain.Entities.ValidationResult vr)
    {
        var checks = new List<string>();
        System.Text.Json.JsonElement json = default;
        bool hasJson = false;

        if (!string.IsNullOrEmpty(vr.ValidationDetailsJson))
        {
            try
            {
                json = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(vr.ValidationDetailsJson);
                hasJson = true;
            }
            catch { }
        }

        // CHANGE: Read FileNames from validation JSON to show which file each check refers to
        var fileNames = new Dictionary<string, string>();
        if (hasJson && json.TryGetProperty("FileNames", out var fnEl) && fnEl.ValueKind == System.Text.Json.JsonValueKind.Object)
        {
            foreach (var prop in fnEl.EnumerateObject())
            {
                var val = prop.Value.GetString();
                if (!string.IsNullOrEmpty(val)) fileNames[prop.Name] = val;
            }
        }
        // CHANGE: Helper to get filename label like " (Invoice_March.pdf)" for a document type
        string Fn(string docType) => fileNames.TryGetValue(docType, out var name) ? $" ({name})" : "";

        // ===== GENERAL CHECKS (6) =====
        if (vr.SapVerificationPassed)
            checks.Add($"SAP Verification{Fn("PO")}: Pass - PO verified against SAP records");
        else
            checks.Add($"SAP Verification{Fn("PO")}: Fail - " + (hasJson ? SafeGetString(json, "SAPVerification", "Discrepancies") ?? "PO could not be verified in SAP" : "PO could not be verified in SAP"));

        checks.Add(vr.AmountConsistencyPassed
            ? "Amount Consistency: Pass - Invoice and Cost Summary amounts are consistent"
            : "Amount Consistency: Fail - Invoice and Cost Summary amounts do not match");

        if (vr.LineItemMatchingPassed)
            checks.Add("Line Item Matching: Pass - All PO line items found in Invoice");
        else
        {
            var detail = hasJson ? SafeGetString(json, "LineItemMatching", "MissingItemCodes") : null;
            checks.Add("Line Item Matching: Fail - " + (detail != null ? $"Missing PO line items in Invoice: {detail}" : "Some PO line items missing in Invoice"));
        }

        if (vr.CompletenessCheckPassed)
            checks.Add("Completeness Check: Pass - All required documents are present");
        else
            checks.Add("Completeness Check: Fail - " + (hasJson ? SafeGetString(json, "Completeness", "MissingItems") ?? "Some required documents are missing" : "Some required documents are missing"));

        if (vr.DateValidationPassed)
            checks.Add("Date Validation: Pass - All dates are valid and consistent");
        else
            checks.Add("Date Validation: Fail - " + (hasJson ? SafeGetString(json, "DateValidation", "DateIssues") ?? "Date inconsistencies found" : "Date inconsistencies found"));

        checks.Add(vr.VendorMatchingPassed
            ? "Vendor Matching: Pass - Vendor name matches across PO and Invoice"
            : "Vendor Matching: Fail - Vendor name mismatch between PO and Invoice");

        if (hasJson)
        {
            // CHANGE: Use Fn() to prepend filename to each document-specific check
            var invLabel = $"Invoice{Fn("Invoice")}";
            var csLabel = $"Cost Summary{Fn("CostSummary")}";
            var actLabel = $"Activity{Fn("Activity")}";
            var edLabel = $"Enquiry Dump{Fn("EnquiryDump")}";
            // CHANGE: For photos, list all photo filenames together
            var photoFileList = fileNames.Where(kv => kv.Key.StartsWith("Photo_")).Select(kv => kv.Value).ToList();
            var photoLabel = photoFileList.Any() ? $"Photo ({string.Join(", ", photoFileList)})" : "Photo";

            // ===== INVOICE FIELD PRESENCE — 13 individual checks =====
            if (SafeSectionExists(json, "InvoiceFieldPresence"))
            {
                var mf = SafeGetStringList(json, "InvoiceFieldPresence", "MissingFields");
                checks.Add(mf.Contains("Agency Name") ? $"{invLabel} - Agency Name: Fail - Missing" : $"{invLabel} - Agency Name: Pass - Present");
                checks.Add(mf.Contains("Agency Address") ? $"{invLabel} - Agency Address: Fail - Missing" : $"{invLabel} - Agency Address: Pass - Present");
                checks.Add(mf.Contains("Billing Name") ? $"{invLabel} - Billing Name: Fail - Missing" : $"{invLabel} - Billing Name: Pass - Present");
                checks.Add(mf.Contains("Billing Address") ? $"{invLabel} - Billing Address: Fail - Missing" : $"{invLabel} - Billing Address: Pass - Present");
                checks.Add(mf.Contains("State Name/Code") ? $"{invLabel} - State Name/Code: Fail - Missing" : $"{invLabel} - State Name/Code: Pass - Present");
                checks.Add(mf.Contains("Invoice Number") ? $"{invLabel} - Invoice Number: Fail - Missing" : $"{invLabel} - Invoice Number: Pass - Present");
                checks.Add(mf.Contains("Invoice Date") ? $"{invLabel} - Invoice Date: Fail - Missing" : $"{invLabel} - Invoice Date: Pass - Present");
                checks.Add(mf.Contains("Vendor Code") ? $"{invLabel} - Vendor Code: Fail - Missing" : $"{invLabel} - Vendor Code: Pass - Present");
                checks.Add(mf.Contains("PO Number") ? $"{invLabel} - PO Number: Fail - Missing" : $"{invLabel} - PO Number: Pass - Present");
                checks.Add(mf.Contains("GST Number") ? $"{invLabel} - GST Number: Fail - Missing" : $"{invLabel} - GST Number: Pass - Present");
                checks.Add(mf.Contains("GST Percentage") ? $"{invLabel} - GST Percentage: Fail - Missing" : $"{invLabel} - GST Percentage: Pass - Present");
                checks.Add(mf.Contains("HSN/SAC Code") ? $"{invLabel} - HSN/SAC Code: Fail - Missing" : $"{invLabel} - HSN/SAC Code: Pass - Present");
                checks.Add(mf.Contains("Invoice Amount") ? $"{invLabel} - Invoice Amount: Fail - Missing" : $"{invLabel} - Invoice Amount: Pass - Present");
            }

            // ===== INVOICE CROSS-DOCUMENT — 6 individual checks =====
            if (SafeSectionExists(json, "InvoiceCrossDocument"))
            {
                var issues = SafeGetStringList(json, "InvoiceCrossDocument", "Issues");
                var sec = SafeGetSection(json, "InvoiceCrossDocument");

                var agencyCodeMatch = SafeGetBoolProp(sec, "AgencyCodeMatches");
                checks.Add(agencyCodeMatch == true ? $"{invLabel} - Agency Code match with PO: Pass - Matches"
                    : agencyCodeMatch == false ? $"{invLabel} - Agency Code match with PO: Fail - " + (FindIssue(issues, "Agency Code") ?? "Mismatch")
                    : $"{invLabel} - Agency Code match with PO: Pass - Not applicable (field empty)");

                var poMatch = SafeGetBoolProp(sec, "PONumberMatches");
                checks.Add(poMatch == true ? $"{invLabel} - PO Number match with PO: Pass - Matches"
                    : poMatch == false ? $"{invLabel} - PO Number match with PO: Fail - " + (FindIssue(issues, "PO Number") ?? "Mismatch")
                    : $"{invLabel} - PO Number match with PO: Pass - Not applicable (field empty)");

                var gstMatch = SafeGetBoolProp(sec, "GSTStateMatches");
                checks.Add(gstMatch == true ? $"{invLabel} - GST Number match with State: Pass - GST matches state code"
                    : gstMatch == false ? $"{invLabel} - GST Number match with State: Fail - " + (FindIssue(issues, "GST") ?? "GST-State mismatch")
                    : $"{invLabel} - GST Number match with State: Pass - Not applicable (field empty)");

                var hsnValid = SafeGetBoolProp(sec, "HSNSACCodeValid");
                checks.Add(hsnValid == true ? $"{invLabel} - HSN/SAC Code valid: Pass - Valid code"
                    : hsnValid == false ? $"{invLabel} - HSN/SAC Code valid: Fail - " + (FindIssue(issues, "HSN") ?? "Invalid code")
                    : $"{invLabel} - HSN/SAC Code valid: Pass - Not applicable (field empty)");

                var amtValid = SafeGetBoolProp(sec, "InvoiceAmountValid");
                checks.Add(amtValid == true ? $"{invLabel} - Amount <= PO Amount: Pass - Invoice amount within PO limit"
                    : $"{invLabel} - Amount <= PO Amount: Fail - " + (FindIssue(issues, "Invoice amount") ?? "Invoice exceeds PO amount"));

                var gstPctValid = SafeGetBoolProp(sec, "GSTPercentageValid");
                checks.Add(gstPctValid == true ? $"{invLabel} - GST% match with State: Pass - GST percentage matches state rate"
                    : gstPctValid == false ? $"{invLabel} - GST% match with State: Fail - " + (FindIssue(issues, "GST Percentage") ?? "GST% mismatch")
                    : $"{invLabel} - GST% match with State: Pass - Not applicable");
            }

            // ===== COST SUMMARY FIELD PRESENCE — 6 individual checks =====
            if (SafeSectionExists(json, "CostSummaryFieldPresence"))
            {
                var mf = SafeGetStringList(json, "CostSummaryFieldPresence", "MissingFields");
                checks.Add(mf.Any(f => f.Contains("Place of Supply") || f.Contains("State")) ? $"{csLabel} - State/Place of Supply: Fail - Missing" : $"{csLabel} - State/Place of Supply: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Element wise Cost")) ? $"{csLabel} - Element wise Cost: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Element wise Cost")) ?? "Missing") : $"{csLabel} - Element wise Cost: Pass - Present");
                checks.Add(mf.Contains("Number of Days") ? $"{csLabel} - No of Days: Fail - Missing" : $"{csLabel} - No of Days: Pass - Present");
                checks.Add(mf.Contains("Number of Activations") ? $"{csLabel} - No of Activations: Fail - Missing" : $"{csLabel} - No of Activations: Pass - Present");
                checks.Add(mf.Contains("Number of Teams") ? $"{csLabel} - No of Teams: Fail - Missing" : $"{csLabel} - No of Teams: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Element wise Quantity")) ? $"{csLabel} - Element wise Quantity: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Element wise Quantity")) ?? "Missing") : $"{csLabel} - Element wise Quantity: Pass - Present");
            }

            // ===== COST SUMMARY CROSS-DOCUMENT — 4 individual checks =====
            if (SafeSectionExists(json, "CostSummaryCrossDocument"))
            {
                var sec = SafeGetSection(json, "CostSummaryCrossDocument");
                var issues = SafeGetStringList(json, "CostSummaryCrossDocument", "Issues");
                checks.Add(SafeGetBoolProp(sec, "TotalCostValid") == true ? $"{csLabel} - Total Cost <= Invoice Amount: Pass - Within limit" : $"{csLabel} - Total Cost <= Invoice Amount: Fail - " + (FindIssue(issues, "total") ?? "Exceeds Invoice amount"));
                checks.Add(SafeGetBoolProp(sec, "ElementCostsValid") == true ? $"{csLabel} - Element wise Cost match State rates: Pass - Matches" : $"{csLabel} - Element wise Cost match State rates: Fail - " + (FindIssue(issues, "Element") ?? "Does not match state rates"));
                checks.Add(SafeGetBoolProp(sec, "FixedCostsValid") == true ? $"{csLabel} - Fixed Cost Limits: Pass - Within state limits" : $"{csLabel} - Fixed Cost Limits: Fail - " + (FindIssue(issues, "Fixed") ?? "Exceeds state limits"));
                checks.Add(SafeGetBoolProp(sec, "VariableCostsValid") == true ? $"{csLabel} - Variable Cost Limits: Pass - Within state limits" : $"{csLabel} - Variable Cost Limits: Fail - " + (FindIssue(issues, "Variable") ?? "Exceeds state limits"));
            }

            // ===== ACTIVITY FIELD PRESENCE — 2 individual checks =====
            if (SafeSectionExists(json, "ActivityFieldPresence"))
            {
                var mf = SafeGetStringList(json, "ActivityFieldPresence", "MissingFields");
                checks.Add(mf.Any(f => f.Contains("Dealer") || f.Contains("Location")) ? $"{actLabel} - Dealer and Location details: Fail - " + string.Join(", ", mf.Where(f => f.Contains("Dealer") || f.Contains("Location"))) : $"{actLabel} - Dealer and Location details: Pass - Present");
                checks.Add(mf.Any(f => f.Contains("days") || f.Contains("Day")) ? $"{actLabel} - No of days in each Location: Fail - Missing" : $"{actLabel} - No of days in each Location: Pass - Present");
            }

            // ===== ACTIVITY CROSS-DOCUMENT — 1 check =====
            if (SafeSectionExists(json, "ActivityCrossDocument"))
            {
                var issues = SafeGetStringList(json, "ActivityCrossDocument", "Issues");
                var sec = SafeGetSection(json, "ActivityCrossDocument");
                checks.Add(SafeGetBoolProp(sec, "NumberOfDaysMatches") == true ? $"{actLabel} - No of days match with Cost Summary: Pass - Days match" : $"{actLabel} - No of days match with Cost Summary: Fail - " + (issues.FirstOrDefault() ?? "Days mismatch"));
            }

            // ===== PHOTO FIELD PRESENCE — 4 individual checks =====
            if (SafeSectionExists(json, "PhotoFieldPresence"))
            {
                var mf = SafeGetStringList(json, "PhotoFieldPresence", "MissingFields");
                checks.Add(mf.Any(f => f.Contains("Date")) ? $"{photoLabel} - Date: Fail - " + (mf.FirstOrDefault(f => f.Contains("Date")) ?? "Missing") : $"{photoLabel} - Date: Pass - Present");
                checks.Add(mf.Any(f => f.Contains("Location") || f.Contains("coordinates")) ? $"{photoLabel} - Lat Long: Fail - " + (mf.FirstOrDefault(f => f.Contains("Location") || f.Contains("coordinates")) ?? "Missing") : $"{photoLabel} - Lat Long: Pass - Present");
                checks.Add(mf.Any(f => f.Contains("blue t-shirt")) ? $"{photoLabel} - Person with Blue T-shirt: Fail - Not detected" : $"{photoLabel} - Person with Blue T-shirt: Pass - Detected");
                checks.Add(mf.Any(f => f.Contains("Bajaj vehicle") || f.Contains("3W")) ? $"{photoLabel} - 3W Vehicle: Fail - Not detected" : $"{photoLabel} - 3W Vehicle: Pass - Detected");
            }

            // ===== PHOTO CROSS-DOCUMENT — 1 check =====
            if (SafeSectionExists(json, "PhotoCrossDocument"))
            {
                var issues = SafeGetStringList(json, "PhotoCrossDocument", "Issues");
                checks.Add(SafeGetBoolProp(SafeGetSection(json, "PhotoCrossDocument"), "PhotoCountMatchesManDays") == true ? $"{photoLabel} - No of days match with Cost Summary: Pass - Photo count matches" : $"{photoLabel} - No of days match with Cost Summary: Fail - " + (issues.FirstOrDefault() ?? "Photo count mismatch"));
            }

            // ===== ENQUIRY DUMP FIELD PRESENCE — 9 individual checks =====
            if (SafeSectionExists(json, "EnquiryDumpFieldPresence"))
            {
                var mf = SafeGetStringList(json, "EnquiryDumpFieldPresence", "MissingFields");
                checks.Add(mf.Any(f => f.StartsWith("State")) ? $"{edLabel} - State: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("State")) ?? "Missing") : $"{edLabel} - State: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Date")) ? $"{edLabel} - Date: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Date")) ?? "Missing") : $"{edLabel} - Date: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Dealer Code")) ? $"{edLabel} - Dealer Code: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Dealer Code")) ?? "Missing") : $"{edLabel} - Dealer Code: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Dealer Name")) ? $"{edLabel} - Dealer Name: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Dealer Name")) ?? "Missing") : $"{edLabel} - Dealer Name: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("District")) ? $"{edLabel} - District: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("District")) ?? "Missing") : $"{edLabel} - District: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Pincode")) ? $"{edLabel} - Pincode: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Pincode")) ?? "Missing") : $"{edLabel} - Pincode: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Customer Name")) ? $"{edLabel} - Customer Name: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Customer Name")) ?? "Missing") : $"{edLabel} - Customer Name: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Customer Number")) ? $"{edLabel} - Customer Number: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Customer Number")) ?? "Missing") : $"{edLabel} - Customer Number: Pass - Present");
                checks.Add(mf.Any(f => f.StartsWith("Test Ride")) ? $"{edLabel} - Test Ride Taken: Fail - " + (mf.FirstOrDefault(f => f.StartsWith("Test Ride")) ?? "Missing") : $"{edLabel} - Test Ride Taken: Pass - Present");
            }
        }

        return string.Join("; ", checks);
    }

    private static bool SafeSectionExists(System.Text.Json.JsonElement root, string section)
    {
        return root.TryGetProperty(section, out var el) && el.ValueKind != System.Text.Json.JsonValueKind.Null;
    }

    private static System.Text.Json.JsonElement? SafeGetSection(System.Text.Json.JsonElement root, string section)
    {
        if (root.TryGetProperty(section, out var el) && el.ValueKind != System.Text.Json.JsonValueKind.Null)
            return el;
        return null;
    }

    private static bool? SafeGetBoolProp(System.Text.Json.JsonElement? section, string property)
    {
        if (section == null) return null;
        if (section.Value.TryGetProperty(property, out var prop))
        {
            if (prop.ValueKind == System.Text.Json.JsonValueKind.True) return true;
            if (prop.ValueKind == System.Text.Json.JsonValueKind.False) return false;
        }
        return null;
    }

    private static List<string> SafeGetStringList(System.Text.Json.JsonElement root, string section, string arrayProp)
    {
        var result = new List<string>();
        try
        {
            if (root.TryGetProperty(section, out var sectionEl) && sectionEl.ValueKind != System.Text.Json.JsonValueKind.Null)
            {
                System.Text.Json.JsonElement arrEl;
                if (sectionEl.TryGetProperty(arrayProp, out arrEl) || sectionEl.TryGetProperty(char.ToLower(arrayProp[0]) + arrayProp.Substring(1), out arrEl))
                {
                    if (arrEl.ValueKind == System.Text.Json.JsonValueKind.Array)
                    {
                        foreach (var item in arrEl.EnumerateArray())
                        {
                            var val = item.GetString();
                            if (!string.IsNullOrEmpty(val)) result.Add(val);
                        }
                    }
                }
            }
        }
        catch { }
        return result;
    }

    private static string? SafeGetString(System.Text.Json.JsonElement root, string section, string arrayProp)
    {
        var list = SafeGetStringList(root, section, arrayProp);
        return list.Any() ? string.Join(", ", list) : null;
    }

    private static string? FindIssue(List<string> issues, string keyword)
    {
        return issues.FirstOrDefault(i => i.Contains(keyword, StringComparison.OrdinalIgnoreCase));
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
    int? CampaignWorkingDays = null
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
/// <param name="TeamsJson">JSON string containing teams/campaign members data</param>
public record UpdateCampaignDataRequest(
    DateTime? CampaignStartDate = null,
    DateTime? CampaignEndDate = null,
    int? CampaignWorkingDays = null,
    string? DealershipName = null,
    string? DealershipAddress = null,
    string? GpsLocation = null,
    string? TeamsJson = null
);
