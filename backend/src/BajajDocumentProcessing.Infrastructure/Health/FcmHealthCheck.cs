using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using BajajDocumentProcessing.Infrastructure.Configuration;

namespace BajajDocumentProcessing.Infrastructure.Health;

/// <summary>
/// Health check for Firebase Cloud Messaging (FCM) configuration
/// </summary>
public class FcmHealthCheck : IHealthCheck
{
    private readonly FcmSettings _settings;

    public FcmHealthCheck(IOptions<FcmSettings> settings)
    {
        _settings = settings.Value;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var isConfigured = !string.IsNullOrWhiteSpace(_settings.ProjectId);

        if (!isConfigured)
        {
            return Task.FromResult(
                HealthCheckResult.Unhealthy(
                    "FCM is not configured. ProjectId is required.",
                    data: new Dictionary<string, object>
                    {
                        ["projectIdConfigured"] = false,
                        ["serviceAccountConfigured"] = !string.IsNullOrWhiteSpace(_settings.ServiceAccountJsonPath)
                    }));
        }

        return Task.FromResult(
            HealthCheckResult.Healthy(
                "FCM is configured",
                data: new Dictionary<string, object>
                {
                    ["projectId"] = _settings.ProjectId,
                    ["serviceAccountConfigured"] = !string.IsNullOrWhiteSpace(_settings.ServiceAccountJsonPath)
                }));
    }
}
