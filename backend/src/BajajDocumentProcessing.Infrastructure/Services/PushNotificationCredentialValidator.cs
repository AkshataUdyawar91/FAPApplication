using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using BajajDocumentProcessing.Infrastructure.Configuration;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Validates APNs and FCM credentials during application startup.
/// Logs warnings for missing or invalid configuration without blocking startup.
/// </summary>
public class PushNotificationCredentialValidator : IHostedService
{
    private readonly ILogger<PushNotificationCredentialValidator> _logger;
    private readonly ApnsSettings _apnsSettings;
    private readonly FcmSettings _fcmSettings;

    /// <summary>
    /// Initializes a new instance of the <see cref="PushNotificationCredentialValidator"/> class
    /// </summary>
    public PushNotificationCredentialValidator(
        ILogger<PushNotificationCredentialValidator> logger,
        IOptions<ApnsSettings> apnsSettings,
        IOptions<FcmSettings> fcmSettings)
    {
        _logger = logger;
        _apnsSettings = apnsSettings.Value;
        _fcmSettings = fcmSettings.Value;
    }

    /// <inheritdoc />
    public Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Validating push notification credentials at startup");

        ValidateApnsSettings();
        ValidateFcmSettings();

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    /// <summary>
    /// Validates APNs configuration settings and logs warnings for missing values
    /// </summary>
    private void ValidateApnsSettings()
    {
        var issues = new List<string>();

        if (string.IsNullOrWhiteSpace(_apnsSettings.KeyId))
            issues.Add("KeyId is not configured");

        if (string.IsNullOrWhiteSpace(_apnsSettings.TeamId))
            issues.Add("TeamId is not configured");

        if (string.IsNullOrWhiteSpace(_apnsSettings.BundleId))
            issues.Add("BundleId is not configured");

        if (string.IsNullOrWhiteSpace(_apnsSettings.KeyFilePath))
        {
            issues.Add("KeyFilePath is not configured");
        }
        else if (!File.Exists(_apnsSettings.KeyFilePath))
        {
            issues.Add($"P8 key file not found at '{_apnsSettings.KeyFilePath}'");
        }

        if (issues.Count > 0)
        {
            _logger.LogWarning(
                "APNs configuration incomplete — iOS push notifications will not work. Issues: {Issues}",
                string.Join("; ", issues));
        }
        else
        {
            _logger.LogInformation(
                "APNs credentials validated successfully (Environment: {Environment})",
                _apnsSettings.IsProduction ? "Production" : "Sandbox");
        }
    }

    /// <summary>
    /// Validates FCM configuration settings and logs warnings for missing values
    /// </summary>
    private void ValidateFcmSettings()
    {
        var issues = new List<string>();

        if (string.IsNullOrWhiteSpace(_fcmSettings.ProjectId))
            issues.Add("ProjectId is not configured");

        if (string.IsNullOrWhiteSpace(_fcmSettings.ServiceAccountJsonPath))
        {
            issues.Add("ServiceAccountJsonPath is not configured");
        }
        else if (!File.Exists(_fcmSettings.ServiceAccountJsonPath))
        {
            issues.Add($"Service account JSON file not found at '{_fcmSettings.ServiceAccountJsonPath}'");
        }

        if (issues.Count > 0)
        {
            _logger.LogWarning(
                "FCM configuration incomplete — Android/Web push notifications will not work. Issues: {Issues}",
                string.Join("; ", issues));
        }
        else
        {
            _logger.LogInformation("FCM credentials validated successfully for project '{ProjectId}'", _fcmSettings.ProjectId);
        }
    }
}
