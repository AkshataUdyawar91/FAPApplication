using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin read-only view of email delivery logs.</summary>
[ApiController]
[Route("api/admin/email-logs")]
[Authorize(Roles = "Admin")]
public class AdminEmailLogsController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<AdminEmailLogsController> _logger;

    public AdminEmailLogsController(IApplicationDbContext context, ILogger<AdminEmailLogsController> logger)
    {
        _context = context;
        _logger  = logger;
    }

    /// <summary>Get paginated email delivery logs.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetEmailLogs(
        [FromQuery] int pageNumber      = 1,
        [FromQuery] int pageSize        = 20,
        [FromQuery] string? search      = null,
        [FromQuery] bool? success       = null,
        [FromQuery] string? template    = null,
        CancellationToken ct = default)
    {
        try
        {
            pageNumber = Math.Max(1, pageNumber);
            pageSize   = Math.Clamp(pageSize, 1, 100);

            var query = _context.EmailDeliveryLogs
                .AsNoTracking()
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.Trim().ToLower();
                query = query.Where(e =>
                    e.RecipientEmail.ToLower().Contains(s) ||
                    e.Subject.ToLower().Contains(s));
            }

            if (success.HasValue)
                query = query.Where(e => e.Success == success.Value);

            if (!string.IsNullOrWhiteSpace(template))
                query = query.Where(e => e.TemplateName == template);

            var total = await query.CountAsync(ct);
            var items = await query
                .OrderByDescending(e => e.SentAt)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .Select(e => new
                {
                    e.Id,
                    e.PackageId,
                    e.RecipientEmail,
                    e.TemplateName,
                    e.Subject,
                    e.Success,
                    e.MessageId,
                    e.ErrorMessage,
                    e.AttemptsCount,
                    e.SentAt,
                })
                .ToListAsync(ct);

            return Ok(new
            {
                items,
                totalCount = total,
                pageNumber,
                pageSize,
                totalPages = (int)Math.Ceiling((double)total / pageSize),
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching email logs");
            return StatusCode(500, new { message = ex.Message });
        }
    }
}
