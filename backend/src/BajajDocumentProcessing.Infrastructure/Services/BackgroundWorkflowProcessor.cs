using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System.Threading.Channels;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Background service that processes document workflows asynchronously
/// </summary>
public class BackgroundWorkflowProcessor : BackgroundService
{
    private readonly Channel<Guid> _queue;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<BackgroundWorkflowProcessor> _logger;

    public BackgroundWorkflowProcessor(
        IServiceProvider serviceProvider,
        ILogger<BackgroundWorkflowProcessor> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        
        // Create unbounded channel for workflow queue
        _queue = Channel.CreateUnbounded<Guid>(new UnboundedChannelOptions
        {
            SingleReader = false, // Allow multiple workers
            SingleWriter = false
        });
    }

    /// <summary>
    /// Queue a package for background processing
    /// </summary>
    public async Task QueueWorkflowAsync(Guid packageId)
    {
        await _queue.Writer.WriteAsync(packageId);
        _logger.LogInformation("Package {PackageId} queued for background processing", packageId);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Background Workflow Processor started");

        try
        {
            // Process workflows from queue
            await foreach (var packageId in _queue.Reader.ReadAllAsync(stoppingToken))
            {
                try
                {
                    _logger.LogInformation("Processing package {PackageId} from queue", packageId);

                    // Create a new scope for each workflow
                    using var scope = _serviceProvider.CreateScope();
                    var orchestrator = scope.ServiceProvider.GetRequiredService<IWorkflowOrchestrator>();

                    // Process the workflow
                    var success = await orchestrator.ProcessSubmissionAsync(packageId, stoppingToken);

                    if (success)
                    {
                        _logger.LogInformation("Package {PackageId} processed successfully", packageId);
                    }
                    else
                    {
                        _logger.LogWarning("Package {PackageId} processing failed", packageId);
                    }
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing package {PackageId} in background", packageId);
                }
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            // Graceful shutdown — expected when the host is stopping
        }

        _logger.LogInformation("Background Workflow Processor stopped");
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Background Workflow Processor stopping...");
        _queue.Writer.Complete();
        await base.StopAsync(cancellationToken);
    }
}

/// <summary>
/// Interface for queuing workflows
/// </summary>
public interface IBackgroundWorkflowQueue
{
    Task QueueWorkflowAsync(Guid packageId);
}

/// <summary>
/// Service to queue workflows for background processing
/// </summary>
public class BackgroundWorkflowQueue : IBackgroundWorkflowQueue
{
    private readonly BackgroundWorkflowProcessor _processor;

    public BackgroundWorkflowQueue(BackgroundWorkflowProcessor processor)
    {
        _processor = processor;
    }

    public Task QueueWorkflowAsync(Guid packageId)
    {
        return _processor.QueueWorkflowAsync(packageId);
    }
}
