using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using BajajDocumentProcessing.Infrastructure.Persistence;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 2: Upload Confirmation Display
/// Validates: Requirements 1.8
/// 
/// Property: When a file upload completes, the system displays a confirmation with filename and file size
/// </summary>
public class UploadConfirmationProperties
{
    private ApplicationDbContext CreateInMemoryContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new ApplicationDbContext(options);
    }

    private IFormFile CreateMockFile(string fileName, long fileSize, string contentType)
    {
        var fileMock = new Mock<IFormFile>();
        var content = new byte[fileSize];
        var ms = new MemoryStream(content);
        
        fileMock.Setup(f => f.FileName).Returns(fileName);
        fileMock.Setup(f => f.Length).Returns(fileSize);
        fileMock.Setup(f => f.ContentType).Returns(contentType);
        fileMock.Setup(f => f.OpenReadStream()).Returns(ms);
        
        return fileMock.Object;
    }

    [Fact]
    public async Task UploadResponse_ContainsAllRequiredFields()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/test.pdf");
        
        var malwareScanMock = new Mock<IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        var documentAgentMock = new Mock<IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("test.pdf", 2048, "application/pdf");
        var userId = Guid.NewGuid();

        // Act
        var response = await service.UploadDocumentAsync(file, DocumentType.PO, null, userId);

        // Assert
        Assert.NotNull(response);
        Assert.NotEqual(Guid.Empty, response.DocumentId);
        Assert.Equal("test.pdf", response.FileName);
        Assert.Equal(2048, response.FileSizeBytes);
        Assert.Equal(DocumentType.PO, response.DocumentType);
        Assert.NotEmpty(response.BlobUrl);
        Assert.True(response.UploadedAt <= DateTime.UtcNow);
        Assert.True(response.UploadedAt >= DateTime.UtcNow.AddMinutes(-1));
    }

    [Fact]
    public async Task UploadResponse_FileSizeMatchesOriginal()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/test.pdf");
        
        var malwareScanMock = new Mock<IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        var documentAgentMock = new Mock<IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var expectedSize = 5 * 1024 * 1024; // 5MB
        var file = CreateMockFile("large.pdf", expectedSize, "application/pdf");

        // Act
        var response = await service.UploadDocumentAsync(file, DocumentType.PO, null, Guid.NewGuid());

        // Assert
        Assert.Equal(expectedSize, response.FileSizeBytes);
    }

    [Fact]
    public async Task UploadResponse_FileNamePreserved()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/unique-id.pdf");
        
        var malwareScanMock = new Mock<IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        var documentAgentMock = new Mock<IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var originalFileName = "My Important Document.pdf";
        var file = CreateMockFile(originalFileName, 1024, "application/pdf");

        // Act
        var response = await service.UploadDocumentAsync(file, DocumentType.PO, null, Guid.NewGuid());

        // Assert
        Assert.Equal(originalFileName, response.FileName);
    }

    [Fact]
    public async Task UploadResponse_DocumentTypeCorrect()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<IFileStorageService>();
        fileStorageMock
            .Setup(f => f.UploadFileAsync(It.IsAny<IFormFile>(), It.IsAny<string>(), It.IsAny<string>()))
            .ReturnsAsync("https://blob.com/test.jpg");
        
        var malwareScanMock = new Mock<IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        var documentAgentMock = new Mock<IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("photo.jpg", 1024, "image/jpeg");

        // Act
        var response = await service.UploadDocumentAsync(file, DocumentType.TeamPhoto, null, Guid.NewGuid());

        // Assert
        Assert.Equal(DocumentType.TeamPhoto, response.DocumentType);
    }
}

