namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating and sending scenario-based emails via SMTP
/// </summary>
public interface IEmailAgent
{
    /// <summary>Sends email to Agency when submission is received and queued for processing</summary>
    Task<EmailResult> SendSubmissionReceivedEmailAsync(Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>Sends email to Agency when document validation fails, requesting re-upload</summary>
    Task<EmailResult> SendValidationFailedEmailAsync(Guid packageId, List<ValidationIssue> issues, CancellationToken cancellationToken = default);

    /// <summary>Sends email to Circle Head (ASM) when validation passes and package is pending their review</summary>
    Task<EmailResult> SendPendingCircleHeadEmailAsync(Guid packageId, string circleHeadEmail, CancellationToken cancellationToken = default);

    /// <summary>Sends email to Agency when Circle Head approves and forwards to RA</summary>
    Task<EmailResult> SendCircleHeadApprovedEmailAsync(Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>Sends email to Agency when Circle Head rejects the package</summary>
    Task<EmailResult> SendCircleHeadRejectedEmailAsync(Guid packageId, string reason, CancellationToken cancellationToken = default);

    /// <summary>Sends email to Agency when RA gives final approval</summary>
    Task<EmailResult> SendRaApprovedEmailAsync(Guid packageId, CancellationToken cancellationToken = default);

    /// <summary>Sends email to Agency when RA rejects the package</summary>
    Task<EmailResult> SendRaRejectedEmailAsync(Guid packageId, string reason, CancellationToken cancellationToken = default);
}

/// <summary>Result of an email send operation</summary>
public class EmailResult
{
    public bool Success { get; set; }
    public string? MessageId { get; set; }
    public string? ErrorMessage { get; set; }
    public int AttemptsCount { get; set; }
}

// ValidationIssue is defined in IValidationAgent.cs
