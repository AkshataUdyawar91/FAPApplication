using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
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
/// Property 1: Document Upload Validation
/// Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6, 1.7
/// 
/// Property: The system validates file format and size limits per document type
/// </summary>
public class DocumentUploadValidationProperties
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
    public async Task PO_WithValidPdfFile_PassesValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("test.pdf", 5 * 1024 * 1024, "application/pdf"); // 5MB

        // Act
        var result = await service.ValidateFileAsync(file, DocumentType.PO);

        // Assert
        Assert.True(result, "Valid PO PDF file should pass validation");
    }

    [Fact]
    public async Task PO_WithOversizedFile_FailsValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("test.pdf", 11 * 1024 * 1024, "application/pdf"); // 11MB (exceeds 10MB limit)

        // Act
        var result = await service.ValidateFileAsync(file, DocumentType.PO);

        // Assert
        Assert.False(result, "Oversized PO file should fail validation");
    }

    [Fact]
    public async Task Invoice_WithValidImageFile_PassesValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("invoice.jpg", 3 * 1024 * 1024, "image/jpeg"); // 3MB

        // Act
        var result = await service.ValidateFileAsync(file, DocumentType.Invoice);

        // Assert
        Assert.True(result, "Valid Invoice JPG file should pass validation");
    }

    [Fact]
    public async Task CostSummary_WithValidExcelFile_PassesValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        malwareScanMock.Setup(m => m.ScanFileAsync(It.IsAny<IFormFile>())).ReturnsAsync(true);
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("summary.xlsx", 2 * 1024 * 1024, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");

        // Act
        var result = await service.ValidateFileAsync(file, DocumentType.CostSummary);

        // Assert
        Assert.True(result, "Valid Cost Summary Excel file should pass validation");
    }

    [Fact]
    public async Task Photo_WithOversizedFile_FailsValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("photo.jpg", 6 * 1024 * 1024, "image/jpeg"); // 6MB (exceeds 5MB limit for photos)

        // Act
        var result = await service.ValidateFileAsync(file, DocumentType.Photo);

        // Assert
        Assert.False(result, "Oversized photo should fail validation");
    }

    [Fact]
    public async Task Document_WithInvalidExtension_FailsValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("test.exe", 1 * 1024 * 1024, "application/x-msdownload"); // Invalid extension

        // Act
        var result = await service.ValidateFileAsync(file, DocumentType.PO);

        // Assert
        Assert.False(result, "File with invalid extension should fail validation");
    }

    [Fact]
    public async Task Document_WithNullFile_FailsValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        // Act
        var result = await service.ValidateFileAsync(null!, DocumentType.PO);

        // Assert
        Assert.False(result, "Null file should fail validation");
    }

    [Fact]
    public async Task Document_WithZeroSize_FailsValidation()
    {
        // Arrange
        var context = CreateInMemoryContext();
        var fileStorageMock = new Mock<Application.Common.Interfaces.IFileStorageService>();
        var malwareScanMock = new Mock<Application.Common.Interfaces.IMalwareScanService>();
        var documentAgentMock = new Mock<Application.Common.Interfaces.IDocumentAgent>();
        var serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        var loggerMock = new Mock<ILogger<DocumentService>>();
        var service = new DocumentService(context, fileStorageMock.Object, malwareScanMock.Object, documentAgentMock.Object, serviceScopeFactoryMock.Object, loggerMock.Object);

        var file = CreateMockFile("empty.pdf", 0, "application/pdf");

        // Act
        var result = await service.ValidateFileAsync(file, DocumentType.PO);

        // Assert
        Assert.False(result, "Empty file should fail validation");
    }
}
