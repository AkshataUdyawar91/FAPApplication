using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Common;
using BajajDocumentProcessing.Application.DTOs.Conversation;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Purchase Orders controller for PO search and filtered listing.
/// Supports typeahead search and progressive filtering with pagination.
/// </summary>
[ApiController]
[Route("api/purchase-orders")]
[Authorize]
public class PurchaseOrdersController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<PurchaseOrdersController> _logger;

    public PurchaseOrdersController(
        IApplicationDbContext context,
        ILogger<PurchaseOrdersController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Typeahead search for purchase orders by PO number.
    /// Returns max 10 results matching the partial PO number.
    /// </summary>
    /// <param name="vendorCode">Agency vendor code to filter POs</param>
    /// <param name="q">Partial PO number for LIKE search (min 1 char)</param>
    /// <param name="status">Comma-separated PO statuses to filter (e.g., "Open,PartiallyConsumed")</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of matching POs (max 10)</returns>
    [HttpGet("search")]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(List<POSearchResult>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> SearchPurchaseOrders(
        [FromQuery] string? vendorCode,
        [FromQuery] string? q,
        [FromQuery] string? status,
        CancellationToken cancellationToken)
    {
        try
        {
            var agencyId = await GetCurrentUserAgencyIdAsync(cancellationToken);
            if (agencyId == null)
                return Forbid();

            var query = _context.POs
                .Where(po => !po.IsDeleted && po.AgencyId == agencyId.Value)
                // Only show unlinked master POs, or POs from rejected/reupload submissions (available to reuse)
                .Where(po => po.PackageId == null ||
                             _context.DocumentPackages.Any(dp =>
                                 dp.Id == po.PackageId &&
                                 (dp.State == PackageState.CHRejected || dp.State == PackageState.RARejected)))
                .AsQueryable();

            // Filter by vendor code if provided
            if (!string.IsNullOrWhiteSpace(vendorCode))
                query = query.Where(po => po.VendorCode == vendorCode);

            // Filter by PO statuses if provided
            if (!string.IsNullOrWhiteSpace(status))
            {
                var statuses = status.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                query = query.Where(po => po.POStatus != null && statuses.Contains(po.POStatus));
            }

            // LIKE search on PONumber
            if (!string.IsNullOrWhiteSpace(q))
                query = query.Where(po => po.PONumber != null && po.PONumber.Contains(q));

            var results = await query
                .OrderByDescending(po => po.PODate)
                .Take(10)
                .Select(po => new POSearchResult
                {
                    Id = po.Id,
                    PONumber = po.PONumber ?? string.Empty,
                    PODate = po.PODate ?? DateTime.MinValue,
                    VendorName = po.VendorName ?? string.Empty,
                    TotalAmount = po.TotalAmount ?? 0,
                    RemainingBalance = po.RemainingBalance,
                    POStatus = po.POStatus
                })
                .ToListAsync(cancellationToken);

            if (results.Count == 0)
            {
                return Ok(new
                {
                    items = Array.Empty<POSearchResult>(),
                    message = BuildZeroResultsMessage(q, status)
                });
            }

            return Ok(results);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching purchase orders");
            return StatusCode(500, new { error = "An error occurred while searching purchase orders" });
        }
    }

    /// <summary>
    /// Filtered list of purchase orders with pagination.
    /// Supports date range, amount range, sorting, and pagination.
    /// </summary>
    /// <param name="vendorCode">Agency vendor code to filter POs</param>
    /// <param name="dateFrom">Start date filter (inclusive)</param>
    /// <param name="dateTo">End date filter (inclusive)</param>
    /// <param name="amountMin">Minimum total amount filter</param>
    /// <param name="amountMax">Maximum total amount filter</param>
    /// <param name="sort">Sort expression (e.g., "poDate:desc", "totalAmount:asc")</param>
    /// <param name="page">Page number (1-based, default 1)</param>
    /// <param name="size">Page size (default 5, max 50)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Paginated list of POs</returns>
    [HttpGet]
    [Authorize(Roles = "Agency")]
    [ProducesResponseType(typeof(PagedResponse<POSearchResult>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ListPurchaseOrders(
        [FromQuery] string? vendorCode,
        [FromQuery] DateTime? dateFrom,
        [FromQuery] DateTime? dateTo,
        [FromQuery] decimal? amountMin,
        [FromQuery] decimal? amountMax,
        [FromQuery] string? sort,
        [FromQuery] int page = 1,
        [FromQuery] int size = 5,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var agencyId = await GetCurrentUserAgencyIdAsync(cancellationToken);
            if (agencyId == null)
                return Forbid();

            // Clamp page size
            size = Math.Clamp(size, 1, 50);
            page = Math.Max(page, 1);

            var query = _context.POs
                .Where(po => !po.IsDeleted && po.AgencyId == agencyId.Value)
                // Only show unlinked master POs, or POs from rejected/reupload submissions
                .Where(po => po.PackageId == null ||
                             _context.DocumentPackages.Any(dp =>
                                 dp.Id == po.PackageId &&
                                 (dp.State == PackageState.CHRejected || dp.State == PackageState.RARejected)))
                .AsQueryable();

            // Filter by vendor code
            if (!string.IsNullOrWhiteSpace(vendorCode))
                query = query.Where(po => po.VendorCode == vendorCode);

            // Date range filter
            if (dateFrom.HasValue)
                query = query.Where(po => po.PODate >= dateFrom.Value);
            if (dateTo.HasValue)
                query = query.Where(po => po.PODate <= dateTo.Value);

            // Amount range filter
            if (amountMin.HasValue)
                query = query.Where(po => po.TotalAmount >= amountMin.Value);
            if (amountMax.HasValue)
                query = query.Where(po => po.TotalAmount <= amountMax.Value);

            // Sorting
            query = ApplySorting(query, sort);

            // Pagination
            var total = await query.CountAsync(cancellationToken);

            var items = await query
                .Skip((page - 1) * size)
                .Take(size)
                .Select(po => new POSearchResult
                {
                    Id = po.Id,
                    PONumber = po.PONumber ?? string.Empty,
                    PODate = po.PODate ?? DateTime.MinValue,
                    VendorName = po.VendorName ?? string.Empty,
                    TotalAmount = po.TotalAmount ?? 0,
                    RemainingBalance = po.RemainingBalance,
                    POStatus = po.POStatus
                })
                .ToListAsync(cancellationToken);

            if (total == 0)
            {
                return Ok(new
                {
                    total = 0,
                    page,
                    pageSize = size,
                    totalPages = 0,
                    hasNextPage = false,
                    hasPreviousPage = false,
                    items = Array.Empty<POSearchResult>(),
                    message = "No purchase orders found matching the specified filters. POs sync from SAP every 4 hours — if a recent PO is missing, please check back shortly."
                });
            }

            var response = new PagedResponse<POSearchResult>
            {
                Total = total,
                Page = page,
                PageSize = size,
                Items = items
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing purchase orders");
            return StatusCode(500, new { error = "An error occurred while listing purchase orders" });
        }
    }

    /// <summary>
    /// Resolves the AgencyId for the current authenticated user.
    /// </summary>
    private async Task<Guid?> GetCurrentUserAgencyIdAsync(CancellationToken cancellationToken)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("User ID claim not found or invalid in token");
            return null;
        }

        var user = await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId && !u.IsDeleted)
            .Select(u => new { u.AgencyId })
            .FirstOrDefaultAsync(cancellationToken);

        if (user?.AgencyId == null)
        {
            _logger.LogWarning("User {UserId} has no associated agency", userId);
            return null;
        }

        return user.AgencyId;
    }

    /// <summary>
    /// Applies sorting to the PO query based on the sort parameter.
    /// Format: "field:direction" (e.g., "poDate:desc", "totalAmount:asc").
    /// Defaults to poDate:desc.
    /// </summary>
    private static IQueryable<Domain.Entities.PO> ApplySorting(
        IQueryable<Domain.Entities.PO> query,
        string? sort)
    {
        if (string.IsNullOrWhiteSpace(sort))
            return query.OrderByDescending(po => po.PODate);

        var parts = sort.Split(':', 2);
        var field = parts[0].Trim().ToLowerInvariant();
        var descending = parts.Length > 1 && parts[1].Trim().Equals("desc", StringComparison.OrdinalIgnoreCase);

        return field switch
        {
            "podate" => descending ? query.OrderByDescending(po => po.PODate) : query.OrderBy(po => po.PODate),
            "totalamount" => descending ? query.OrderByDescending(po => po.TotalAmount) : query.OrderBy(po => po.TotalAmount),
            "ponumber" => descending ? query.OrderByDescending(po => po.PONumber) : query.OrderBy(po => po.PONumber),
            "remainingbalance" => descending ? query.OrderByDescending(po => po.RemainingBalance) : query.OrderBy(po => po.RemainingBalance),
            _ => query.OrderByDescending(po => po.PODate)
        };
    }

    /// <summary>
    /// Builds a descriptive message when search returns zero results.
    /// </summary>
    private static string BuildZeroResultsMessage(string? searchTerm, string? statusFilter)
    {
        if (!string.IsNullOrWhiteSpace(searchTerm))
        {
            return $"No purchase orders found matching \"{searchTerm}\". "
                   + "The PO may be closed or not yet synced from SAP. POs sync every 4 hours.";
        }

        if (!string.IsNullOrWhiteSpace(statusFilter))
        {
            return $"No purchase orders found with status {statusFilter}. "
                   + "Try broadening your search or check if the PO has been fully consumed.";
        }

        return "No open purchase orders found for your agency. "
               + "POs sync from SAP every 4 hours — if a recent PO is missing, please check back shortly.";
    }
}
