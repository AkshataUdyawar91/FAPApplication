using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

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
            var userId = Guid.Parse(User.FindFirst("sub")?.Value ?? throw new System.UnauthorizedAccessException());
            var userRole = User.FindFirst("role")?.Value;

            var query = _context.DocumentPackages
                .Include(p => p.Documents)
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
                items = packages.Select(p => new
                {
                    id = p.Id,
                    state = p.State.ToString(),
                    createdAt = p.CreatedAt,
                    updatedAt = p.UpdatedAt,
                    documentCount = p.Documents.Count
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
}

public record CreateSubmissionRequest();

public record RejectSubmissionRequest(string Reason);

public record RequestReuploadRequest(List<string> Fields);
