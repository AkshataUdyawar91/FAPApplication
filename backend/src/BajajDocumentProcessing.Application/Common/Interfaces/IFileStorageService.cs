using Microsoft.AspNetCore.Http;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// File storage service interface for Azure Blob Storage operations
/// </summary>
public interface IFileStorageService
{
    /// <summary>
    /// Uploads a file to Azure Blob Storage
    /// </summary>
    /// <param name="file">File to upload</param>
    /// <param name="containerName">Blob container name</param>
    /// <param name="fileName">File name to use in blob storage</param>
    /// <returns>Blob URL of the uploaded file</returns>
    Task<string> UploadFileAsync(IFormFile file, string containerName, string fileName);

    /// <summary>
    /// Deletes a file from Azure Blob Storage
    /// </summary>
    /// <param name="blobUrl">URL of the blob to delete</param>
    /// <returns>True if deletion was successful, false otherwise</returns>
    Task<bool> DeleteFileAsync(string blobUrl);

    /// <summary>
    /// Downloads a file from Azure Blob Storage as a stream
    /// </summary>
    /// <param name="blobUrl">URL of the blob to download</param>
    /// <returns>Stream containing the file data</returns>
    Task<Stream> DownloadFileAsync(string blobUrl);

    /// <summary>
    /// Checks if a file exists in Azure Blob Storage
    /// </summary>
    /// <param name="blobUrl">URL of the blob to check</param>
    /// <returns>True if file exists, false otherwise</returns>
    Task<bool> FileExistsAsync(string blobUrl);

    /// <summary>
    /// Downloads a file from Azure Blob Storage as a byte array
    /// </summary>
    /// <param name="blobUrl">URL of the blob to download</param>
    /// <returns>Byte array containing the file data</returns>
    Task<byte[]> GetFileBytesAsync(string blobUrl);

    /// <summary>
    /// Generates a public URL with SAS token for temporary access to a blob
    /// </summary>
    /// <param name="blobUrl">URL of the blob</param>
    /// <param name="validity">Duration for which the SAS token is valid</param>
    /// <returns>Public URL with SAS token</returns>
    Task<string> GetPublicUrlWithSasAsync(string blobUrl, TimeSpan validity);
}