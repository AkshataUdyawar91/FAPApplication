using Xunit;
using Microsoft.AspNetCore.Http;
using Moq;
using BajajDocumentProcessing.Application.Utilities;

namespace BajajDocumentProcessing.Tests.Application.Utilities;

/// <summary>
/// Unit tests for FileUploadValidator
/// </summary>
public class FileUploadValidatorTests
{
    /// <summary>
    /// Creates a mock IFormFile with specified content
    /// </summary>
    private static IFormFile CreateMockFile(string fileName, byte[] content)
    {
        var fileMock = new Mock<IFormFile>();
        var ms = new MemoryStream(content);
        
        fileMock.Setup(f => f.FileName).Returns(fileName);
        fileMock.Setup(f => f.Length).Returns(content.Length);
        fileMock.Setup(f => f.OpenReadStream()).Returns(ms);
        
        return fileMock.Object;
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_ValidPdfFile_ReturnsTrue()
    {
        // Arrange - PDF magic bytes: %PDF (0x25 0x50 0x44 0x46)
        var pdfContent = new byte[] { 0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34 };
        var file = CreateMockFile("document.pdf", pdfContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_ValidJpegFile_ReturnsTrue()
    {
        // Arrange - JPEG magic bytes: FF D8 FF E0 (JFIF)
        var jpegContent = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46 };
        var file = CreateMockFile("photo.jpg", jpegContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_ValidPngFile_ReturnsTrue()
    {
        // Arrange - PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
        var pngContent = new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
        var file = CreateMockFile("image.png", pngContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_ValidTiffFileLittleEndian_ReturnsTrue()
    {
        // Arrange - TIFF magic bytes (little-endian): 49 49 2A 00
        var tiffContent = new byte[] { 0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00 };
        var file = CreateMockFile("scan.tiff", tiffContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_ValidTiffFileBigEndian_ReturnsTrue()
    {
        // Arrange - TIFF magic bytes (big-endian): 4D 4D 00 2A
        var tiffContent = new byte[] { 0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08 };
        var file = CreateMockFile("scan.tif", tiffContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_InvalidPdfFile_ReturnsFalse()
    {
        // Arrange - File with .pdf extension but wrong magic bytes
        var invalidContent = new byte[] { 0x50, 0x4B, 0x03, 0x04 }; // ZIP magic bytes
        var file = CreateMockFile("fake.pdf", invalidContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_InvalidJpegFile_ReturnsFalse()
    {
        // Arrange - File with .jpg extension but wrong magic bytes
        var invalidContent = new byte[] { 0x89, 0x50, 0x4E, 0x47 }; // PNG magic bytes
        var file = CreateMockFile("fake.jpg", invalidContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_NullFile_ReturnsFalse()
    {
        // Arrange
        IFormFile? file = null;

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file!);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_EmptyFile_ReturnsFalse()
    {
        // Arrange
        var file = CreateMockFile("empty.pdf", Array.Empty<byte>());

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_UnsupportedExtension_ReturnsTrue()
    {
        // Arrange - Extension not in signature list should pass through
        var content = new byte[] { 0x50, 0x4B, 0x03, 0x04 }; // ZIP
        var file = CreateMockFile("document.docx", content);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.True(result); // Should return true for unsupported extensions
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_JpegWithExifSignature_ReturnsTrue()
    {
        // Arrange - JPEG with EXIF signature: FF D8 FF E1
        var jpegContent = new byte[] { 0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x16, 0x45, 0x78 };
        var file = CreateMockFile("photo.jpeg", jpegContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task ValidateFileTypeByMagicBytesAsync_FileSmallerThanSignature_ReturnsFalse()
    {
        // Arrange - File too small to contain full signature
        var smallContent = new byte[] { 0x25, 0x50 }; // Only 2 bytes of PDF signature
        var file = CreateMockFile("truncated.pdf", smallContent);

        // Act
        var result = await FileUploadValidator.ValidateFileTypeByMagicBytesAsync(file);

        // Assert
        Assert.False(result);
    }
}
