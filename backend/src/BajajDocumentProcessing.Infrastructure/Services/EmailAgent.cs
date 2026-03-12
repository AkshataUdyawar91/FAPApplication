using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Text;
using MailKit.Net.Smtp;
using MimeKit;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for generating and sending scenario-based emails via Azure Communication Services
/// </summary>
public class EmailAgent : IEmailAgent
{
    private readonly IApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailAgent> _logger;
    private readonly ICorrelationIdService _correlationIdService;

    // Retry configuration
    private const int MAX_RETRY_ATTEMPTS = 3;
    private static readonly TimeSpan[] RetryDelays = { TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(4) };

    public EmailAgent(
        IApplicationDbContext context,
        IConfiguration configuration,
        ILogger<EmailAgent> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _configuration = configuration;
        _logger = logger;
        _correlationIdService = correlationIdService;
    }

    /// <summary>
    /// Sends a data failure notification email to the agency user when document validation fails.
    /// </summary>
    /// <param name="packageId">The unique identifier of the failed document package.</param>
    /// <param name="issues">List of validation issues that caused the failure.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>An <see cref="EmailResult"/> indicating success or failure, including retry attempt count.</returns>
    /// <remarks>
    /// This method:
    /// - Loads the package and submitting user information
    /// - Generates an HTML email body listing all validation issues
    /// - Sends the email with exponential backoff retry logic (up to 3 attempts)
    /// - Returns detailed result including message ID on success or error message on failure
    /// </remarks>
    public async Task<EmailResult> SendDataFailureEmailAsync(
        Guid packageId,
        List<ValidationIssue> issues,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Sending data failure email for package {PackageId}. CorrelationId: {CorrelationId}",
            packageId, correlationId);

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
            _logger.LogError(
                ex,
                "Error sending data failure email for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    /// <summary>
    /// Sends a notification email to the ASM when a document package passes validation and is ready for review.
    /// </summary>
    /// <param name="packageId">The unique identifier of the validated document package.</param>
    /// <param name="asmEmail">The email address of the Area Sales Manager.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>An <see cref="EmailResult"/> indicating success or failure, including retry attempt count.</returns>
    /// <remarks>
    /// This method:
    /// - Loads the package, confidence score, and AI recommendation
    /// - Generates an HTML email body with package details and AI recommendation
    /// - Sends the email with exponential backoff retry logic (up to 3 attempts)
    /// - Notifies the ASM to log in and review the submission
    /// </remarks>
    public async Task<EmailResult> SendDataPassEmailAsync(
        Guid packageId,
        string asmEmail,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Sending data pass email for package {PackageId} to ASM {Email}. CorrelationId: {CorrelationId}",
            packageId, asmEmail, correlationId);

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
            _logger.LogError(
                ex,
                "Error sending data pass email for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    /// <summary>
    /// Sends an approval notification email to the agency user when their document package is approved.
    /// </summary>
    /// <param name="packageId">The unique identifier of the approved document package.</param>
    /// <param name="agencyEmail">The email address of the agency user.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>An <see cref="EmailResult"/> indicating success or failure, including retry attempt count.</returns>
    /// <remarks>
    /// This method:
    /// - Loads the package information
    /// - Generates a congratulatory HTML email body
    /// - Sends the email with exponential backoff retry logic (up to 3 attempts)
    /// - Confirms successful processing of the documents
    /// </remarks>
    public async Task<EmailResult> SendApprovedEmailAsync(
        Guid packageId,
        string agencyEmail,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Sending approved email for package {PackageId} to {Email}. CorrelationId: {CorrelationId}",
            packageId, agencyEmail, correlationId);

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
            _logger.LogError(
                ex,
                "Error sending approved email for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    /// <summary>
    /// Sends a rejection notification email to the agency user when their document package is rejected.
    /// </summary>
    /// <param name="packageId">The unique identifier of the rejected document package.</param>
    /// <param name="agencyEmail">The email address of the agency user.</param>
    /// <param name="reason">The reason for rejection provided by the reviewer.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>An <see cref="EmailResult"/> indicating success or failure, including retry attempt count.</returns>
    /// <remarks>
    /// This method:
    /// - Loads the package information
    /// - Generates an HTML email body with the rejection reason
    /// - Sends the email with exponential backoff retry logic (up to 3 attempts)
    /// - Instructs the user to review feedback and resubmit corrected documents
    /// </remarks>
    public async Task<EmailResult> SendRejectedEmailAsync(
        Guid packageId,
        string agencyEmail,
        string reason,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Sending rejected email for package {PackageId} to {Email}. CorrelationId: {CorrelationId}",
            packageId, agencyEmail, correlationId);

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
            _logger.LogError(
                ex,
                "Error sending rejected email for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    /// <summary>
    /// Sends a pre-built PO details email to a vendor contact with retry logic.
    /// </summary>
    public async Task<EmailResult> SendVendorPOEmailAsync(
        string recipientEmail,
        string subject,
        string body,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Sending vendor PO email to {Email}. Subject: {Subject}. CorrelationId: {CorrelationId}",
            recipientEmail, subject, correlationId);

        try
        {
            return await SendEmailWithRetryAsync(recipientEmail, subject, body, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error sending vendor PO email to {Email}. CorrelationId: {CorrelationId}",
                recipientEmail, correlationId);
            return new EmailResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                AttemptsCount = 0
            };
        }
    }

    /// <summary>
    /// Sends an email with exponential backoff retry logic to handle transient failures.
    /// </summary>
    /// <param name="recipientEmail">The recipient's email address.</param>
    /// <param name="subject">The email subject line.</param>
    /// <param name="body">The HTML email body content.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>An <see cref="EmailResult"/> with success status, message ID (on success), error message (on failure), and attempt count.</returns>
    /// <remarks>
    /// Retry strategy:
    /// - Maximum 3 attempts
    /// - Exponential backoff delays: 1s, 2s, 4s
    /// - Logs warnings on retry, errors on final failure
    /// - Returns detailed result including number of attempts made
    /// </remarks>
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
    /// Sends an email via Azure Communication Services.
    /// </summary>
    /// <param name="recipientEmail">The recipient's email address.</param>
    /// <param name="subject">The email subject line.</param>
    /// <param name="body">The HTML email body content.</param>
    /// <param name="cancellationToken">Token to cancel the asynchronous operation.</param>
    /// <returns>A unique message identifier for tracking the email delivery.</returns>
    /// <remarks>
    /// <para><strong>NOTE: This is a placeholder implementation.</strong></para>
    /// <para>
    /// FUTURE ENHANCEMENT: Azure Communication Services Integration
    /// This method currently uses a mock implementation for email sending.
    /// To integrate with Azure Communication Services:
    /// </para>
    /// <list type="number">
    /// <item><description>Add Azure.Communication.Email NuGet package</description></item>
    /// <item><description>Configure ACS connection string in appsettings.json</description></item>
    /// <item><description>Replace mock implementation with actual EmailClient SDK calls</description></item>
    /// <item><description>Handle ACS-specific exceptions and retry policies</description></item>
    /// </list>
    /// <para>
    /// Example implementation:
    /// <code>
    /// var emailClient = new EmailClient(connectionString);
    /// var emailSendOperation = await emailClient.SendAsync(
    ///     Azure.WaitUntil.Completed,
    ///     senderAddress: "noreply@bajaj.com",
    ///     recipientAddress: recipientEmail,
    ///     subject: subject,
    ///     htmlContent: body,
    ///     cancellationToken: cancellationToken);
    /// return emailSendOperation.Id;
    /// </code>
    /// </para>
    /// </remarks>
    private async Task<string> SendEmailViaACSAsync(
        string recipientEmail,
        string subject,
        string body,
        CancellationToken cancellationToken)
    {
        var smtpHost = _configuration["Smtp:Host"];
        var smtpPort = int.Parse(_configuration["Smtp:Port"] ?? "587");
        var smtpUsername = _configuration["Smtp:Username"];
        var smtpPassword = _configuration["Smtp:Password"];
        var senderEmail = _configuration["Smtp:SenderEmail"] ?? smtpUsername;
        var senderName = _configuration["Smtp:SenderName"] ?? "Bajaj FAP System";

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(senderName, senderEmail));
        message.To.Add(MailboxAddress.Parse(recipientEmail));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = body };

        using var client = new SmtpClient();
        await client.ConnectAsync(smtpHost, smtpPort, MailKit.Security.SecureSocketOptions.StartTls, cancellationToken);
        await client.AuthenticateAsync(smtpUsername, smtpPassword, cancellationToken);
        var response = await client.SendAsync(message, cancellationToken);
        await client.DisconnectAsync(true, cancellationToken);

        return response ?? $"msg_{Guid.NewGuid():N}";
    }

