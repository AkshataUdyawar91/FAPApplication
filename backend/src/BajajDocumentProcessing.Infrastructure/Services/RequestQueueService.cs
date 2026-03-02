using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for queuing requests when external services are unavailable
/// </summary>
public class RequestQueueService : IRequestQueueService
{
    private readonly IMemoryCache _cache;
    private readonly IValidationAgent _validationAgent;
    private readonly ILogger<RequestQueueService> _logger;
    private const string QueueKey = "validation_request_queue";

    public RequestQueueService(
        IMemoryCache cache,
        IValidationAgent validationAgent,
        ILogger<RequestQueueService> logger)
    {
        _cache = cache;
        _validationAgent = validationAgent;
        _logger = logger;
    }

    public Task QueueValidationRequestAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        var queue = _cache.GetOrCreate(QueueKey, entry =>
        {
            entry.SlidingExpiration = TimeSpan.FromHours(24);
            return new Queue<Guid>();
        });

        if (queue != null && !queue.Contains(packageId))
        {
            queue.Enqueue(packageId);
            _logger.LogInformation("Queued validation request for package {PackageId}", packageId);
        }

        return Task.CompletedTask;
    }

    public async Task ProcessQueuedRequestsAsync(CancellationToken cancellationToken = default)
    {
        var queue = _cache.Get<Queue<Guid>>(QueueKey);
        
        if (queue == null || queue.Count == 0)
        {
            _logger.LogDebug("No queued validation requests to process");
            return;
        }

        _logger.LogInformation("Processing {Count} queued validation requests", queue.Count);

        var processedCount = 0;
        var failedCount = 0;

        while (queue.Count > 0 && !cancellationToken.IsCancellationRequested)
        {
            var packageId = queue.Dequeue();

            try
            {
                await _validationAgent.ValidatePackageAsync(packageId, cancellationToken);
                processedCount++;
                _logger.LogInformation("Successfully processed queued validation for package {PackageId}", packageId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to process queued validation for package {PackageId}", packageId);
                failedCount++;
                
                // Re-queue if SAP is still unavailable
                queue.Enqueue(packageId);
                break; // Stop processing if SAP is still down
            }
        }

        _logger.LogInformation(
            "Finished processing queued requests. Processed: {Processed}, Failed: {Failed}, Remaining: {Remaining}",
            processedCount, failedCount, queue.Count);
    }

    public Task<int> GetQueuedRequestCountAsync(CancellationToken cancellationToken = default)
    {
        var queue = _cache.Get<Queue<Guid>>(QueueKey);
        return Task.FromResult(queue?.Count ?? 0);
    }
}
