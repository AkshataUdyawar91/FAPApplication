namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for generating and sending scenario-based emails
/// </summary>
public interface IEmailAgent
{
    /// <summary>
    /// Sends email to Agency when validation fails, requesting re-upload
    /// </summary>
    Task<EmailResult> SendDataFailureEmailAsync(Guid packageId, List<ValidationIssue> issues, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends email to ASM when validation passes, requesting approval
    /// </summary>
    Task<EmailResult> SendDataPassEmailAsync(Guid packageId, string asmEmail, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends email to Agency when ASM approves the package
    /// </summary>
    Task<EmailResult> SendApprovedEmailAsync(Guid packageId, string agencyEmail, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends email to Agency when ASM rejects the package
    /// </summary>
    Task<EmailResult> SendRejectedEmailAsync(Guid packageId, string agencyEmail, string reason, CancellationToken cancellationToken = default);
}

/// <summary>
/// Result of email sending operation
/// </summary>
public class EmailResult
{
    public bool Success { get; set; }
    public string? MessageId { get; set; }
    public string? ErrorMessage { get; set; }
    public int AttemptsCount { get; set; }
}