    /// <summary>
    /// Generates an HTML email body for data failure notifications.
    /// </summary>
    /// <param name="userName">The name of the agency user who submitted the documents.</param>
    /// <param name="issues">List of validation issues to include in the email.</param>
    /// <returns>An HTML-formatted email body listing all validation issues with expected vs. actual values.</returns>
    /// <remarks>
    /// The email includes:
    /// - Personalized greeting
    /// - List of validation issues with field names and descriptions
    /// - Expected vs. actual values where applicable
    /// - Instructions to correct and resubmit
    /// </remarks>
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
    /// Generates an HTML email body for data pass notifications to ASM.
    /// </summary>
    /// <param name="agencyName">The name of the agency that submitted the documents.</param>
    /// <param name="packageId">The unique identifier of the document package.</param>
    /// <param name="confidence">The overall confidence score (0-100).</param>
    /// <param name="recommendation">The AI recommendation type (APPROVE, REVIEW, or REJECT).</param>
    /// <returns>An HTML-formatted email body with package details and AI recommendation.</returns>
    /// <remarks>
    /// The email includes:
    /// - Notification that a package passed validation
    /// - Package ID for reference
    /// - Confidence score percentage
    /// - AI recommendation
    /// - Instructions to log in and review
    /// </remarks>
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
    /// Generates an HTML email body for approval notifications.
    /// </summary>
    /// <param name="userName">The name of the agency user who submitted the documents.</param>
    /// <param name="packageId">The unique identifier of the approved document package.</param>
    /// <returns>An HTML-formatted congratulatory email body confirming approval.</returns>
    /// <remarks>
    /// The email includes:
    /// - Congratulatory message
    /// - Package ID for reference
    /// - Confirmation that documents are in the system
    /// - Thank you message
    /// </remarks>
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
    /// Generates an HTML email body for rejection notifications.
    /// </summary>
    /// <param name="userName">The name of the agency user who submitted the documents.</param>
    /// <param name="packageId">The unique identifier of the rejected document package.</param>
    /// <param name="reason">The reason for rejection provided by the reviewer.</param>
    /// <returns>An HTML-formatted email body with rejection reason and instructions to resubmit.</returns>
    /// <remarks>
    /// The email includes:
    /// - Notification of rejection
    /// - Package ID for reference
    /// - Detailed reason for rejection
    /// - Instructions to review feedback, make corrections, and resubmit
    /// </remarks>
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
