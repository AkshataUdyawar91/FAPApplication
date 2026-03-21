using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin read-only endpoint for enquiry document dump per FAP.</summary>
[ApiController]
[Route("api/admin/enquiry-dump")]
[Authorize(Roles = "Admin")]
public class AdminEnquiryDumpController : ControllerBase
{
    private readonly IApplicationDbContext _context;

    public AdminEnquiryDumpController(IApplicationDbContext context) => _context = context;

    /// <summary>Paginated list of FAPs with their enquiry document extracted data.</summary>
    [HttpGet]
    public async Task<IActionResult> GetEnquiryDump(
        [FromQuery] int pageNumber          = 1,
        [FromQuery] int pageSize            = 10,
        [FromQuery] string? search          = null,
        [FromQuery] string? locationFilter  = null,
        CancellationToken ct = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize   = Math.Clamp(pageSize, 1, 100);

        var query = _context.EnquiryDocuments
            .AsNoTracking()
            .Include(e => e.DocumentPackage)
                .ThenInclude(p => p.Agency)
            .Where(e => !e.IsDeleted && !e.DocumentPackage.IsDeleted)
            .AsQueryable();

        // Search by submission number or agency name
        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(e =>
                (e.DocumentPackage.SubmissionNumber != null &&
                 e.DocumentPackage.SubmissionNumber.ToLower().Contains(s)) ||
                e.DocumentPackage.Agency.SupplierName.ToLower().Contains(s) ||
                e.DocumentPackage.Agency.SupplierCode.ToLower().Contains(s));
        }

        // Filter by ActivityState (location)
        if (!string.IsNullOrWhiteSpace(locationFilter))
        {
            query = query.Where(e =>
                e.DocumentPackage.ActivityState != null &&
                e.DocumentPackage.ActivityState == locationFilter);
        }

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(e => e.DocumentPackage.CreatedAt)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .Select(e => new
            {
                id                  = e.Id,
                packageId           = e.PackageId,
                submissionNumber    = e.DocumentPackage.SubmissionNumber,
                agencyCode          = e.DocumentPackage.Agency.SupplierCode,
                agencyName          = e.DocumentPackage.Agency.SupplierName,
                location            = e.DocumentPackage.ActivityState,
                fileName            = e.FileName,
                extractedDataJson   = e.ExtractedDataJson,
                extractionConfidence= e.ExtractionConfidence,
                isFlaggedForReview  = e.IsFlaggedForReview,
                versionNumber       = e.VersionNumber,
                submittedOn         = e.DocumentPackage.CreatedAt,
            })
            .ToListAsync(ct);

        // Distinct locations for filter dropdown
        var locations = await _context.EnquiryDocuments
            .AsNoTracking()
            .Where(e => !e.IsDeleted && !e.DocumentPackage.IsDeleted &&
                        e.DocumentPackage.ActivityState != null)
            .Select(e => e.DocumentPackage.ActivityState!)
            .Distinct()
            .OrderBy(x => x)
            .ToListAsync(ct);

        return Ok(new
        {
            items,
            totalCount  = total,
            pageNumber,
            pageSize,
            totalPages  = (int)Math.Ceiling((double)total / pageSize),
            locations,
        });
    }
}
