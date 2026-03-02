using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Text;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for generating and sending scenario-based emails via Azure Communication Services
/// </summary>
public class EmailAgent : IEmailAgent
{
    private readonly IApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailAgent> _logger;

    // Retry configuration
    private const int MAX_RETRY_ATTEMPTS = 3;
    private static readonly TimeSpan[] RetryDelays = { TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(4) };

    public EmailAgent(
        IApplicationDbContext context,
        IConfiguration configuration,
        ILogger<EmailAgent> logger)
    {
        _context = context;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<EmailResult> SendDataFailureEmailAsync(
        Guid packageId,
        List<ValidationIssue> issues,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Sending data failure email for package {PackageId}", packageId);

        try
        {
            // Load package with user
            var package = await _context.DocumentPackages
                .Include(p => p.SubmittedBy)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null || package.SubmittedBy == null)
            {
                _logger.LogError("Package {PackageId} or user not found", packageId);
                return new EmailResult
                {
                    Success = false,
                    ErrorMessage = "Package or user not found",
                    AttemptsCount = 0
                };
            }

            // Generate email content
            var subject = "Action Required: Document Validation Failed";
            var body = GenerateDataFailureEmailBody(package.SubmittedBy.FullName, issues);

            // Send email with retry logic
            return await SendEmailWithRetryAsync(package.SubmittedBy.Email, subject, body, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending data failure email for package {PackageId}", packageId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    public async Task<EmailResult> SendDataPassEmailAsync(
        Guid packageId,
        string asmEmail,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Sending data pass email for package {PackageId} to ASM {Email}", packageId, asmEmail);

        try
        {
            // Load package with confidence score and recommendation
            var package = await _context.DocumentPackages
                .Include(p => p.SubmittedBy)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            var confidenceScore = await _context.ConfidenceScores
                .FirstOrDefaultAsync(cs => cs.PackageId == packageId, cancellationToken);

            var recommendation = await _context.Recommendations
                .FirstOrDefaultAsync(r => r.PackageId == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                return new EmailResult
                {
                    Success = false,
                    ErrorMessage = "Package not found",
                    AttemptsCount = 0
                };
            }

            // Generate email content
            var subject = "New Document Package Ready for Review";
            var body = GenerateDataPassEmailBody(
                package.SubmittedBy?.FullName ?? "Agency",
                packageId,
                confidenceScore?.OverallConfidence ?? 0,
                recommendation?.Type.ToString() ?? "REVIEW");

            // Send email with retry logic
            return await SendEmailWithRetryAsync(asmEmail, subject, body, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending data pass email for package {PackageId}", packageId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    public async Task<EmailResult> SendApprovedEmailAsync(
        Guid packageId,
        string agencyEmail,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Sending approved email for package {PackageId} to {Email}", packageId, agencyEmail);

        try
        {
            // Load package
            var package = await _context.DocumentPackages
                .Include(p => p.SubmittedBy)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                return new EmailResult
                {
                    Success = false,
                    ErrorMessage = "Package not found",
                    AttemptsCount = 0
                };
            }

            // Generate email content
            var subject = "Document Package Approved";
            var body = GenerateApprovedEmailBody(package.SubmittedBy?.FullName ?? "Agency", packageId);

            // Send email with retry logic
            return await SendEmailWithRetryAsync(agencyEmail, subject, body, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending approved email for package {PackageId}", packageId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    public async Task<EmailResult> SendRejectedEmailAsync(
        Guid packageId,
        string agencyEmail,
        string reason,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Sending rejected email for package {PackageId} to {Email}", packageId, agencyEmail);

        try
        {
            // Load package
            var package = await _context.DocumentPackages
                .Include(p => p.SubmittedBy)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                return new EmailResult
                {
                    Success = false,
                    ErrorMessage = "Package not found",
                    AttemptsCount = 0
                };
            }

            // Generate email content
            var subject = "Document Package Rejected";
            var body = GenerateRejectedEmailBody(package.SubmittedBy?.FullName ?? "Agency", packageId, reason);

            // Send email with retry logic
            return await SendEmailWithRetryAsync(agencyEmail, subject, body, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending rejected email for package {PackageId}", packageId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    /// <summary>
    /// Sends email with exponential backoff retry logic
    /// </summary>
    private async Task<EmailResult> SendEmailWithRetryAsync(
        string recipientEmail,
        string subject,
        string body,
        CancellationToken cancellationToken)
    {
        int attempts = 0;
        Exception? lastException = null;

        for (int i = 0; i < MAX_RETRY_ATTEMPTS; i++)
        {
            attempts++;

            try
            {
                // Simulate email sending (replace with actual ACS implementation)
                var messageId = await SendEmailViaACSAsync(recipientEmail, subject, body, cancellationToken);

                _logger.LogInformation(
                    "Email sent successfully to {Email} on attempt {Attempt}. MessageId: {MessageId}",
                    recipientEmail,
                    attempts,
                    messageId);

                return new EmailResult
                {
                    Success = true,
                    MessageId = messageId,
                    AttemptsCount = attempts
                };
            }
            catch (Exception ex)
            {
                lastException = ex;
                _logger.LogWarning(
                    ex,
                    "Email send attempt {Attempt} failed for {Email}",
                    attempts,
                    recipientEmail);

                // Wait before retry (except on last attempt)
                if (i < MAX_RETRY_ATTEMPTS - 1)
                {
                    await Task.Delay(RetryDelays[i], cancellationToken);
                }
            }
        }

        // All retries failed
        _logger.LogError(
            lastException,
            "Failed to send email to {Email} after {Attempts} attempts",
            recipientEmail,
            attempts);

        return new EmailResult
        {
            Success = false,
            ErrorMessage = lastException?.Message ?? "Unknown error",
            AttemptsCount = attempts
        };
    }

    /// <summary>
    /// Sends email via Azure Communication Services
    /// NOTE: This is a placeholder implementation. Replace with actual ACS SDK calls.
    /// </summary>
    private async Task<string> SendEmailViaACSAsync(
        string recipientEmail,
        string subject,
        string body,
        CancellationToken cancellationToken)
    {
        // TODO: Replace with actual Azure Communication Services implementation
        // Example:
        // var emailClient = new EmailClient(connectionString);
        // var emailSendOperation = await emailClient.SendAsync(
        //     Azure.WaitUntil.Completed,
        //     senderAddress: "noreply@bajaj.com",
        //     recipientAddress: recipientEmail,
        //     subject: subject,
        //     htmlContent: body,
        //     cancellationToken: cancellationToken);
        // return emailSendOperation.Id;

        // Simulate async operation
        await Task.Delay(100, cancellationToken);

        // Generate mock message ID
        return $"msg_{Guid.NewGuid():N}";
    }

    /// <summary>
    /// Generates email body for data failure scenario
    /// </summary>
    private string GenerateDataFailureEmailBody(string userName, List<ValidationIssue> issues)
    {
        var body = new StringBuilder();
        body.AppendLine($"<html><body>");
        body.AppendLine($"<p>Dear {userName},</p>");
        body.AppendLine($"<p>Your document submission has failed validation. Please review the following issues and re-upload the corrected documents:</p>");
        body.AppendLine($"<ul>");

        foreach (var issue in issues)
        {
            body.AppendLine($"<li><strong>{issue.Field}</strong>: {issue.Issue}");
            if (!string.IsNullOrEmpty(issue.ExpectedValue) && !string.IsNullOrEmpty(issue.ActualValue))
            {
                body.AppendLine($"<br/>Expected: {issue.ExpectedValue}, Found: {issue.ActualValue}");
            }
            body.AppendLine($"</li>");
        }

        body.AppendLine($"</ul>");
        body.AppendLine($"<p>Please correct these issues and submit your documents again.</p>");
        body.AppendLine($"<p>Best regards,<br/>Bajaj Document Processing System</p>");
        body.AppendLine($"</body></html>");

        return body.ToString();
    }

    /// <summary>
    /// Generates email body for data pass scenario
    /// </summary>
    private string GenerateDataPassEmailBody(string agencyName, Guid packageId, double confidence, string recommendation)
    {
        var body = new StringBuilder();
        body.AppendLine($"<html><body>");
        body.AppendLine($"<p>Dear ASM,</p>");
        body.AppendLine($"<p>A new document package from <strong>{agencyName}</strong> has passed validation and is ready for your review.</p>");
        body.AppendLine($"<p><strong>Package Details:</strong></p>");
        body.AppendLine($"<ul>");
        body.AppendLine($"<li>Package ID: {packageId}</li>");
        body.AppendLine($"<li>Confidence Score: {confidence:F1}%</li>");
        body.AppendLine($"<li>AI Recommendation: {recommendation}</li>");
        body.AppendLine($"</ul>");
        body.AppendLine($"<p>Please log in to the system to review and approve or reject this submission.</p>");
        body.AppendLine($"<p>Best regards,<br/>Bajaj Document Processing System</p>");
        body.AppendLine($"</body></html>");

        return body.ToString();
    }

    /// <summary>
    /// Generates email body for approved scenario
    /// </summary>
    private string GenerateApprovedEmailBody(string userName, Guid packageId)
    {
        var body = new StringBuilder();
        body.AppendLine($"<html><body>");
        body.AppendLine($"<p>Dear {userName},</p>");
        body.AppendLine($"<p>Congratulations! Your document submission (Package ID: {packageId}) has been approved.</p>");
        body.AppendLine($"<p>Your documents have been successfully processed and are now in the system.</p>");
        body.AppendLine($"<p>Thank you for your submission.</p>");
        body.AppendLine($"<p>Best regards,<br/>Bajaj Document Processing System</p>");
        body.AppendLine($"</body></html>");

        return body.ToString();
    }

    /// <summary>
    /// Generates email body for rejected scenario
    /// </summary>
    private string GenerateRejectedEmailBody(string userName, Guid packageId, string reason)
    {
        var body = new StringBuilder();
        body.AppendLine($"<html><body>");
        body.AppendLine($"<p>Dear {userName},</p>");
        body.AppendLine($"<p>Your document submission (Package ID: {packageId}) has been rejected.</p>");
        body.AppendLine($"<p><strong>Reason for Rejection:</strong></p>");
        body.AppendLine($"<p>{reason}</p>");
        body.AppendLine($"<p>Please review the feedback, make the necessary corrections, and submit your documents again.</p>");
        body.AppendLine($"<p>Best regards,<br/>Bajaj Document Processing System</p>");
        body.AppendLine($"</body></html>");

        return body.ToString();
    }
}
