using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Storage.Sas;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Azure Blob Storage implementation of file storage service
/// </summary>
public class FileStorageService : IFileStorageService
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly ILogger<FileStorageService> _logger;
    private readonly string _containerName;

    public FileStorageService(IConfiguration configuration, ILogger<FileStorageService> logger)
    {
        var connectionString = configuration["AzureBlobStorage:ConnectionString"];
        _containerName = configuration["AzureBlobStorage:ContainerName"] ?? "documents";
        _logger = logger;

        if (string.IsNullOrEmpty(connectionString))
        {
            // For development without Azure, use local storage simulation
            _logger.LogWarning("Azure Blob Storage connection string not configured. Using local file storage simulation.");
            _blobServiceClient = null!;
        }
        else
        {
            _blobServiceClient = new BlobServiceClient(connectionString);
        }
    }

    public async Task<string> UploadFileAsync(IFormFile file, string containerName, string fileName)
    {
        try
        {
            if (_blobServiceClient == null)
            {
                // Simulate local storage for development
                return await SimulateLocalStorageAsync(file, containerName, fileName);
            }

            // Get or create container
            var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
            await containerClient.CreateIfNotExistsAsync(PublicAccessType.None);

            // Upload file
            var blobClient = containerClient.GetBlobClient(fileName);
            
            using var stream = file.OpenReadStream();
            await blobClient.UploadAsync(stream, new BlobHttpHeaders
            {
                ContentType = file.ContentType
            });

            _logger.LogInformation("File uploaded successfully: {FileName}", fileName);
            return blobClient.Uri.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading file: {FileName}", fileName);
            throw;
        }
    }

    public async Task<bool> DeleteFileAsync(string blobUrl)
    {
        try
        {
            if (_blobServiceClient == null)
            {
                _logger.LogInformation("Simulating file deletion: {BlobUrl}", blobUrl);
                return true;
            }

            var blobClient = new BlobClient(new Uri(blobUrl));
            var result = await blobClient.DeleteIfExistsAsync();
            
            _logger.LogInformation("File deleted: {BlobUrl}", blobUrl);
            return result.Value;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting file: {BlobUrl}", blobUrl);
            return false;
        }
    }

    public async Task<Stream> DownloadFileAsync(string blobUrl)
    {
        try
        {
            if (_blobServiceClient == null)
            {
                throw new InvalidOperationException("Azure Blob Storage not configured");
            }

            var blobClient = new BlobClient(new Uri(blobUrl));
            var response = await blobClient.DownloadAsync();
            
            _logger.LogInformation("File downloaded: {BlobUrl}", blobUrl);
            return response.Value.Content;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error downloading file: {BlobUrl}", blobUrl);
            throw;
        }
    }

    public async Task<bool> FileExistsAsync(string blobUrl)
    {
        try
        {
            if (_blobServiceClient == null)
            {
                return true; // Simulate existence for development
            }

            var blobClient = new BlobClient(new Uri(blobUrl));
            return await blobClient.ExistsAsync();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error checking file existence: {BlobUrl}", blobUrl);
            return false;
        }
    }

    private async Task<string> SimulateLocalStorageAsync(IFormFile file, string containerName, string fileName)
    {
        // For development without Azure, save files locally
        var localStoragePath = Path.Combine(Directory.GetCurrentDirectory(), "LocalStorage", containerName);
        Directory.CreateDirectory(localStoragePath);
        
        var filePath = Path.Combine(localStoragePath, fileName);
        
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }
        
        // Return local file path as URL
        var localUrl = $"file:///{filePath.Replace("\\", "/")}";
        _logger.LogInformation("Saved file locally: {FileName} -> {Path}", fileName, filePath);
        
        return localUrl;
    }
    
    public async Task<byte[]> GetFileBytesAsync(string blobUrl)
    {
        try
        {
            if (blobUrl.StartsWith("file:///"))
            {
                // Local file
                var filePath = blobUrl.Replace("file:///", "").Replace("/", "\\");
                if (File.Exists(filePath))
                {
                    _logger.LogInformation("Reading local file: {FilePath}", filePath);
                    return await File.ReadAllBytesAsync(filePath);
                }
                throw new FileNotFoundException($"Local file not found: {filePath}");
            }
            else if (_blobServiceClient != null)
            {
                // Azure Blob Storage - extract container and blob name from URL
                var uri = new Uri(blobUrl);
                var pathParts = uri.AbsolutePath.TrimStart('/').Split('/', 2);
                
                if (pathParts.Length < 2)
                {
                    throw new InvalidOperationException($"Invalid blob URL format: {blobUrl}");
                }
                
                var containerName = pathParts[0];
                var blobName = pathParts[1];
                
                _logger.LogInformation("Downloading blob: Container={Container}, Blob={Blob}", containerName, blobName);
                
                var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
                var blobClient = containerClient.GetBlobClient(blobName);
                
                var response = await blobClient.DownloadAsync();
                using var memoryStream = new MemoryStream();
                await response.Value.Content.CopyToAsync(memoryStream);
                var bytes = memoryStream.ToArray();
                _logger.LogInformation("Downloaded {Size} bytes from blob", bytes.Length);
                return bytes;
            }
            else
            {
                throw new InvalidOperationException("Cannot retrieve file bytes - no storage configured");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting file bytes from: {BlobUrl}", blobUrl);
            throw;
        }
    }
    
    public async Task<string> GetPublicUrlWithSasAsync(string blobUrl, TimeSpan validity)
    {
        try
        {
            if (blobUrl.StartsWith("file:///"))
            {
                // For local files, return the file URL as-is (development only)
                _logger.LogWarning("Cannot generate SAS URL for local file: {BlobUrl}", blobUrl);
                return blobUrl;
            }
            
            if (_blobServiceClient == null)
            {
                throw new InvalidOperationException("Azure Blob Storage not configured");
            }

            // Extract container and blob name from URL
            var uri = new Uri(blobUrl);
            var pathParts = uri.AbsolutePath.TrimStart('/').Split('/', 2);
            
            if (pathParts.Length < 2)
            {
                throw new InvalidOperationException($"Invalid blob URL format: {blobUrl}");
            }
            
            var containerName = pathParts[0];
            var blobName = pathParts[1];
            
            var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
            var blobClient = containerClient.GetBlobClient(blobName);
            
            // Check if blob exists
            if (!await blobClient.ExistsAsync())
            {
                throw new FileNotFoundException($"Blob not found: {blobUrl}");
            }
            
            // Generate SAS token
            var sasBuilder = new BlobSasBuilder
            {
                BlobContainerName = containerName,
                BlobName = blobName,
                Resource = "b", // b = blob
                StartsOn = DateTimeOffset.UtcNow.AddMinutes(-5), // Allow for clock skew
                ExpiresOn = DateTimeOffset.UtcNow.Add(validity)
            };
            
            sasBuilder.SetPermissions(BlobSasPermissions.Read);
            
            var sasToken = blobClient.GenerateSasUri(sasBuilder);
            
            _logger.LogInformation("Generated SAS URL for blob: {BlobName}, Valid until: {ExpiresOn}", 
                blobName, sasBuilder.ExpiresOn);
            
            return sasToken.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating SAS URL for: {BlobUrl}", blobUrl);
            throw;
        }
    }
}
