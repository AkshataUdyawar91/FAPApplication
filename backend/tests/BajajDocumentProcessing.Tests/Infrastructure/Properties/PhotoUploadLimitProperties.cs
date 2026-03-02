using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Moq;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using BajajDocumentProcessing.Infrastructure.Persistence;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 3: Photo Upload Limit
/// Validates: Requirements 1.9
/// 
/// Property: For any submission, the system should accept up to 20 photos and reject any attempt to upload more than 20 photos
/// </summary>
public class PhotoUploadLimitProperties
{
    private ApplicationDbContext CreateInMemoryContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new ApplicationDbContext(options);
    }

    private IFormFile CreateMockPhotoFile(string fileName)
    {
        var fileMock = new Mock<IFormFile>();
        var content = new byte[1024]; // 1KB
        var ms = new MemoryStream(content);
        
        fileMock.Setup(f => f.FileName).Returns(fileName);
        fileMock.Setup(f => f.Length).Returns(1024);
        fileMock.Setup(f => f.ContentType).Returns("image/jpeg");
        fileMock.Setup(f => f.OpenReadStream()).Returns(ms);
        
        return fileMock.Object;
    }

    [Fact]
    public async Task PhotoUpload_Rejects21stPhoto()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/photo.jpg");
        
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, loggerMock.Object);

        var packageId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        // Upload 20 photos successfully
        for (int i = 0; i < 20; i++)
        {
            var file = CreateMockPhotoFile($"photo{i}.jpg");
            await service.UploadDocumentAsync(file, DocumentType.Photo, packageId, userId);
        }

        // Act & Assert - 21st photo should be rejected
        var file21 = CreateMockPhotoFile("photo20.jpg");
        var exception = await Assert.ThrowsAsync<InvalidOperationException>(
            async () => await service.UploadDocumentAsync(file21, DocumentType.Photo, packageId, userId));
        
        Assert.Contains("Photo limit exceeded", exception.Message);
        Assert.Contains("20 photos", exception.Message);
    }

    [Fact]
    public async Task PhotoUpload_LimitIsPerPackage()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/photo.jpg");
        
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, loggerMock.Object);

        var packageId1 = Guid.NewGuid();
        var packageId2 = Guid.NewGuid();
        var userId = Guid.NewGuid();

        // Upload 20 photos to package 1
        for (int i = 0; i < 20; i++)
        {
            var file = CreateMockPhotoFile($"package1_photo{i}.jpg");
            await service.UploadDocumentAsync(file, DocumentType.Photo, packageId1, userId);
        }

        // Act - Upload photo to package 2 should succeed
        var file2 = CreateMockPhotoFile("package2_photo0.jpg");
        var response = await service.UploadDocumentAsync(file2, DocumentType.Photo, packageId2, userId);

        // Assert
        Assert.NotNull(response);
        Assert.Equal("package2_photo0.jpg", response.FileName);
    }

    [Fact]
    public async Task PhotoUpload_NoLimitWithoutPackageId()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/photo.jpg");
        
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, loggerMock.Object);

        var userId = Guid.NewGuid();

        // Act - Upload photos without packageId (orphaned uploads)
        // This should not enforce the limit since they're not part of a package yet
        for (int i = 0; i < 25; i++)
        {
            var file = CreateMockPhotoFile($"orphan_photo{i}.jpg");
            var response = await service.UploadDocumentAsync(file, DocumentType.Photo, null, userId);
            Assert.NotNull(response);
        }

        // Assert - All uploads should succeed
        var orphanPhotos = await context.Documents
            .Where(d => d.Type == DocumentType.Photo && d.PackageId == Guid.Empty)
            .CountAsync();
        
        Assert.Equal(25, orphanPhotos);
    }

    [Fact]
    public async Task PhotoUpload_NonPhotoDocumentsNotAffectedByLimit()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/document.pdf");
        
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, loggerMock.Object);

        var packageId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        // Upload 20 photos
        for (int i = 0; i < 20; i++)
        {
            var file = CreateMockPhotoFile($"photo{i}.jpg");
            await service.UploadDocumentAsync(file, DocumentType.Photo, packageId, userId);
        }

        // Act - Upload non-photo documents should still work
        var pdfMock = new Mock<IFormFile>();
        pdfMock.Setup(f => f.FileName).Returns("document.pdf");
        pdfMock.Setup(f => f.Length).Returns(1024);
        pdfMock.Setup(f => f.ContentType).Returns("application/pdf");
        pdfMock.Setup(f => f.OpenReadStream()).Returns(new MemoryStream(new byte[1024]));

        var response = await service.UploadDocumentAsync(pdfMock.Object, DocumentType.PO, packageId, userId);

        // Assert
        Assert.NotNull(response);
        Assert.Equal(DocumentType.PO, response.DocumentType);
    }
}
