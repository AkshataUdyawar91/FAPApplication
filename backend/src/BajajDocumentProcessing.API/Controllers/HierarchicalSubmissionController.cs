using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Text.Json;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Controller for hierarchical document submission (FAP → PO → Invoices → Campaigns → Photos)
/// </summary>
[ApiController]
[Route("api/hierarchical")]
[Authorize]
public class HierarchicalSubmissionController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly IFileStorageService _fileStorage;
    private readonly ILogger<HierarchicalSubmissionController> _logger;

    public HierarchicalSubmissionController(
        IApplicationDbContext context,
        IFileStorageService fileStorage,
        ILogger<HierarchicalSubmissionController> logger)
    {
        _context = context;
        _fileStorage = fileStorage;
        _logger = logger;
    }

    /// <summary>
    /// Add an invoice to a package (linked to PO)
    /// </summary>
    [HttpPost("{packageId}/invoices")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddInvoice(
        Guid packageId,
        [FromForm] AddInvoiceRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .Include(p => p.Documents)
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            // Find the PO document
            var poDocument = package.Documents.FirstOrDefault(d => d.Type == DocumentType.PO);
            if (poDocument == null)
                return BadRequest(new { error = "PO document must be uploaded first" });

            // Upload file
            string blobUrl = "";
            if (request.File != null)
            {
                blobUrl = await _fileStorage.UploadFileAsync(request.File, "invoices", $"{Guid.NewGuid()}_{request.File.FileName}");
            }

            var invoice = new Invoice
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                PODocumentId = poDocument.Id,
                InvoiceNumber = request.InvoiceNumber,
                InvoiceDate = request.InvoiceDate,
                VendorName = request.VendorName,
                GSTNumber = request.GSTNumber,
                TotalAmount = request.TotalAmount,
                FileName = request.File?.FileName ?? "",
                BlobUrl = blobUrl,
                FileSizeBytes = request.File?.Length ?? 0,
                ContentType = request.File?.ContentType ?? "",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Invoices.Add(invoice);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Invoice {InvoiceId} added to package {PackageId}", invoice.Id, packageId);

            return Ok(new { invoiceId = invoice.Id, message = "Invoice added successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding invoice to package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to add invoice" });
        }
    }

    /// <summary>
    /// Add a campaign to an invoice
    /// </summary>
    [HttpPost("{packageId}/invoices/{invoiceId}/campaigns")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddCampaign(
        Guid packageId,
        Guid invoiceId,
        [FromBody] AddCampaignRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var invoice = await _context.Invoices
                .Include(i => i.Package)
                .FirstOrDefaultAsync(i => i.Id == invoiceId && i.PackageId == packageId, cancellationToken);

            if (invoice == null || invoice.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Invoice not found" });

            var campaign = new Campaign
            {
                Id = Guid.NewGuid(),
                InvoiceId = invoiceId,
                PackageId = packageId,
                CampaignName = request.CampaignName,
                StartDate = request.StartDate,
                EndDate = request.EndDate,
                WorkingDays = request.WorkingDays,
                DealershipName = request.DealershipName,
                DealershipAddress = request.DealershipAddress,
                GPSLocation = request.GPSLocation,
                State = request.State,
                TotalCost = request.TotalCost,
                TeamsJson = request.TeamsJson,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Campaigns.Add(campaign);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Campaign {CampaignId} added to invoice {InvoiceId}", campaign.Id, invoiceId);

            return Ok(new { campaignId = campaign.Id, message = "Campaign added successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding campaign to invoice {InvoiceId}", invoiceId);
            return StatusCode(500, new { error = "Failed to add campaign" });
        }
    }

    /// <summary>
    /// Add photos to a campaign
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/photos")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddPhotos(
        Guid packageId,
        Guid campaignId,
        [FromForm] List<IFormFile> files,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var campaign = await _context.Campaigns
                .Include(c => c.Package)
                .FirstOrDefaultAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);

            if (campaign == null || campaign.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Campaign not found" });

            var photoIds = new List<Guid>();
            var displayOrder = await _context.CampaignPhotos
                .Where(p => p.CampaignId == campaignId)
                .CountAsync(cancellationToken);

            foreach (var file in files)
            {
                // Upload file
                var blobUrl = await _fileStorage.UploadFileAsync(file, "photos", $"{Guid.NewGuid()}_{file.FileName}");

                var photo = new CampaignPhoto
                {
                    Id = Guid.NewGuid(),
                    CampaignId = campaignId,
                    PackageId = packageId,
                    FileName = file.FileName,
                    BlobUrl = blobUrl,
                    FileSizeBytes = file.Length,
                    ContentType = file.ContentType,
                    DisplayOrder = displayOrder++,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                _context.CampaignPhotos.Add(photo);
                photoIds.Add(photo.Id);
            }

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("{Count} photos added to campaign {CampaignId}", files.Count, campaignId);

            return Ok(new { photoIds, message = $"{files.Count} photos added successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding photos to campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to add photos" });
        }
    }

    /// <summary>
    /// Get hierarchical structure for a package
    /// </summary>
    [HttpGet("{packageId}/structure")]
    public async Task<IActionResult> GetHierarchicalStructure(Guid packageId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;

            var package = await _context.DocumentPackages
                .Include(p => p.Documents)
                .Include(p => p.Invoices)
                    .ThenInclude(i => i.Campaigns)
                        .ThenInclude(c => c.Photos)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            // Agency users can only see their own packages
            if (userRole == "Agency" && package.SubmittedByUserId != userId)
                return NotFound(new { error = "Package not found" });

            var poDocument = package.Documents.FirstOrDefault(d => d.Type == DocumentType.PO);

            var response = new HierarchicalStructureResponse
            {
                PackageId = package.Id,
                State = package.State.ToString(),
                CreatedAt = package.CreatedAt,
                PO = poDocument != null ? new POInfo
                {
                    DocumentId = poDocument.Id,
                    FileName = poDocument.FileName,
                    ExtractedData = poDocument.ExtractedDataJson
                } : null,
                Invoices = package.Invoices.Select(i => new InvoiceInfo
                {
                    InvoiceId = i.Id,
                    InvoiceNumber = i.InvoiceNumber,
                    InvoiceDate = i.InvoiceDate,
                    TotalAmount = i.TotalAmount,
                    FileName = i.FileName,
                    Campaigns = i.Campaigns.Select(c => new CampaignInfo
                    {
                        CampaignId = c.Id,
                        CampaignName = c.CampaignName,
                        StartDate = c.StartDate,
                        EndDate = c.EndDate,
                        DealershipName = c.DealershipName,
                        TotalCost = c.TotalCost,
                        PhotoCount = c.Photos.Count,
                        Photos = c.Photos.OrderBy(p => p.DisplayOrder).Select(p => new PhotoInfo
                        {
                            PhotoId = p.Id,
                            FileName = p.FileName,
                            BlobUrl = p.BlobUrl,
                            PhotoTimestamp = p.PhotoTimestamp
                        }).ToList()
                    }).ToList()
                }).ToList()
            };

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting hierarchical structure for package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to get package structure" });
        }
    }

    /// <summary>
    /// Delete an invoice and all its campaigns/photos
    /// </summary>
    [HttpDelete("{packageId}/invoices/{invoiceId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeleteInvoice(Guid packageId, Guid invoiceId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var invoice = await _context.Invoices
                .Include(i => i.Package)
                .FirstOrDefaultAsync(i => i.Id == invoiceId && i.PackageId == packageId, cancellationToken);

            if (invoice == null || invoice.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Invoice not found" });

            // Soft delete
            invoice.IsDeleted = true;
            invoice.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Invoice {InvoiceId} deleted from package {PackageId}", invoiceId, packageId);

            return Ok(new { message = "Invoice deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting invoice {InvoiceId}", invoiceId);
            return StatusCode(500, new { error = "Failed to delete invoice" });
        }
    }

    /// <summary>
    /// Delete a campaign and all its photos
    /// </summary>
    [HttpDelete("{packageId}/campaigns/{campaignId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeleteCampaign(Guid packageId, Guid campaignId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var campaign = await _context.Campaigns
                .Include(c => c.Package)
                .FirstOrDefaultAsync(c => c.Id == campaignId && c.PackageId == packageId, cancellationToken);

            if (campaign == null || campaign.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Campaign not found" });

            campaign.IsDeleted = true;
            campaign.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Campaign {CampaignId} deleted from package {PackageId}", campaignId, packageId);

            return Ok(new { message = "Campaign deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to delete campaign" });
        }
    }

    /// <summary>
    /// Delete a photo
    /// </summary>
    [HttpDelete("{packageId}/photos/{photoId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeletePhoto(Guid packageId, Guid photoId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var photo = await _context.CampaignPhotos
                .Include(p => p.Package)
                .FirstOrDefaultAsync(p => p.Id == photoId && p.PackageId == packageId, cancellationToken);

            if (photo == null || photo.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Photo not found" });

            photo.IsDeleted = true;
            photo.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Photo {PhotoId} deleted from package {PackageId}", photoId, packageId);

            return Ok(new { message = "Photo deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting photo {PhotoId}", photoId);
            return StatusCode(500, new { error = "Failed to delete photo" });
        }
    }

    private Guid GetUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(userIdClaim))
            throw new System.UnauthorizedAccessException("User ID not found in token");
        return Guid.Parse(userIdClaim);
    }
}

// Request DTOs
public class AddInvoiceRequest
{
    public IFormFile? File { get; set; }
    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public string? VendorName { get; set; }
    public string? GSTNumber { get; set; }
    public decimal? TotalAmount { get; set; }
}

public class AddCampaignRequest
{
    public string? CampaignName { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? WorkingDays { get; set; }
    public string? DealershipName { get; set; }
    public string? DealershipAddress { get; set; }
    public string? GPSLocation { get; set; }
    public string? State { get; set; }
    public decimal? TotalCost { get; set; }
    public string? TeamsJson { get; set; }
}

// Response DTOs
public class HierarchicalStructureResponse
{
    public Guid PackageId { get; set; }
    public string State { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public POInfo? PO { get; set; }
    public List<InvoiceInfo> Invoices { get; set; } = new();
}

public class POInfo
{
    public Guid DocumentId { get; set; }
    public string FileName { get; set; } = "";
    public string? ExtractedData { get; set; }
}

public class InvoiceInfo
{
    public Guid InvoiceId { get; set; }
    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public decimal? TotalAmount { get; set; }
    public string FileName { get; set; } = "";
    public List<CampaignInfo> Campaigns { get; set; } = new();
}

public class CampaignInfo
{
    public Guid CampaignId { get; set; }
    public string? CampaignName { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? DealershipName { get; set; }
    public decimal? TotalCost { get; set; }
    public int PhotoCount { get; set; }
    public List<PhotoInfo> Photos { get; set; } = new();
}

public class PhotoInfo
{
    public Guid PhotoId { get; set; }
    public string FileName { get; set; } = "";
    public string BlobUrl { get; set; } = "";
    public DateTime? PhotoTimestamp { get; set; }
}
