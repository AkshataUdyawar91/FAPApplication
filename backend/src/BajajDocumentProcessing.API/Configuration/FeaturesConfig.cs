namespace BajajDocumentProcessing.API.Configuration;

/// <summary>
/// Feature flags for toggling conversational AI behaviour at runtime.
/// Read from appsettings.json "Features" section via IOptionsSnapshot (hot-reload enabled).
/// </summary>
public class FeaturesConfig
{
    /// <summary>
    /// When false, the assistant API returns a disabled response without processing any action.
    /// Toggle in appsettings.json without restarting the application.
    /// </summary>
    public bool AgencyConversationalAI { get; set; } = false;

    /// <summary>
    /// When true, intent classification uses GPT-4o-mini via LLM.
    /// When false (default), keyword-based classification is used.
    /// </summary>
    public bool UseLLMClassifier { get; set; } = false;
}
