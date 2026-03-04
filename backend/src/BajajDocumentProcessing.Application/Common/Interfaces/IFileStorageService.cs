using Microsoft.AspNetCore.Http;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// File storage service interface
/// </summary>
public interface IFileStorageService
{
    Task<string> UploadFileAsync(IFormFile file, string containerName, string fileName);
    Task<bool> DeleteFileAsync(string blobUrl);
    Task<Stream> DownloadFileAsync(string blobUrl);
    Task<bool> FileExistsAsync(string blobUrl);
    Task<byte[]> GetFileBytesAsync(string blobUrl);
}
