using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Document service implementation
/// </summary>
public class DocumentService : IDocumentService
{
    private readonly ApplicationDbContext _context;
    private readonly IFileStorageService _fileStorageService;
    private readonly IMalwareScanService _malwareScanService;
    private readonly ILogger<DocumentService> _logger;

    // File size limits in bytes
    private const long MaxDocumentSize = 10 * 1024 * 1024; // 10MB
    private const long MaxPhotoSize = 5 * 1024 * 1024; // 5MB

    // Allowed file extensions by document type
    private static readonly Dictionary<DocumentType, string[]> AllowedExtensions = new()
    {
        { DocumentType.PO, new[] { ".pdf", ".jpg", ".jpeg", ".png", ".tiff", ".tif" } },
        { DocumentType.Invoice, new[] { ".pdf", ".jpg", ".jpeg", ".png", ".tiff", ".tif" } },
        { DocumentType.CostSummary, new[] { ".pdf", ".xls", ".xlsx", ".csv" } },
        { DocumentType.Photo, new[] { ".jpg", ".jpeg", ".png", ".heic" } },
        { DocumentType.AdditionalDocument, new[] { ".pdf", ".doc", ".docx", ".xls", ".xlsx" } }
    };

    public DocumentService(
        ApplicationDbContext context,
        IFileStorageService fileStorageService,
        IMalwareScanService malwareScanService,
        ILogger<DocumentService> logger)
    {
        _context = context;
        _fileStorageService = fileStorageService;
        _malwareScanService = malwareScanService;
        _logger = logger;
    }

    public async Task<UploadDocumentResponse> UploadDocumentAsync(
        IFormFile file,
        DocumentType documentType,
        Guid? packageId,
        Guid userId)
    {
        // Validate file
        if (!await ValidateFileAsync(file, documentType))
        {
            throw new InvalidOperationException("File validation failed");
        }

        // Create or get package
        Guid actualPackageId;
        if (packageId.HasValue && packageId.Value != Guid.Empty)
        {
            // Use existing package
            actualPackageId = packageId.Value;
            
            // Verify package exists and belongs to user
            var existingPackage = await _context.DocumentPackages
                .FirstOrDefaultAsync(p => p.Id == packageId.Value && p.SubmittedByUserId == userId);
            
            if (existingPackage == null)
            {
                throw new InvalidOperationException("Package not found or access denied");
            }
        }
        else
        {
            // Create new package for first document (PO)
            var newPackage = new DocumentPackage
            {
                Id = Guid.NewGuid(),
                SubmittedByUserId = userId,
                State = PackageState.Uploaded,
                CreatedAt = DateTime.UtcNow,
                CreatedBy = userId.ToString()
            };
            
            await _context.DocumentPackages.AddAsync(newPackage);
            await _context.SaveChangesAsync();
            
            actualPackageId = newPackage.Id;
            
            _logger.LogInformation("Created new package: {PackageId} for user {UserId}", actualPackageId, userId);
        }

        // Check photo limit (20 photos max per package)
        if (documentType == DocumentType.Photo)
        {
            var photoCount = await _context.Documents
                .CountAsync(d => d.PackageId == actualPackageId && d.Type == DocumentType.Photo);
            
            if (photoCount >= 20)
            {
                throw new InvalidOperationException("Photo limit exceeded. Maximum 20 photos allowed per submission.");
            }
        }

        // Generate unique file name
        var fileExtension = Path.GetExtension(file.FileName);
        var uniqueFileName = $"{Guid.NewGuid()}{fileExtension}";

        // Upload to blob storage
        var blobUrl = await _fileStorageService.UploadFileAsync(file, "documents", uniqueFileName);

        // Create document entity
        var document = new Document
        {
            Id = Guid.NewGuid(),
            PackageId = actualPackageId,
            Type = documentType,
            FileName = file.FileName,
            BlobUrl = blobUrl,
            FileSizeBytes = file.Length,
            ContentType = file.ContentType,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = userId.ToString()
        };

        // Save to database
        await _context.Documents.AddAsync(document);
        await _context.SaveChangesAsync();

        _logger.LogInformation(
            "Document uploaded: {DocumentId}, Type: {DocumentType}, Size: {Size} bytes, Package: {PackageId}",
            document.Id, documentType, file.Length, actualPackageId);

        return new UploadDocumentResponse
        {
            DocumentId = document.Id,
            PackageId = actualPackageId,
            FileName = document.FileName,
            FileSizeBytes = document.FileSizeBytes,
            DocumentType = document.Type,
            BlobUrl = document.BlobUrl,
            UploadedAt = document.CreatedAt
        };
    }

    public async Task<bool> ValidateFileAsync(IFormFile file, DocumentType documentType)
    {
        if (file == null || file.Length == 0)
        {
            _logger.LogWarning("File is null or empty");
            return false;
        }

        // Check file size
        var maxSize = documentType == DocumentType.Photo ? MaxPhotoSize : MaxDocumentSize;
        if (file.Length > maxSize)
        {
            _logger.LogWarning(
                "File size {Size} exceeds maximum {MaxSize} for {DocumentType}",
                file.Length, maxSize, documentType);
            return false;
        }

        // Check file extension
        var fileExtension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExtensions.TryGetValue(documentType, out var allowedExts) ||
            !allowedExts.Contains(fileExtension))
        {
            _logger.LogWarning(
                "File extension {Extension} not allowed for {DocumentType}",
                fileExtension, documentType);
            return false;
        }

        // Malware scan
        if (!await _malwareScanService.ScanFileAsync(file))
        {
            _logger.LogWarning("File failed malware scan: {FileName}", file.FileName);
            return false;
        }

        return true;
    }

    public async Task<Document?> GetDocumentAsync(Guid documentId)
    {
        return await _context.Documents.FindAsync(documentId);
    }
}
