using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Controller for hierarchical document submission
/// New Structure: FAP → PO → Campaigns (Teams) → Invoices/Photos
/// Each Campaign has: multiple Invoices, multiple Photos, 1 Cost Summary, 1 Activity Summary
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
    /// Add a campaign (team) to a package
    /// </summary>
    [HttpPost("{packageId}/campaigns")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddCampaign(
        Guid packageId,
        [FromBody] AddCampaignRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            var campaign = new Campaign
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                CampaignName = request.CampaignName,
                TeamCode = request.TeamCode,
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

            _logger.LogInformation("Campaign {CampaignId} added to package {PackageId}", campaign.Id, packageId);

            return Ok(new { campaignId = campaign.Id, message = "Campaign added successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding campaign to package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to add campaign" });
        }
    }

    /// <summary>
    /// Add an invoice to a campaign
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/invoices")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> AddInvoiceToCampaign(
        Guid packageId,
        Guid campaignId,
        [FromForm] AddInvoiceRequest request,
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

            // Upload file
            string blobUrl = "";
            if (request.File != null)
            {
                blobUrl = await _fileStorage.UploadFileAsync(request.File, "invoices", $"{Guid.NewGuid()}_{request.File.FileName}");
            }

            var invoice = new CampaignInvoice
            {
                Id = Guid.NewGuid(),
                CampaignId = campaignId,
                PackageId = packageId,
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

            _context.CampaignInvoices.Add(invoice);
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Invoice {InvoiceId} added to campaign {CampaignId}", invoice.Id, campaignId);

            return Ok(new { invoiceId = invoice.Id, message = "Invoice added successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding invoice to campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to add invoice" });
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
    /// Upload cost summary for a campaign (1 per campaign)
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/cost-summary")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> UploadCostSummary(
        Guid packageId,
        Guid campaignId,
        [FromForm] IFormFile file,
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

            var blobUrl = await _fileStorage.UploadFileAsync(file, "cost-summaries", $"{Guid.NewGuid()}_{file.FileName}");

            campaign.CostSummaryFileName = file.FileName;
            campaign.CostSummaryBlobUrl = blobUrl;
            campaign.CostSummaryContentType = file.ContentType;
            campaign.CostSummaryFileSizeBytes = file.Length;
            campaign.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Cost summary uploaded for campaign {CampaignId}", campaignId);

            return Ok(new { message = "Cost summary uploaded successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading cost summary for campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to upload cost summary" });
        }
    }

    /// <summary>
    /// Upload activity summary for a campaign (1 per campaign)
    /// </summary>
    [HttpPost("{packageId}/campaigns/{campaignId}/activity-summary")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> UploadActivitySummary(
        Guid packageId,
        Guid campaignId,
        [FromForm] IFormFile file,
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

            var blobUrl = await _fileStorage.UploadFileAsync(file, "activity-summaries", $"{Guid.NewGuid()}_{file.FileName}");

            campaign.ActivitySummaryFileName = file.FileName;
            campaign.ActivitySummaryBlobUrl = blobUrl;
            campaign.ActivitySummaryContentType = file.ContentType;
            campaign.ActivitySummaryFileSizeBytes = file.Length;
            campaign.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Activity summary uploaded for campaign {CampaignId}", campaignId);

            return Ok(new { message = "Activity summary uploaded successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading activity summary for campaign {CampaignId}", campaignId);
            return StatusCode(500, new { error = "Failed to upload activity summary" });
        }
    }

    /// <summary>
    /// Upload enquiry document for a package (1 per package - Additional docs at PO level)
    /// </summary>
    [HttpPost("{packageId}/enquiry-doc")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> UploadEnquiryDoc(
        Guid packageId,
        [FromForm] IFormFile file,
        CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var package = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId && p.SubmittedByUserId == userId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

            var blobUrl = await _fileStorage.UploadFileAsync(file, "enquiry-docs", $"{Guid.NewGuid()}_{file.FileName}");

            package.EnquiryDocFileName = file.FileName;
            package.EnquiryDocBlobUrl = blobUrl;
            package.EnquiryDocContentType = file.ContentType;
            package.EnquiryDocFileSizeBytes = file.Length;
            package.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Enquiry document uploaded for package {PackageId}", packageId);

            return Ok(new { message = "Enquiry document uploaded successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading enquiry document for package {PackageId}", packageId);
            return StatusCode(500, new { error = "Failed to upload enquiry document" });
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
                .Include(p => p.Campaigns)
                    .ThenInclude(c => c.Invoices)
                .Include(p => p.Campaigns)
                    .ThenInclude(c => c.Photos)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
                return NotFound(new { error = "Package not found" });

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
                EnquiryDoc = package.EnquiryDocFileName != null ? new EnquiryDocInfo
                {
                    FileName = package.EnquiryDocFileName,
                    BlobUrl = package.EnquiryDocBlobUrl
                } : null,
                Campaigns = package.Campaigns.Select(c => new CampaignInfo
                {
                    CampaignId = c.Id,
                    CampaignName = c.CampaignName,
                    TeamCode = c.TeamCode,
                    StartDate = c.StartDate,
                    EndDate = c.EndDate,
                    WorkingDays = c.WorkingDays,
                    DealershipName = c.DealershipName,
                    TotalCost = c.TotalCost,
                    CostSummaryFileName = c.CostSummaryFileName,
                    ActivitySummaryFileName = c.ActivitySummaryFileName,
                    Invoices = c.Invoices.Select(i => new CampaignInvoiceInfo
                    {
                        InvoiceId = i.Id,
                        InvoiceNumber = i.InvoiceNumber,
                        InvoiceDate = i.InvoiceDate,
                        TotalAmount = i.TotalAmount,
                        FileName = i.FileName
                    }).ToList(),
                    Photos = c.Photos.OrderBy(p => p.DisplayOrder).Select(p => new PhotoInfo
                    {
                        PhotoId = p.Id,
                        FileName = p.FileName,
                        BlobUrl = p.BlobUrl,
                        PhotoTimestamp = p.PhotoTimestamp
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
    /// Delete a campaign and all its invoices/photos
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
    /// Delete an invoice from a campaign
    /// </summary>
    [HttpDelete("{packageId}/campaigns/{campaignId}/invoices/{invoiceId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeleteInvoice(Guid packageId, Guid campaignId, Guid invoiceId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var invoice = await _context.CampaignInvoices
                .Include(i => i.Package)
                .FirstOrDefaultAsync(i => i.Id == invoiceId && i.CampaignId == campaignId && i.PackageId == packageId, cancellationToken);

            if (invoice == null || invoice.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Invoice not found" });

            invoice.IsDeleted = true;
            invoice.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Invoice {InvoiceId} deleted from campaign {CampaignId}", invoiceId, campaignId);

            return Ok(new { message = "Invoice deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting invoice {InvoiceId}", invoiceId);
            return StatusCode(500, new { error = "Failed to delete invoice" });
        }
    }

    /// <summary>
    /// Delete a photo from a campaign
    /// </summary>
    [HttpDelete("{packageId}/campaigns/{campaignId}/photos/{photoId}")]
    [Authorize(Roles = "Agency")]
    public async Task<IActionResult> DeletePhoto(Guid packageId, Guid campaignId, Guid photoId, CancellationToken cancellationToken)
    {
        try
        {
            var userId = GetUserId();
            
            var photo = await _context.CampaignPhotos
                .Include(p => p.Package)
                .FirstOrDefaultAsync(p => p.Id == photoId && p.CampaignId == campaignId && p.PackageId == packageId, cancellationToken);

            if (photo == null || photo.Package.SubmittedByUserId != userId)
                return NotFound(new { error = "Photo not found" });

            photo.IsDeleted = true;
            photo.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Photo {PhotoId} deleted from campaign {CampaignId}", photoId, campaignId);

            return Ok(new { message = "Photo deleted successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting photo {PhotoId}", photoId);
            return StatusCode(500, new { error = "Failed to delete photo" });
        }
    }

    /// <summary>
    /// Download a campaign invoice file
    /// </summary>
    [HttpGet("invoices/{invoiceId}/download")]
    public async Task<IActionResult> DownloadInvoice(Guid invoiceId, CancellationToken cancellationToken)
    {
        try
        {
            var invoice = await _context.CampaignInvoices
                .AsNoTracking()
                .FirstOrDefaultAsync(i => i.Id == invoiceId, cancellationToken);

            if (invoice == null || string.IsNullOrEmpty(invoice.BlobUrl))
                return NotFound(new { message = "Invoice not found" });

            var fileBytes = await _fileStorage.GetFileBytesAsync(invoice.BlobUrl);
            var base64Content = Convert.ToBase64String(fileBytes);

            return Ok(new
            {
                base64Content,
                filename = invoice.FileName,
                contentType = !string.IsNullOrEmpty(invoice.ContentType) ? invoice.ContentType : "application/octet-stream",
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading invoice {InvoiceId}", invoiceId);
            return StatusCode(500, new { message = "Failed to download invoice" });
        }
    }

    /// <summary>
    /// Download a campaign photo file
    /// </summary>
    [HttpGet("photos/{photoId}/download")]
    public async Task<IActionResult> DownloadPhoto(Guid photoId, CancellationToken cancellationToken)
    {
        try
        {
            var photo = await _context.CampaignPhotos
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == photoId, cancellationToken);

            if (photo == null || string.IsNullOrEmpty(photo.BlobUrl))
                return NotFound(new { message = "Photo not found" });

            var fileBytes = await _fileStorage.GetFileBytesAsync(photo.BlobUrl);
            var base64Content = Convert.ToBase64String(fileBytes);

            return Ok(new
            {
                base64Content,
                filename = photo.FileName,
                contentType = !string.IsNullOrEmpty(photo.ContentType) ? photo.ContentType : "application/octet-stream",
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading photo {PhotoId}", photoId);
            return StatusCode(500, new { message = "Failed to download photo" });
        }
    }

    /// <summary>
    /// Download cost summary or activity summary for a campaign
    /// </summary>
    [HttpGet("campaigns/{campaignId}/download/{docType}")]
    public async Task<IActionResult> DownloadCampaignSummary(
        Guid campaignId,
        string docType,
        CancellationToken cancellationToken)
    {
        try
        {
            var campaign = await _context.Campaigns
                .AsNoTracking()
                .FirstOrDefaultAsync(c => c.Id == campaignId, cancellationToken);

            if (campaign == null)
                return NotFound(new { message = "Campaign not found" });

            string? blobUrl;
            string? fileName;
            string? contentType;

            if (docType.Equals("cost-summary", StringComparison.OrdinalIgnoreCase))
            {
                blobUrl = campaign.CostSummaryBlobUrl;
                fileName = campaign.CostSummaryFileName;
                contentType = campaign.CostSummaryContentType;
            }
            else if (docType.Equals("activity-summary", StringComparison.OrdinalIgnoreCase))
            {
                blobUrl = campaign.ActivitySummaryBlobUrl;
                fileName = campaign.ActivitySummaryFileName;
                contentType = campaign.ActivitySummaryContentType;
            }
            else
            {
                return BadRequest(new { message = "Invalid document type. Use 'cost-summary' or 'activity-summary'." });
            }

            if (string.IsNullOrEmpty(blobUrl))
                return NotFound(new { message = $"{docType} not found for this campaign" });

            var fileBytes = await _fileStorage.GetFileBytesAsync(blobUrl);
            var base64Content = Convert.ToBase64String(fileBytes);

            return Ok(new
            {
                base64Content,
                filename = fileName ?? "document",
                contentType = !string.IsNullOrEmpty(contentType) ? contentType : "application/octet-stream",
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading {DocType} for campaign {CampaignId}", docType, campaignId);
            return StatusCode(500, new { message = $"Failed to download {docType}" });
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
    public string? TeamCode { get; set; }
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
    public EnquiryDocInfo? EnquiryDoc { get; set; }
    public List<CampaignInfo> Campaigns { get; set; } = new();
}

public class POInfo
{
    public Guid DocumentId { get; set; }
    public string FileName { get; set; } = "";
    public string? ExtractedData { get; set; }
}

public class EnquiryDocInfo
{
    public string? FileName { get; set; }
    public string? BlobUrl { get; set; }
}

public class CampaignInfo
{
    public Guid CampaignId { get; set; }
    public string? CampaignName { get; set; }
    public string? TeamCode { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? WorkingDays { get; set; }
    public string? DealershipName { get; set; }
    public decimal? TotalCost { get; set; }
    public string? CostSummaryFileName { get; set; }
    public string? ActivitySummaryFileName { get; set; }
    public List<CampaignInvoiceInfo> Invoices { get; set; } = new();
    public List<PhotoInfo> Photos { get; set; } = new();
}

public class CampaignInvoiceInfo
{
    public Guid InvoiceId { get; set; }
    public string? InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public decimal? TotalAmount { get; set; }
    public string FileName { get; set; } = "";
}

public class PhotoInfo
{
    public Guid PhotoId { get; set; }
    public string FileName { get; set; } = "";
    public string BlobUrl { get; set; } = "";
    public DateTime? PhotoTimestamp { get; set; }
}
