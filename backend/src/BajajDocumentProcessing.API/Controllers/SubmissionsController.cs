using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

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
    /// Create a new submission
    /// </summary>
    [HttpPost]
    [Authorize(Roles = "Agency")]
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
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.DocumentPackages.Add(package);
            await _context.SaveChangesAsync(cancellationToken);

            // Queue workflow for background processing (non-blocking)
            await _backgroundQueue.QueueWorkflowAsync(package.Id);
            
            _logger.LogInformation("Submission {PackageId} created and queued for processing", package.Id);

            return CreatedAtAction(
                nameof(GetSubmission),
                new { id = package.Id },
                new { id = package.Id, state = package.State.ToString(), message = "Submission received and is being processed" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating submission");
            return StatusCode(500, new { error = "An error occurred while creating the submission" });
        }
    }

    /// <summary>
    /// Get submission details by ID
    /// </summary>
    [HttpGet("{id}")]
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

            return Ok(new
            {
                id = package.Id,
                state = package.State.ToString(),
                createdAt = package.CreatedAt,
                updatedAt = package.UpdatedAt,
                // ASM Approval info
                asmReviewedAt = package.ASMReviewedAt,
                asmReviewNotes = package.ASMReviewNotes,
                // HQ Approval info
                hqReviewedAt = package.HQReviewedAt,
                hqReviewNotes = package.HQReviewNotes,
                // Legacy review info
                reviewedAt = package.ReviewedAt,
                reviewNotes = package.ReviewNotes,
                documents = package.Documents.Select(d => new
                {
                    id = d.Id,
                    type = d.Type.ToString(),
                    filename = d.FileName,
                    blobUrl = d.BlobUrl,
                    extractionConfidence = d.ExtractionConfidence,
                    extractedData = d.ExtractedDataJson
                }),
                validationResult = package.ValidationResult != null ? new
                {
                    allValidationsPassed = package.ValidationResult.AllValidationsPassed,
                    failureReason = package.ValidationResult.FailureReason
                } : null,
                confidenceScore = package.ConfidenceScore != null ? new
                {
                    overallConfidence = package.ConfidenceScore.OverallConfidence,
                    poConfidence = package.ConfidenceScore.PoConfidence,
                    invoiceConfidence = package.ConfidenceScore.InvoiceConfidence,
                    costSummaryConfidence = package.ConfidenceScore.CostSummaryConfidence,
                    activityConfidence = package.ConfidenceScore.ActivityConfidence,
                    photosConfidence = package.ConfidenceScore.PhotosConfidence
                } : null,
                recommendation = package.Recommendation != null ? new
                {
                    type = package.Recommendation.Type.ToString(),
                    evidence = package.Recommendation.Evidence
                } : null
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while retrieving the submission" });
        }
    }

    /// <summary>
    /// List submissions with filtering
    /// </summary>
    [HttpGet]
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

            return Ok(new
            {
                total,
                page,
                pageSize,
                items = packages.Select(p =>
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

                    return new
                    {
                        id = p.Id,
                        state = p.State.ToString(),
                        createdAt = p.CreatedAt,
                        updatedAt = p.UpdatedAt,
                        documentCount = p.Documents.Count,
                        invoiceNumber = invoiceNumber,
                        invoiceAmount = invoiceAmount,
                        poNumber = poNumber,
                        poAmount = poAmount,
                        overallConfidence = p.ConfidenceScore?.OverallConfidence
                    };
                })
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing submissions");
            return StatusCode(500, new { error = "An error occurred while listing submissions" });
        }
    }

    /// <summary>
    /// Approve a submission by ASM - moves to HQ approval
    /// </summary>
    [HttpPatch("{id}/asm-approve")]
    [Authorize(Roles = "ASM")]
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

            if (package.State != PackageState.PendingASMApproval)
            {
                return BadRequest(new { error = $"Submission is not in pending ASM approval state. Current state: {package.State}" });
            }

            package.State = PackageState.PendingHQApproval;
            package.ASMReviewedByUserId = userId;
            package.ASMReviewedAt = DateTime.UtcNow;
            package.ASMReviewNotes = request?.Notes ?? "Approved by ASM";
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} approved by ASM {UserId}, moved to HQ approval", id, userId);

            return Ok(new { id = package.Id, state = package.State.ToString(), message = "Approved by ASM, pending HQ approval" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error approving submission {Id} by ASM", id);
            return StatusCode(500, new { error = "An error occurred while approving the submission" });
        }
    }

    /// <summary>
    /// Reject a submission by ASM - sends back to Agency
    /// </summary>
    [HttpPatch("{id}/asm-reject")]
    [Authorize(Roles = "ASM")]
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

            if (package.State != PackageState.PendingASMApproval)
            {
                return BadRequest(new { error = $"Submission is not in pending ASM approval state. Current state: {package.State}" });
            }

            package.State = PackageState.RejectedByASM;
            package.ASMReviewedByUserId = userId;
            package.ASMReviewedAt = DateTime.UtcNow;
            package.ASMReviewNotes = request.Reason;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} rejected by ASM {UserId} with reason: {Reason}", id, userId, request.Reason);

            return Ok(new { id = package.Id, state = package.State.ToString(), message = "Rejected by ASM" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error rejecting submission {Id} by ASM", id);
            return StatusCode(500, new { error = "An error occurred while rejecting the submission" });
        }
    }

    /// <summary>
    /// Approve a submission by HQ - final approval
    /// </summary>
    [HttpPatch("{id}/hq-approve")]
    [Authorize(Roles = "HQ")]
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

            return Ok(new { id = package.Id, state = package.State.ToString(), message = "Final approval by HQ" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error approving submission {Id} by HQ", id);
            return StatusCode(500, new { error = "An error occurred while approving the submission" });
        }
    }

    /// <summary>
    /// Reject a submission by HQ - sends back to ASM
    /// </summary>
    [HttpPatch("{id}/hq-reject")]
    [Authorize(Roles = "HQ")]
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

            return Ok(new { id = package.Id, state = package.State.ToString(), message = "Rejected by HQ, sent back to ASM" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error rejecting submission {Id} by HQ", id);
            return StatusCode(500, new { error = "An error occurred while rejecting the submission" });
        }
    }

    /// <summary>
    /// Legacy approve endpoint - kept for backward compatibility
    /// </summary>
    [HttpPatch("{id}/approve")]
    [Authorize(Roles = "ASM")]
    public async Task<IActionResult> ApproveSubmission(Guid id, CancellationToken cancellationToken)
    {
        // Redirect to ASM approve
        return await ASMApproveSubmission(id, null, cancellationToken);
    }

    /// <summary>
    /// Legacy reject endpoint - kept for backward compatibility
    /// </summary>
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
    /// Agency resubmits a rejected package for review
    /// </summary>
    [HttpPatch("{id}/resubmit")]
    [Authorize(Roles = "Agency")]
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

            return Ok(new 
            { 
                id = package.Id, 
                state = package.State.ToString(), 
                resubmissionCount = package.ResubmissionCount,
                message = "Package resubmitted successfully and workflow triggered" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resubmitting package {Id}", id);
            return StatusCode(500, new { error = "An error occurred while resubmitting the package" });
        }
    }

    /// <summary>
    /// ASM resubmits a package to HQ after HQ rejection
    /// </summary>
    [HttpPatch("{id}/resubmit-to-hq")]
    [Authorize(Roles = "ASM")]
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

            return Ok(new 
            { 
                id = package.Id, 
                state = package.State.ToString(), 
                hqResubmissionCount = package.HQResubmissionCount,
                message = "Package resubmitted to HQ successfully" 
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resubmitting package {Id} to HQ", id);
            return StatusCode(500, new { error = "An error occurred while resubmitting to HQ" });
        }
    }

    /// <summary>
    /// Request re-upload for a submission (ASM only)
    /// </summary>
    [HttpPatch("{id}/request-reupload")]
    [Authorize(Roles = "ASM")]
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

            return Ok(new { id = package.Id, state = package.State.ToString() });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error requesting reupload for submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while requesting reupload" });
        }
    }

    /// <summary>
    /// Submit/finalize a package for processing
    /// </summary>
    [HttpPost("{packageId}/submit")]
    [Authorize(Roles = "Agency")]
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

            return Ok(new 
            { 
                message = "Package submitted for processing", 
                packageId,
                documentCount = package.Documents.Count,
                status = "Queued for processing"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error submitting package {PackageId}", packageId);
            return StatusCode(500, new { error = "An error occurred while submitting the package" });
        }
    }

    /// <summary>
    /// Manually move submission to PendingApproval state (for testing without Azure services)
    /// </summary>
    [HttpPatch("{id}/move-to-pending")]
    [Authorize]
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

            return Ok(new { id = package.Id, state = package.State.ToString() });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error moving submission {Id} to pending approval", id);
            return StatusCode(500, new { error = "An error occurred while updating submission state" });
        }
    }

    /// <summary>
    /// Manually trigger workflow for a package (synchronous for testing)
    /// </summary>
    [HttpPost("{packageId}/process-now")]
    [Authorize]
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

            return Ok(new 
            { 
                success = result,
                packageId,
                currentState = package?.State.ToString() ?? "Unknown",
                message = result ? "Workflow completed successfully" : "Workflow failed - check logs"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing package {PackageId}", packageId);
            return StatusCode(500, new { error = $"Error: {ex.Message}" });
        }
    }
}

public record CreateSubmissionRequest();

public record ApproveSubmissionRequest(string? Notes);

public record RejectSubmissionRequest(string Reason);

public record ResubmitToHQRequest(string Notes);

public record RequestReuploadRequest(List<string> Fields);
