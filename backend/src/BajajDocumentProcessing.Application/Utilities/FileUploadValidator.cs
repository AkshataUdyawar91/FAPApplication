using Microsoft.AspNetCore.Http;

namespace BajajDocumentProcessing.Application.Utilities;

/// <summary>
/// Validates file uploads by checking magic bytes (file signatures) to prevent file type spoofing
/// </summary>
public static class FileUploadValidator
{
    /// <summary>
    /// File signatures (magic bytes) for supported file types
    /// </summary>
    private static readonly Dictionary<string, byte[][]> FileSignatures = new()
    {
        // PDF files start with %PDF (0x25 0x50 0x44 0x46)
        { ".pdf", new[] { new byte[] { 0x25, 0x50, 0x44, 0x46 } } },
        
        // JPEG files have multiple possible signatures
        { ".jpg", new[] 
            { 
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 }, // JFIF
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE1 }, // EXIF
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE2 }, // Canon
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE3 }, // Samsung
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE8 }, // SPIFF
                new byte[] { 0xFF, 0xD8, 0xFF, 0xDB }  // Generic JPEG
            } 
        },
        { ".jpeg", new[] 
            { 
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 },
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE1 },
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE2 },
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE3 },
                new byte[] { 0xFF, 0xD8, 0xFF, 0xE8 },
                new byte[] { 0xFF, 0xD8, 0xFF, 0xDB }
            } 
        },
        
        // PNG files start with 89 50 4E 47 0D 0A 1A 0A
        { ".png", new[] { new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A } } },
        
        // TIFF files have two possible byte orders
        { ".tiff", new[] 
            { 
                new byte[] { 0x49, 0x49, 0x2A, 0x00 }, // Little-endian
                new byte[] { 0x4D, 0x4D, 0x00, 0x2A }  // Big-endian
            } 
        },
        { ".tif", new[] 
            { 
                new byte[] { 0x49, 0x49, 0x2A, 0x00 },
                new byte[] { 0x4D, 0x4D, 0x00, 0x2A }
            } 
        }
    };

    /// <summary>
    /// Validates a file by checking its magic bytes against expected signatures for the file extension
    /// </summary>
    /// <param name="file">The file to validate</param>
    /// <returns>True if the file's magic bytes match its extension, false otherwise</returns>
    public static async Task<bool> ValidateFileTypeByMagicBytesAsync(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return false;
        }

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        
        // Check if we have signatures for this extension
        if (!FileSignatures.TryGetValue(extension, out var signatures))
        {
            // Extension not in our signature list - allow it (other validation will handle)
            return true;
        }

        // Read the file header
        var headerBytes = await ReadFileHeaderAsync(file, GetMaxSignatureLength(signatures));
        
        // Check if any signature matches
        foreach (var signature in signatures)
        {
            if (HeaderMatchesSignature(headerBytes, signature))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Reads the header bytes from a file
    /// </summary>
    /// <param name="file">The file to read from</param>
    /// <param name="bytesToRead">Number of bytes to read</param>
    /// <returns>Array of header bytes</returns>
    private static async Task<byte[]> ReadFileHeaderAsync(IFormFile file, int bytesToRead)
    {
        var buffer = new byte[bytesToRead];
        
        using var stream = file.OpenReadStream();
        var bytesRead = await stream.ReadAsync(buffer, 0, bytesToRead);
        
        // Reset stream position for subsequent reads
        stream.Position = 0;
        
        // Return only the bytes actually read
        if (bytesRead < bytesToRead)
        {
            Array.Resize(ref buffer, bytesRead);
        }
        
        return buffer;
    }

    /// <summary>
    /// Checks if the file header matches a signature
    /// </summary>
    /// <param name="header">The file header bytes</param>
    /// <param name="signature">The expected signature</param>
    /// <returns>True if the header starts with the signature</returns>
    private static bool HeaderMatchesSignature(byte[] header, byte[] signature)
    {
        if (header.Length < signature.Length)
        {
            return false;
        }

        for (int i = 0; i < signature.Length; i++)
        {
            if (header[i] != signature[i])
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Gets the maximum signature length from an array of signatures
    /// </summary>
    /// <param name="signatures">Array of signatures</param>
    /// <returns>Maximum length</returns>
    private static int GetMaxSignatureLength(byte[][] signatures)
    {
        return signatures.Max(s => s.Length);
    }
}
