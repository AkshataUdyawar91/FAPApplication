namespace BajajDocumentProcessing.Infrastructure.Services.Teams;

/// <summary>
/// Strongly-typed configuration POCO for Teams Bot settings.
/// Bound from appsettings.json "TeamsBot" section.
/// </summary>
public class TeamsBotOptions
{
    /// <summary>
    /// Configuration section name in appsettings.json.
    /// </summary>
    public const string SectionName = "TeamsBot";

    /// <summary>
    /// Azure Bot registration App ID (empty for local Emulator testing).
    /// </summary>
    public string MicrosoftAppId { get; set; } = string.Empty;

    /// <summary>
    /// Azure Bot registration App Secret (empty for local Emulator testing).
    /// </summary>
    public string MicrosoftAppPassword { get; set; } = string.Empty;

    /// <summary>
    /// Azure AD Tenant ID for the Bajaj organization.
    /// </summary>
    public string TenantId { get; set; } = string.Empty;

    /// <summary>
    /// Base URL for the FieldIQ portal (used in "Open in Portal" links).
    /// </summary>
    public string PortalBaseUrl { get; set; } = "https://localhost:7001";

    /// <summary>
    /// Whether pilot mode is enabled (single ASM user, in-memory reference capture).
    /// </summary>
    public bool IsPilotMode { get; set; } = true;
}
