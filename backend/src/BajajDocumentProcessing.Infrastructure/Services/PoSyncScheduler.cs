using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Background service that triggers the SAP PO_CREATE sync daily at 23:00 (11 PM).
/// Uses IServiceScopeFactory to resolve the scoped IPoSyncService correctly.
/// </summary>
public class PoSyncScheduler : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PoSyncScheduler> _logger;

    // Target time: 23:00 daily
    private static readonly TimeOnly ScheduledTime = new(23, 0, 0);

    public PoSyncScheduler(IServiceScopeFactory scopeFactory, ILogger<PoSyncScheduler> logger)
    {
        _scopeFactory = scopeFactory;
        _logger       = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("PoSyncScheduler started — will run daily at {Time}", ScheduledTime);

        while (!stoppingToken.IsCancellationRequested)
        {
            var delay = CalculateDelayUntilNextRun();
            _logger.LogInformation("Next PO sync scheduled in {Hours}h {Minutes}m",
                (int)delay.TotalHours, delay.Minutes);

            try
            {
                await Task.Delay(delay, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }

            await RunSyncAsync(stoppingToken);
        }

        _logger.LogInformation("PoSyncScheduler stopped");
    }

    /// <summary>
    /// Calculates how long to wait until the next 23:00 run.
    /// If it is already past 23:00 today, schedules for 23:00 tomorrow.
    /// </summary>
    private static TimeSpan CalculateDelayUntilNextRun()
    {
        var now  = DateTime.Now;
        var next = DateTime.Today.Add(ScheduledTime.ToTimeSpan());

        if (now >= next)
            next = next.AddDays(1);

        return next - now;
    }

    /// <summary>
    /// Creates a fresh DI scope and executes the sync.
    /// Scoped services (DbContext, IPoSyncService) must be resolved per-run.
    /// </summary>
    private async Task RunSyncAsync(CancellationToken ct)
    {
        _logger.LogInformation("PO_CREATE scheduled sync starting at {Time}", DateTime.Now);

        try
        {
            using var scope      = _scopeFactory.CreateScope();
            var poSyncService    = scope.ServiceProvider.GetRequiredService<IPoSyncService>();
            var result           = await poSyncService.SyncAsync(ct);

            if (result.ErrorMessage != null)
            {
                _logger.LogError("Scheduled PO sync failed: {Error}", result.ErrorMessage);
            }
            else
            {
                _logger.LogInformation(
                    "Scheduled PO sync complete — inserted={Inserted} skipped={Skipped} failed={Failed}",
                    result.Inserted, result.Skipped, result.Failed);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception during scheduled PO sync");
        }
    }
}
