using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
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
    private readonly ILogger<SubmissionsController> _logger;

    public SubmissionsController(
        IApplicationDbContext context,
        IWorkflowOrchestrator orchestrator,
        ILogger<SubmissionsController> logger)
    {
        _context = context;
        _orchestrator = orchestrator;
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
            var userId = Guid.Parse(User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());

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

            // Start workflow orchestration asynchronously
            _ = Task.Run(async () =>
            {
                try
                {
                    await _orchestrator.ProcessSubmissionAsync(package.Id, CancellationToken.None);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing submission {PackageId}", package.Id);
                }
            }, cancellationToken);

            return CreatedAtAction(
                nameof(GetSubmission),
                new { id = package.Id },
                new { id = package.Id, state = package.State.ToString() });
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
            var userId = Guid.Parse(User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            var userRole = User.FindFirst("role")?.Value;

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

            var query = _context.DocumentPackages
                .Include(p => p.Documents)
                .Include(p => p.ConfidenceScore)
                .AsQueryable();

            // Agency users can only see their own submissions
            if (userRole == "Agency")
            {
                query = query.Where(p => p.SubmittedByUserId == userId);
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
    /// Approve a submission (ASM only)
    /// </summary>
    [HttpPatch("{id}/approve")]
    [Authorize(Roles = "ASM")]
    public async Task<IActionResult> ApproveSubmission(Guid id, CancellationToken cancellationToken)
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

            package.State = PackageState.Approved;
            package.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Submission {Id} approved", id);

            return Ok(new { id = package.Id, state = package.State.ToString() });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error approving submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while approving the submission" });
        }
    }

    /// <summary>
    /// Reject a submission (ASM only)
    /// </summary>
    [HttpPatch("{id}/reject")]
    [Authorize(Roles = "ASM")]
    public async Task<IActionResult> RejectSubmission(
        Guid id,
        [FromBody] RejectSubmissionRequest request,
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

            _logger.LogInformation("Submission {Id} rejected with reason: {Reason}", id, request.Reason);

            return Ok(new { id = package.Id, state = package.State.ToString() });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error rejecting submission {Id}", id);
            return StatusCode(500, new { error = "An error occurred while rejecting the submission" });
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

            // Trigger workflow orchestrator asynchronously
            _ = Task.Run(async () =>
            {
                try
                {
                    _logger.LogInformation("Starting background workflow for package {PackageId}", packageId);
                    await _orchestrator.ProcessSubmissionAsync(packageId, CancellationToken.None);
                    _logger.LogInformation("Background workflow completed for package {PackageId}", packageId);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing package {PackageId} in background", packageId);
                }
            }, cancellationToken);

            return Ok(new 
            { 
                message = "Package submitted for processing", 
                packageId,
                documentCount = package.Documents.Count,
                status = "Processing started in background"
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

public record RejectSubmissionRequest(string Reason);

public record RequestReuploadRequest(List<string> Fields);
