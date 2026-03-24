using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Audit record for every email send attempt made by the system
/// </summary>
public class EmailDeliveryLog : BaseEntity
{
    /// <summary>The package this email relates to</summary>
    public Guid PackageId { get; set; }

    /// <summary>Semicolon-separated list of recipient email addresses</summary>
    public string RecipientEmail { get; set; } = string.Empty;

    /// <summary>Template name used (e.g. submission_received, validation_failed)</summary>
    public string TemplateName { get; set; } = string.Empty;

    /// <summary>Email subject line</summary>
    public string Subject { get; set; } = string.Empty;

    /// <summary>True when the provider accepted the message</summary>
    public bool Success { get; set; }

    /// <summary>Provider message ID returned on success</summary>
    public string? MessageId { get; set; }

    /// <summary>Error detail on failure</summary>
    public string? ErrorMessage { get; set; }

    /// <summary>Total send attempts including retries</summary>
    public int AttemptsCount { get; set; }

    /// <summary>When the final attempt was made</summary>
    public DateTime SentAt { get; set; }

    /// <summary>Navigation to the related package</summary>
    public DocumentPackage Package { get; set; } = null!;
}
