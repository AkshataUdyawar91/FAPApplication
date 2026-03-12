namespace BajajDocumentProcessing.Infrastructure.Configuration;

/// <summary>
/// Configuration settings for Apple Push Notification service (APNs)
/// </summary>
public class ApnsSettings
{
    /// <summary>
    /// Configuration section name in appsettings.json
    /// </summary>
    public const string SectionName = "Apns";

    /// <summary>
    /// Gets or sets the APNs authentication key ID (10-character identifier)
    /// </summary>
    public string KeyId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the Apple Developer Team ID (10-character identifier)
    /// </summary>
    public string TeamId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the app bundle identifier (e.g., com.bajaj.documentprocessing)
    /// </summary>
    public string BundleId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the file path to the P8 authentication key file
    /// </summary>
    public string KeyFilePath { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets whether to use the production APNs environment.
    /// When false, uses the sandbox environment for development/testing.
    /// </summary>
    public bool IsProduction { get; set; }
}
