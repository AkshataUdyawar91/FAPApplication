namespace BajajDocumentProcessing.Infrastructure.Configuration;

/// <summary>
/// Configuration settings for Firebase Cloud Messaging (FCM)
/// </summary>
public class FcmSettings
{
    /// <summary>
    /// Configuration section name in appsettings.json
    /// </summary>
    public const string SectionName = "Fcm";

    /// <summary>
    /// Gets or sets the file path to the Google service account JSON key file
    /// </summary>
    public string ServiceAccountJsonPath { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the Firebase/GCP project ID
    /// </summary>
    public string ProjectId { get; set; } = string.Empty;
}
