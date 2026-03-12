using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;
using BajajDocumentProcessing.Infrastructure.Configuration;

namespace BajajDocumentProcessing.Infrastructure.Health;

/// <summary>
/// Health check for Apple Push Notification service (APNs) configuration
/// </summary>
public class ApnsHealthCheck : IHealthCheck
{
    private readonly ApnsSettings _settings;

    public ApnsHealthCheck(IOptions<ApnsSettings> settings)
    {
        _settings = settings.Value;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var isConfigured = !string.IsNullOrWhiteSpace(_settings.KeyId) &&
                          !string.IsNullOrWhiteSpace(_settings.TeamId) &&
                          !string.IsNullOrWhiteSpace(_settings.BundleId);

        if (!isConfigured)
        {
            return Task.FromResult(
                HealthCheckResult.Unhealthy(
                    "APNs is not configured. KeyId, TeamId, and BundleId are required.",
                    data: new Dictionary<string, object>
                    {
                        ["keyIdConfigured"] = !string.IsNullOrWhiteSpace(_settings.KeyId),
                        ["teamIdConfigured"] = !string.IsNullOrWhiteSpace(_settings.TeamId),
                        ["bundleIdConfigured"] = !string.IsNullOrWhiteSpace(_settings.BundleId),
                        ["isProduction"] = _settings.IsProduction
                    }));
        }

        return Task.FromResult(
            HealthCheckResult.Healthy(
                "APNs is configured",
                data: new Dictionary<string, object>
                {
                    ["keyId"] = _settings.KeyId,
                    ["teamId"] = _settings.TeamId,
                    ["bundleId"] = _settings.BundleId,
                    ["isProduction"] = _settings.IsProduction,
                    ["keyFileConfigured"] = !string.IsNullOrWhiteSpace(_settings.KeyFilePath)
                }));
    }
}
