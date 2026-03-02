using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
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
        var connectionString = configuration["AzureServices:BlobStorage:ConnectionString"];
        _containerName = configuration["AzureServices:BlobStorage:ContainerName"] ?? "documents";
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
        // For development without Azure, return a simulated URL
        var simulatedUrl = $"https://localhost/storage/{containerName}/{fileName}";
        _logger.LogInformation("Simulated file upload: {FileName} -> {Url}", fileName, simulatedUrl);
        
        await Task.CompletedTask; // Simulate async operation
        return simulatedUrl;
    }
}
