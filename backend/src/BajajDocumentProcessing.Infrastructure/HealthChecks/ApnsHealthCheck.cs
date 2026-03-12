using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using BajajDocumentProcessing.Application.Common.Interfaces;

namespace BajajDocumentProcessing.Infrastructure.HealthChecks;

/// <summary>
/// Health check for Apple Push Notification service (APNs) credential validation.
/// Reports healthy when APNs credentials are properly configured and valid.
/// </summary>
public class ApnsHealthCheck : IHealthCheck
{
    private readonly IApnsService _apnsService;
    private readonly ILogger<ApnsHealthCheck> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="ApnsHealthCheck"/> class
    /// </summary>
    public ApnsHealthCheck(
        IApnsService apnsService,
        ILogger<ApnsHealthCheck> logger)
    {
        _apnsService = apnsService;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _apnsService.ValidateCredentialsAsync(cancellationToken);

            if (result.Success)
            {
                _logger.LogDebug("APNs health check passed");
                return HealthCheckResult.Healthy("APNs credentials are valid");
            }

            _logger.LogWarning("APNs health check failed: {Error}", result.ErrorMessage);
            return HealthCheckResult.Degraded(
                $"APNs credentials validation failed: {result.ErrorMessage}",
                data: new Dictionary<string, object>
                {
                    ["errorCode"] = result.ErrorCode ?? "Unknown"
                });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "APNs health check threw an exception");
            return HealthCheckResult.Unhealthy(
                "APNs health check failed with exception",
                ex);
        }
    }
}
