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
    /// Get enhanced validation report for a submission (ASM and HQ roles only)
    /// </summary>
    /// <param name="id">Submission package ID</param>
    /// <param name="enhancedValidationReportService">Enhanced validation report service</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Enhanced validation report with detailed evidence and recommendations</returns>
    /// <response code="200">Returns enhanced validation report</response>
    /// <response code="401">Unauthorized - authentication required</response>
    /// <response code="403">Forbidden - ASM or HQ role required</response>
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
                // Extract invoice data from documents
                var invoiceDoc = p.Documents.FirstOrDefault(d => d.Type == DocumentType.Invoice);
                string? invoiceNumber = null;
                decimal? invoiceAmount = null;

                if (invoiceDoc != null && !string.IsNullOrEmpty(invoiceDoc.ExtractedDataJson))
                {
                    try
                    {
                        var invoiceData = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(invoiceDoc.ExtractedDataJson);
                        
                        // Try to get invoice number
                        if (invoiceData.TryGetProperty("InvoiceNumber", out var invNum))
                        {
                            invoiceNumber = invNum.GetString();
                        }
                        else if (invoiceData.TryGetProperty("invoiceNumber", out var invNum2))
                        {
                            invoiceNumber = invNum2.GetString();
                        }

                        // Try to get invoice amount
                        if (invoiceData.TryGetProperty("TotalAmount", out var amt))
                        {
                            if (amt.ValueKind == System.Text.Json.JsonValueKind.Number)
                            {
                                invoiceAmount = amt.GetDecimal();
                            }
                            else if (amt.ValueKind == System.Text.Json.JsonValueKind.String)
                            {
                                decimal.TryParse(amt.GetString(), out var parsedAmount);
                                invoiceAmount = parsedAmount;
                            }
                        }
                        else if (invoiceData.TryGetProperty("totalAmount", out var amt2))
                        {
                            if (amt2.ValueKind == System.Text.Json.JsonValueKind.Number)
                            {
                                invoiceAmount = amt2.GetDecimal();
                            }
                            else if (amt2.ValueKind == System.Text.Json.JsonValueKind.String)
                            {
                                decimal.TryParse(amt2.GetString(), out var parsedAmount);
                                invoiceAmount = parsedAmount;
                            }
                        }
                    }
                    catch
                    {
                        // If parsing fails, leave as null
                    }
                }

                // Extract PO data from documents
                var poDoc = p.Documents.FirstOrDefault(d => d.Type == DocumentType.PO);
                string? poNumber = null;
                decimal? poAmount = null;

                if (poDoc != null && !string.IsNullOrEmpty(poDoc.ExtractedDataJson))
                {
                    try
                    {
                        var poData = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(poDoc.ExtractedDataJson);
                        
                        // Try to get PO number
                        if (poData.TryGetProperty("PONumber", out var poNum))
                        {
                            poNumber = poNum.GetString();
                        }
                        else if (poData.TryGetProperty("poNumber", out var poNum2))
                        {
                            poNumber = poNum2.GetString();
                        }

                        // Try to get PO amount
                        if (poData.TryGetProperty("TotalAmount", out var amt))
                        {
                            if (amt.ValueKind == System.Text.Json.JsonValueKind.Number)
                            {
                                poAmount = amt.GetDecimal();
                            }
                            else if (amt.ValueKind == System.Text.Json.JsonValueKind.String)
                            {
                                decimal.TryParse(amt.GetString(), out var parsedAmount);
                                poAmount = parsedAmount;
                            }
                        }
                        else if (poData.TryGetProperty("totalAmount", out var amt2))
                        {
                            if (amt2.ValueKind == System.Text.Json.JsonValueKind.Number)
                            {
                                poAmount = amt2.GetDecimal();
                            }
                            else if (amt2.ValueKind == System.Text.Json.JsonValueKind.String)
                            {
                                decimal.TryParse(amt2.GetString(), out var parsedAmount);
                                poAmount = parsedAmount;
                            }
                        }
                    }
                    catch
                    {
                        // If parsing fails, leave as null
                    }
                }

                return new SubmissionListItemDto
                {
                    Id = p.Id,
                    State = p.State.ToString(),
                    CreatedAt = p.CreatedAt,
                    UpdatedAt = p.UpdatedAt,
                    DocumentCount = p.Documents.Count,
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

            // Allow approval from PendingASMApproval, PendingApproval (legacy), or RejectedByHQ states
            if (package.State != PackageState.PendingASMApproval && 
                package.State != PackageState.PendingApproval &&
                package.State != PackageState.RejectedByHQ)
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

            // Allow rejection from PendingASMApproval, PendingApproval (legacy), or RejectedByHQ states
            if (package.State != PackageState.PendingASMApproval && 
                package.State != PackageState.PendingApproval &&
                package.State != PackageState.RejectedByHQ)
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

            package.State = PackageState.RejectedByHQ;
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
                Message = "Rejected by HQ, sent back to ASM"
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

            // Can only resubmit if rejected by ASM
            if (package.State != PackageState.RejectedByASM)
            {
                return BadRequest(new { error = $"Can only resubmit packages rejected by ASM. Current state: {package.State}" });
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

            // Can only resubmit if rejected by HQ
            if (package.State != PackageState.RejectedByHQ)
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
            var hasInvoice = package.Documents.Any(d => d.Type == DocumentType.Invoice);
            var hasCostSummary = package.Documents.Any(d => d.Type == DocumentType.CostSummary);

            _logger.LogInformation("Package {PackageId} document check: PO={HasPO}, Invoice={HasInvoice}, CostSummary={HasCostSummary}", 
                packageId, hasPO, hasInvoice, hasCostSummary);

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
    /// <summary>
    /// Builds a single string showing all validation checks with descriptive pass/fail messages
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

        // SAP Verification
        if (vr.SapVerificationPassed)
            checks.Add("SAP Verification: Pass - PO verified against SAP records");
        else
            checks.Add("SAP Verification: Fail - " + (hasJson ? GetJsonArrayAsString(json, "SAPVerification", "Discrepancies", "PO could not be verified in SAP") : "PO could not be verified in SAP"));

        // Amount Consistency
        checks.Add(vr.AmountConsistencyPassed
            ? "Amount Consistency: Pass - Invoice and Cost Summary amounts are consistent"
            : "Amount Consistency: Fail - Invoice and Cost Summary amounts do not match");

        // Line Item Matching
        if (vr.LineItemMatchingPassed)
            checks.Add("Line Item Matching: Pass - All PO line items found in Invoice");
        else
            checks.Add("Line Item Matching: Fail - " + (hasJson ? GetLineItemDetail(json) : "Some PO line items missing in Invoice"));

        // Completeness Check
        if (vr.CompletenessCheckPassed)
            checks.Add("Completeness Check: Pass - All required documents are present");
        else
            checks.Add("Completeness Check: Fail - " + (hasJson ? GetJsonArrayAsString(json, "Completeness", "MissingItems", "Some required documents are missing") : "Some required documents are missing"));

        // Date Validation
        if (vr.DateValidationPassed)
            checks.Add("Date Validation: Pass - All dates are valid and consistent");
        else
            checks.Add("Date Validation: Fail - " + (hasJson ? GetJsonArrayAsString(json, "DateValidation", "DateIssues", "Date inconsistencies found") : "Date inconsistencies found"));

        // Vendor Matching
        checks.Add(vr.VendorMatchingPassed
            ? "Vendor Matching: Pass - Vendor name matches across PO and Invoice"
            : "Vendor Matching: Fail - Vendor name mismatch between PO and Invoice");

        if (hasJson)
        {
            // Invoice Field Presence
            checks.Add(GetJsonBool(json, "InvoiceFieldPresence", "AllFieldsPresent")
                ? "Invoice Field Presence: Pass - All required Invoice fields are present"
                : "Invoice Field Presence: Fail - " + GetJsonIssueDetail(json, "InvoiceFieldPresence", "MissingFields"));

            // Invoice Cross-Document
            checks.Add(GetJsonBool(json, "InvoiceCrossDocument", "AllChecksPass")
                ? "Invoice Cross-Document: Pass - Invoice data matches PO data"
                : "Invoice Cross-Document: Fail - " + GetJsonIssues(json, "InvoiceCrossDocument"));

            // Cost Summary Field Presence
            checks.Add(GetJsonBool(json, "CostSummaryFieldPresence", "AllFieldsPresent")
                ? "Cost Summary Field Presence: Pass - All required Cost Summary fields are present"
                : "Cost Summary Field Presence: Fail - " + GetJsonIssueDetail(json, "CostSummaryFieldPresence", "MissingFields"));

            // Cost Summary Cross-Document
            checks.Add(GetJsonBool(json, "CostSummaryCrossDocument", "AllChecksPass")
                ? "Cost Summary Cross-Document: Pass - Cost Summary data matches Invoice data"
                : "Cost Summary Cross-Document: Fail - " + GetJsonIssues(json, "CostSummaryCrossDocument"));

            // Activity Field Presence
            checks.Add(GetJsonBool(json, "ActivityFieldPresence", "AllFieldsPresent")
                ? "Activity Field Presence: Pass - All required Activity Summary fields are present"
                : "Activity Field Presence: Fail - " + GetJsonIssueDetail(json, "ActivityFieldPresence", "MissingFields"));

            // Activity Cross-Document
            checks.Add(GetJsonBool(json, "ActivityCrossDocument", "AllChecksPass")
                ? "Activity Cross-Document: Pass - Activity Summary data matches Cost Summary data"
                : "Activity Cross-Document: Fail - " + GetJsonIssues(json, "ActivityCrossDocument"));

            // Photo Field Presence
            checks.Add(GetJsonBool(json, "PhotoFieldPresence", "AllFieldsPresent")
                ? "Photo Field Presence: Pass - Photo proofs validated successfully"
                : "Photo Field Presence: Fail - " + GetJsonIssueDetail(json, "PhotoFieldPresence", "MissingFields"));

            // Photo Cross-Document
            checks.Add(GetJsonBool(json, "PhotoCrossDocument", "AllChecksPass")
                ? "Photo Cross-Document: Pass - Photo count matches Activity Summary"
                : "Photo Cross-Document: Fail - " + GetJsonIssues(json, "PhotoCrossDocument"));

            // Enquiry Dump Field Presence (optional doc)
            if (JsonSectionExists(json, "EnquiryDumpFieldPresence"))
            {
                checks.Add(GetJsonBool(json, "EnquiryDumpFieldPresence", "AllFieldsPresent")
                    ? "Enquiry Dump Field Presence: Pass - All required Enquiry Dump fields are present"
                    : "Enquiry Dump Field Presence: Fail - " + GetJsonIssueDetail(json, "EnquiryDumpFieldPresence", "MissingFields"));
            }

            // Enquiry Dump Cross-Document (optional doc)
            if (JsonSectionExists(json, "EnquiryDumpCrossDocument"))
            {
                checks.Add(GetJsonBool(json, "EnquiryDumpCrossDocument", "AllChecksPass")
                    ? "Enquiry Dump Cross-Document: Pass - Enquiry Dump dealers match Activity Summary"
                    : "Enquiry Dump Cross-Document: Fail - " + GetJsonIssues(json, "EnquiryDumpCrossDocument"));
            }
        }

        return string.Join("; ", checks);
    }

    // CHANGE: Helper to safely read a nested boolean from JsonElement
    private static bool GetJsonBool(System.Text.Json.JsonElement root, string section, string property)
    {
        if (root.TryGetProperty(section, out var sectionEl) && 
            sectionEl.ValueKind != System.Text.Json.JsonValueKind.Null &&
            sectionEl.TryGetProperty(property, out var propEl) &&
            propEl.ValueKind == System.Text.Json.JsonValueKind.True)
        {
            return true;
        }
        return false;
    }

    // CHANGE: Helper to check if a JSON section exists and is not null
    private static bool JsonSectionExists(System.Text.Json.JsonElement root, string section)
    {
        return root.TryGetProperty(section, out var el) && el.ValueKind != System.Text.Json.JsonValueKind.Null;
    }

    // CHANGE: Helper to read a string array from a nested JSON section
    private static string GetJsonArrayAsString(System.Text.Json.JsonElement root, string section, string arrayProp, string fallback)
    {
        try
        {
            if (root.TryGetProperty(section, out var sectionEl) &&
                sectionEl.ValueKind != System.Text.Json.JsonValueKind.Null)
            {
                System.Text.Json.JsonElement arrEl;
                if (sectionEl.TryGetProperty(arrayProp, out arrEl) &&
                    arrEl.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    var items = new List<string>();
                    foreach (var item in arrEl.EnumerateArray())
                    {
                        var val = item.GetString();
                        if (!string.IsNullOrEmpty(val)) items.Add(val);
                    }
                    if (items.Any()) return string.Join(", ", items);
                }
            }
        }
        catch { }
        return fallback;
    }

    // CHANGE: Helper to get line item matching detail from JSON
    private static string GetLineItemDetail(System.Text.Json.JsonElement root)
    {
        try
        {
            if (root.TryGetProperty("LineItemMatching", out var sectionEl) &&
                sectionEl.ValueKind != System.Text.Json.JsonValueKind.Null)
            {
                System.Text.Json.JsonElement arrEl;
                if (sectionEl.TryGetProperty("MissingItemCodes", out arrEl) &&
                    arrEl.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    var items = new List<string>();
                    foreach (var item in arrEl.EnumerateArray())
                    {
                        var val = item.GetString();
                        if (!string.IsNullOrEmpty(val)) items.Add(val);
                    }
                    if (items.Any()) return $"Missing {items.Count} PO line items in Invoice: {string.Join(", ", items)}";
                }
            }
        }
        catch { }
        return "Some PO line items missing in Invoice";
    }

    // CHANGE: Helper to extract Issues array from a validation section as a joined string
    private static string GetJsonIssues(System.Text.Json.JsonElement root, string section)
    {
        try
        {
            if (root.TryGetProperty(section, out var sectionEl) &&
                sectionEl.ValueKind != System.Text.Json.JsonValueKind.Null)
            {
                // Try both PascalCase and camelCase for Issues property
                System.Text.Json.JsonElement issuesEl;
                if ((sectionEl.TryGetProperty("Issues", out issuesEl) || sectionEl.TryGetProperty("issues", out issuesEl)) &&
                    issuesEl.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    var issues = new List<string>();
                    foreach (var item in issuesEl.EnumerateArray())
                    {
                        var val = item.GetString();
                        if (!string.IsNullOrEmpty(val)) issues.Add(val);
                    }
                    if (issues.Any()) return string.Join(", ", issues);
                }
            }
        }
        catch { }
        return "Validation checks failed";
    }

    // CHANGE: Helper to extract MissingFields array from a validation section
    private static string GetJsonIssueDetail(System.Text.Json.JsonElement root, string section, string arrayProp)
    {
        try
        {
            if (root.TryGetProperty(section, out var sectionEl) &&
                sectionEl.ValueKind != System.Text.Json.JsonValueKind.Null)
            {
                // Try both PascalCase and camelCase
                System.Text.Json.JsonElement arrEl;
                if ((sectionEl.TryGetProperty(arrayProp, out arrEl) || 
                     sectionEl.TryGetProperty(char.ToLower(arrayProp[0]) + arrayProp.Substring(1), out arrEl)) &&
                    arrEl.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    var items = new List<string>();
                    foreach (var item in arrEl.EnumerateArray())
                    {
                        var val = item.GetString();
                        if (!string.IsNullOrEmpty(val)) items.Add(val);
                    }
                    if (items.Any()) return "Missing: " + string.Join(", ", items);
                }

                // Also try reading Issues as fallback (some sections store errors in Issues not MissingFields)
                System.Text.Json.JsonElement issuesEl;
                if ((sectionEl.TryGetProperty("Issues", out issuesEl) || sectionEl.TryGetProperty("issues", out issuesEl)) &&
                    issuesEl.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    var issues = new List<string>();
                    foreach (var item in issuesEl.EnumerateArray())
                    {
                        var val = item.GetString();
                        if (!string.IsNullOrEmpty(val)) issues.Add(val);
                    }
                    if (issues.Any()) return string.Join(", ", issues);
                }
            }
        }
        catch { }
        return "Some required fields are missing";
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
