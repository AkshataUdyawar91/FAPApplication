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
                // CHANGE: Added validationDetails list showing all checks (pass + fail) alongside failureReason
                validationResult = package.ValidationResult != null ? new
                {
                    allValidationsPassed = package.ValidationResult.AllValidationsPassed,
                    validationDetails = BuildValidationDetails(package.ValidationResult)
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

public record CreateSubmissionRequest();

public record ApproveSubmissionRequest(string? Notes);

public record RejectSubmissionRequest(string Reason);

public record ResubmitToHQRequest(string Notes);

public record RequestReuploadRequest(List<string> Fields);
