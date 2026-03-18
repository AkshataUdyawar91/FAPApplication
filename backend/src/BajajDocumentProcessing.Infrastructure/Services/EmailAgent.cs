using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Polly;
using Polly.Retry;
using System.Net;
using System.Net.Mail;
using System.Text;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Sends scenario-based HTML emails via SMTP with Polly retry (3 attempts, 5-min exponential backoff).
/// All delivery attempts are persisted to EmailDeliveryLogs for audit.
/// </summary>
public class EmailAgent : IEmailAgent
{
    private readonly IApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailAgent> _logger;
    private readonly ICorrelationIdService _correlationIdService;
    private readonly AsyncRetryPolicy _retryPolicy;

    private const string Brand = "ClaimsIQ";
    private const string BrandColor = "#003087";
    private const string AccentColor = "#00A3E0";
    private const string GreenColor = "#38a169";
    private const string RedColor = "#e53e3e";

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

        // 3 retries with 5-minute exponential backoff: 5m → 10m → 20m
        _retryPolicy = Policy
            .Handle<SmtpException>()
            .Or<Exception>(ex => ex is not OperationCanceledException)
            .WaitAndRetryAsync(
                retryCount: 3,
                sleepDurationProvider: attempt => TimeSpan.FromMinutes(5 * Math.Pow(2, attempt - 1)),
                onRetry: (exception, delay, attempt, _) =>
                    _logger.LogWarning(
                        exception,
                        "Email send attempt {Attempt} failed. Retrying in {Delay}. CorrelationId: {CorrelationId}",
                        attempt, delay, correlationIdService.GetCorrelationId()));
    }

    // ─── Template: Submission Received ──────────────────────────────────────

    /// <inheritdoc/>
    public async Task<EmailResult> SendSubmissionReceivedEmailAsync(
        Guid packageId, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.SubmittedBy)
            .Include(p => p.PO)
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
        if (package is null) return PackageNotFound();

        var fapId      = package.SubmissionNumber ?? packageId.ToString()[..8].ToUpper();
        var poNumber   = package.PO?.PONumber ?? "—";
        var invoice    = package.Invoices.FirstOrDefault();
        var invoiceNum = invoice?.InvoiceNumber ?? "—";
        var amtDisplay = $"&#8377;{invoice?.TotalAmount.GetValueOrDefault():N2}";
        var state      = package.ActivityState ?? "—";
        var submitted  = package.CreatedAt.ToString("dd-MMM-yyyy, hh:mm tt");

        // Fetch assigned Circle Head name for personalised next-steps
        var circleHeadName = await GetUserNameAsync(package.AssignedCircleHeadUserId, cancellationToken);

        var subject = $"Submission Received — {fapId}";

        var body = Card(
            subject: subject,
            recipientName: package.SubmittedBy?.FullName ?? "Agency",
            intro: "Your claim submission has been received.",
            detailRows: new[]
            {
                ("FAP ID",    fapId,      false),
                ("PO Number", poNumber,   false),
                ("Invoice",   invoiceNum, false),
                ("Amount",    amtDisplay, false),
                ("State",     state,      false),
                ("Submitted", submitted,  false),
            },
            reasonBox: null,
            nextSteps: new[]
            {
                $"Submission routes to {circleHeadName} for review",
                "You will be notified on approval or rejection",
            },
            buttonLabel: "Track Submission",
            buttonColor: BrandColor,
            buttonUrl: $"https://claimsiq.bajaj.com/fap/{fapId}",
            footerNote: $"You will receive a notification when {circleHeadName} reviews your submission."
        );

        return await SendAndLogAsync(packageId, "submission_received",
            package.SubmittedBy?.Email ?? "", subject, body, cancellationToken);
    }

    // ─── Template: Validation Failed ────────────────────────────────────────

    /// <inheritdoc/>
    public async Task<EmailResult> SendValidationFailedEmailAsync(
        Guid packageId, List<ValidationIssue> issues, CancellationToken cancellationToken = default)
    {
        var package = await LoadPackageWithUserAsync(packageId, cancellationToken);
        if (package is null) return PackageNotFound();

        var fapId = package.SubmissionNumber ?? packageId.ToString()[..8].ToUpper();

        // Build issue text for the reason box
        var issueText = new StringBuilder();
        foreach (var issue in issues)
        {
            issueText.Append($"<strong>{issue.Field}:</strong> {issue.Issue}");
            if (!string.IsNullOrEmpty(issue.ExpectedValue))
                issueText.Append($" Expected: {issue.ExpectedValue}.");
            if (!string.IsNullOrEmpty(issue.ActualValue))
                issueText.Append($" Found: {issue.ActualValue}.");
            issueText.Append("<br/>");
        }

        var subject = $"Action Required: Validation Failed — {fapId}";

        var body = Card(
            subject: subject,
            recipientName: package.SubmittedBy?.FullName ?? "Agency",
            intro: "Your document submission could not pass automated validation. Please review the issues below, correct your documents, and resubmit.",
            detailRows: new[] { ("FAP ID", fapId, false) },
            reasonBox: ($"Validation Issues", issueText.ToString(), RedColor),
            nextSteps: null,
            buttonLabel: "Correct and Resubmit",
            buttonColor: RedColor,
            buttonUrl: $"https://claimsiq.bajaj.com/fap/{fapId}",
            footerNote: "Please resubmit with corrections at your earliest convenience."
        );

        return await SendAndLogAsync(packageId, "validation_failed",
            package.SubmittedBy?.Email ?? "", subject, body, cancellationToken);
    }

    // ─── Template: Pending Circle Head ──────────────────────────────────────

    /// <inheritdoc/>
    public async Task<EmailResult> SendPendingCircleHeadEmailAsync(
        Guid packageId, string circleHeadEmail, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.SubmittedBy)
            .Include(p => p.PO)
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
        if (package is null) return PackageNotFound();

        var fapId      = package.SubmissionNumber ?? packageId.ToString()[..8].ToUpper();
        var poNumber   = package.PO?.PONumber ?? "—";
        var amount     = package.Invoices.FirstOrDefault()?.TotalAmount;
        var amtDisplay = amount.HasValue ? $"&#8377;{amount.Value:N0}" : "—";
        var agencyName = package.SubmittedBy?.FullName ?? "Agency";

        var confidence = await _context.ConfidenceScores
            .AsNoTracking()
            .Where(cs => cs.PackageId == packageId)
            .Select(cs => cs.OverallConfidence)
            .FirstOrDefaultAsync(cancellationToken);

        var subject = $"New Submission Pending Your Review — {fapId}";

        var body = Card(
            subject: subject,
            recipientName: "Circle Head",
            intro: $"A new claim submission from <strong>{agencyName}</strong> has passed AI validation and is awaiting your review.",
            detailRows: new[]
            {
                ("FAP ID",           fapId,                  false),
                ("PO Number",        poNumber,               false),
                ("Amount",           amtDisplay,             false),
                ("Confidence Score", $"{confidence:F1}%",    false),
            },
            reasonBox: null,
            nextSteps: null,
            buttonLabel: "Review Submission",
            buttonColor: BrandColor,
            buttonUrl: $"https://claimsiq.bajaj.com/fap/{fapId}",
            footerNote: "Please review and take action at your earliest convenience."
        );

        return await SendAndLogAsync(packageId, "pending_circle_head",
            circleHeadEmail, subject, body, cancellationToken);
    }

    // ─── Template: Circle Head Approved ─────────────────────────────────────

    /// <inheritdoc/>
    public async Task<EmailResult> SendCircleHeadApprovedEmailAsync(
        Guid packageId, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.SubmittedBy)
            .Include(p => p.PO)
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.RequestApprovalHistory)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
        if (package is null) return PackageNotFound();

        var fapId      = package.SubmissionNumber ?? packageId.ToString()[..8].ToUpper();
        var poNumber   = package.PO?.PONumber ?? "—";
        var amtDisplay = $"&#8377;{package.Invoices.FirstOrDefault()?.TotalAmount.GetValueOrDefault():N2}";

        var approval = package.RequestApprovalHistory
            .Where(h => h.ApproverRole == Domain.Enums.UserRole.ASM
                     && h.Action == Domain.Enums.ApprovalAction.Approved)
            .OrderByDescending(h => h.ActionDate)
            .FirstOrDefault();

        var approverName = await GetUserNameAsync(approval?.ApproverId, cancellationToken);
        var approvedOn   = (approval?.ActionDate ?? DateTime.UtcNow).ToString("dd-MMM-yyyy, hh:mm tt");
        var comments     = approval?.Comments ?? "All documents verified. Forwarding to RA.";

        var subject = $"Claim Approved — {fapId} ({amtDisplay})";

        var body = Card(
            subject: subject,
            recipientName: package.SubmittedBy?.FullName ?? "Agency",
            intro: $"Your claim has been <span style=\"color:{GreenColor};font-weight:bold\">approved</span> by {approverName} and forwarded for final approval.",
            detailRows: new[]
            {
                ("FAP ID",      fapId,        false),
                ("PO Number",   poNumber,     false),
                ("Amount",      amtDisplay,   false),
                ("Approved On", approvedOn,   false),
                ("Comments",    comments,     false),
            },
            reasonBox: null,
            nextSteps: null,
            buttonLabel: "View Status",
            buttonColor: GreenColor,
            buttonUrl: $"https://claimsiq.bajaj.com/fap/{fapId}",
            footerNote: "Your claim is now with the Regional Approver. You will be notified on final approval.",
            bodyNote: "No action needed. The Regional Approver will review next."
        );

        return await SendAndLogAsync(packageId, "circleHead_approved",
            package.SubmittedBy?.Email ?? "", subject, body, cancellationToken);
    }

    // ─── Template: Circle Head Rejected ─────────────────────────────────────

    /// <inheritdoc/>
    public async Task<EmailResult> SendCircleHeadRejectedEmailAsync(
        Guid packageId, string reason, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.SubmittedBy)
            .Include(p => p.PO)
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.RequestApprovalHistory)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
        if (package is null) return PackageNotFound();

        var fapId      = package.SubmissionNumber ?? packageId.ToString()[..8].ToUpper();
        var poNumber   = package.PO?.PONumber ?? "—";
        var amount     = package.Invoices.FirstOrDefault()?.TotalAmount;
        var amtDisplay = $"&#8377;{amount.GetValueOrDefault():N2}";

        var rejection = package.RequestApprovalHistory
            .Where(h => h.ApproverRole == Domain.Enums.UserRole.ASM
                     && h.Action == Domain.Enums.ApprovalAction.Rejected)
            .OrderByDescending(h => h.ActionDate)
            .FirstOrDefault();

        var approverName = await GetUserNameAsync(rejection?.ApproverId, cancellationToken);
        var returnedOn   = (rejection?.ActionDate ?? DateTime.UtcNow).ToString("dd-MMM-yyyy, hh:mm tt");

        var subject = $"Claim Requires Correction — {fapId}";

        var body = Card(
            subject: subject,
            recipientName: package.SubmittedBy?.FullName ?? "Agency",
            intro: $"Your claim has been <span style=\"color:{RedColor};font-weight:bold\">returned for correction</span> by {approverName}. Please review the feedback and resubmit.",
            detailRows: new[]
            {
                ("FAP ID",      fapId,        false),
                ("PO Number",   poNumber,     false),
                ("Amount",      amtDisplay,   false),
                ("Returned On", returnedOn,   false),
            },
            reasonBox: ("Reason for return:", reason, RedColor),
            nextSteps: null,
            buttonLabel: "Correct and Resubmit",
            buttonColor: RedColor,
            buttonUrl: $"https://claimsiq.bajaj.com/fap/{fapId}",
            footerNote: "Please resubmit with corrections at your earliest convenience.",
            bodyNote: "Log in to ClaimsIQ to correct and resubmit your claim."
        );

        return await SendAndLogAsync(packageId, "circleHead_rejected",
            package.SubmittedBy?.Email ?? "", subject, body, cancellationToken);
    }

    // ─── Template: RA Approved ───────────────────────────────────────────────

    /// <inheritdoc/>
    public async Task<EmailResult> SendRaApprovedEmailAsync(
        Guid packageId, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.SubmittedBy)
            .Include(p => p.PO)
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.RequestApprovalHistory)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
        if (package is null) return PackageNotFound();

        var fapId      = package.SubmissionNumber ?? packageId.ToString()[..8].ToUpper();
        var poNumber   = package.PO?.PONumber ?? "—";
        var amtDisplay = $"&#8377;{package.Invoices.FirstOrDefault()?.TotalAmount.GetValueOrDefault():N2}";

        var approval = package.RequestApprovalHistory
            .Where(h => h.ApproverRole == Domain.Enums.UserRole.RA
                     && h.Action == Domain.Enums.ApprovalAction.Approved)
            .OrderByDescending(h => h.ActionDate)
            .FirstOrDefault();

        var approvedOn = (approval?.ActionDate ?? DateTime.UtcNow).ToString("dd-MMM-yyyy, hh:mm tt");

        var subject = $"Final Approval — {fapId} ({amtDisplay})";

        var body = Card(
            subject: subject,
            recipientName: package.SubmittedBy?.FullName ?? "Agency",
            intro: $"Your claim has received <span style=\"color:{GreenColor};font-weight:bold\">final approval</span>. Payment processing will begin shortly.",
            detailRows: new[]
            {
                ("FAP ID",         fapId,        false),
                ("PO Number",      poNumber,     false),
                ("Payable Amount", amtDisplay,   true),
                ("Approved On",    approvedOn,   false),
            },
            reasonBox: null,
            nextSteps: null,
            buttonLabel: "View Details",
            buttonColor: GreenColor,
            buttonUrl: $"https://claimsiq.bajaj.com/fap/{fapId}",
            footerNote: "Payment will be processed as per the standard payment cycle. Thank you for using ClaimsIQ.",
            bodyNote: "No further action required. Payment will be processed as per the standard cycle."
        );

        return await SendAndLogAsync(packageId, "ra_approved",
            package.SubmittedBy?.Email ?? "", subject, body, cancellationToken);
    }

    // ─── Template: RA Rejected ───────────────────────────────────────────────

    /// <inheritdoc/>
    public async Task<EmailResult> SendRaRejectedEmailAsync(
        Guid packageId, string reason, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.SubmittedBy)
            .Include(p => p.PO)
            .Include(p => p.Invoices.Where(i => !i.IsDeleted))
            .Include(p => p.RequestApprovalHistory)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
        if (package is null) return PackageNotFound();

        var fapId      = package.SubmissionNumber ?? packageId.ToString()[..8].ToUpper();
        var poNumber   = package.PO?.PONumber ?? "—";
        var amount     = package.Invoices.FirstOrDefault()?.TotalAmount;
        var amtDisplay = $"&#8377;{amount.GetValueOrDefault():N2}";

        var rejection = package.RequestApprovalHistory
            .Where(h => h.ApproverRole == Domain.Enums.UserRole.RA
                     && h.Action == Domain.Enums.ApprovalAction.Rejected)
            .OrderByDescending(h => h.ActionDate)
            .FirstOrDefault();

        var approverName = await GetUserNameAsync(rejection?.ApproverId, cancellationToken);
        var returnedOn   = (rejection?.ActionDate ?? DateTime.UtcNow).ToString("dd-MMM-yyyy, hh:mm tt");

        var subject = $"Claim Returned by Regional Approver — {fapId}";

        var body = Card(
            subject: subject,
            recipientName: package.SubmittedBy?.FullName ?? "Agency",
            intro: $"Your claim has been <span style=\"color:{RedColor};font-weight:bold\">returned for correction</span> by {approverName} (Regional Approver). Please review the feedback below.",
            detailRows: new[]
            {
                ("FAP ID",      fapId,        false),
                ("PO Number",   poNumber,     false),
                ("Amount",      amtDisplay,   false),
                ("Returned On", returnedOn,   false),
            },
            reasonBox: ("Reason for return:", reason, RedColor),
            nextSteps: null,
            buttonLabel: "Correct and Resubmit",
            buttonColor: RedColor,
            buttonUrl: $"https://claimsiq.bajaj.com/fap/{fapId}",
            footerNote: "Please resubmit with corrections. The claim will go through Circle Head review again after resubmission.",
            bodyNote: "After correction, your claim will go through the full review cycle again."
        );

        return await SendAndLogAsync(packageId, "ra_rejected",
            package.SubmittedBy?.Email ?? "", subject, body, cancellationToken);
    }

    // ─── Legacy compatibility ────────────────────────────────────────────────

    /// <inheritdoc/>
    public Task<EmailResult> SendDataFailureEmailAsync(Guid packageId, List<ValidationIssue> issues, CancellationToken cancellationToken = default)
        => SendValidationFailedEmailAsync(packageId, issues, cancellationToken);

    /// <inheritdoc/>
    public Task<EmailResult> SendDataPassEmailAsync(Guid packageId, string asmEmail, CancellationToken cancellationToken = default)
        => SendPendingCircleHeadEmailAsync(packageId, asmEmail, cancellationToken);

    /// <inheritdoc/>
    public Task<EmailResult> SendApprovedEmailAsync(Guid packageId, string agencyEmail, CancellationToken cancellationToken = default)
        => SendRaApprovedEmailAsync(packageId, cancellationToken);

    /// <inheritdoc/>
    public Task<EmailResult> SendRejectedEmailAsync(Guid packageId, string agencyEmail, string reason, CancellationToken cancellationToken = default)
        => SendCircleHeadRejectedEmailAsync(packageId, reason, cancellationToken);

    // ─── Core send + log ─────────────────────────────────────────────────────

    private async Task<EmailResult> SendAndLogAsync(
        Guid packageId, string templateName, string recipientEmails,
        string subject, string body, CancellationToken cancellationToken)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Sending email template '{Template}' to {Email} for package {PackageId}. CorrelationId: {CorrelationId}",
            templateName, recipientEmails, packageId, correlationId);

        if (string.IsNullOrWhiteSpace(recipientEmails))
        {
            _logger.LogWarning("No recipient email for package {PackageId}, template {Template}", packageId, templateName);
            return new EmailResult { Success = false, ErrorMessage = "Recipient email is empty", AttemptsCount = 0 };
        }

        var attempts = 0;
        string? messageId = null;
        string? errorMessage = null;
        var success = false;

        try
        {
            await _retryPolicy.ExecuteAsync(async ct =>
            {
                attempts++;
                messageId = await SendSmtpAsync(recipientEmails, subject, body, ct);
                success = true;
            }, cancellationToken);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            errorMessage = ex.Message;
            _logger.LogError(ex,
                "All retry attempts exhausted for template '{Template}' to {Email}. CorrelationId: {CorrelationId}",
                templateName, recipientEmails, correlationId);
        }

        try
        {
            var log = new EmailDeliveryLog
            {
                Id             = Guid.NewGuid(),
                PackageId      = packageId,
                TemplateName   = templateName,
                RecipientEmail = recipientEmails,
                Subject        = subject,
                Success        = success,
                AttemptsCount  = attempts,
                MessageId      = messageId,
                ErrorMessage   = errorMessage,
                SentAt         = DateTime.UtcNow,
            };
            _context.EmailDeliveryLogs.Add(log);
            await _context.SaveChangesAsync(CancellationToken.None);
        }
        catch (Exception logEx)
        {
            _logger.LogError(logEx, "Failed to persist EmailDeliveryLog for package {PackageId}", packageId);
        }

        if (success)
            _logger.LogInformation(
                "Email '{Template}' delivered to {Email} in {Attempts} attempt(s). MessageId: {MessageId}",
                templateName, recipientEmails, attempts, messageId);

        return new EmailResult { Success = success, MessageId = messageId, ErrorMessage = errorMessage, AttemptsCount = attempts };
    }

    private async Task<string> SendSmtpAsync(
        string recipientEmails, string subject, string body, CancellationToken cancellationToken)
    {
        var host        = _configuration["Smtp:Host"] ?? throw new InvalidOperationException("Smtp:Host not configured");
        var port        = int.Parse(_configuration["Smtp:Port"] ?? "587");
        var username    = _configuration["Smtp:Username"] ?? "";
        var password    = _configuration["Smtp:Password"] ?? "";
        var senderEmail = _configuration["Smtp:SenderEmail"] ?? username;
        var senderName  = _configuration["Smtp:SenderName"] ?? Brand;
        var enableSsl   = bool.Parse(_configuration["Smtp:EnableSsl"] ?? "true");

        using var client = new SmtpClient(host, port)
        {
            Credentials = new NetworkCredential(username, password),
            EnableSsl = enableSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network
        };

        using var message = new MailMessage
        {
            From = new MailAddress(senderEmail, senderName),
            Subject = subject,
            Body = body,
            IsBodyHtml = true
        };

        foreach (var addr in recipientEmails.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            message.To.Add(addr);

        await client.SendMailAsync(message, cancellationToken);
        return $"smtp_{Guid.NewGuid():N}";
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private async Task<Domain.Entities.DocumentPackage?> LoadPackageWithUserAsync(
        Guid packageId, CancellationToken cancellationToken)
    {
        var pkg = await _context.DocumentPackages
            .Include(p => p.SubmittedBy)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);
        if (pkg is null) _logger.LogError("Package {PackageId} not found when sending email", packageId);
        return pkg;
    }

    private async Task<string> GetUserNameAsync(Guid? userId, CancellationToken cancellationToken)
    {
        if (!userId.HasValue) return "ClaimsIQ System";
        return await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId.Value)
            .Select(u => u.FullName)
            .FirstOrDefaultAsync(cancellationToken) ?? "ClaimsIQ System";
    }

    private static EmailResult PackageNotFound() =>
        new() { Success = false, ErrorMessage = "Package not found", AttemptsCount = 0 };

    /// <summary>
    /// Builds the white card email HTML matching the screenshot layout:
    /// - White card on light-grey page background
    /// - "C ClaimsIQ  Bajaj Auto" header row with blue bottom border
    /// - Bold recipient greeting
    /// - Intro line (may contain inline colored spans)
    /// - Bordered detail table with blue left-column labels
    /// - Optional red reason box
    /// - Optional numbered next-steps list
    /// - CTA button
    /// - Italic grey footer note
    /// </summary>
    private static string Card(
        string subject,
        string recipientName,
        string intro,
        IEnumerable<(string Label, string Value, bool Highlight)> detailRows,
        (string Title, string Body, string Color)? reasonBox,
        IEnumerable<string>? nextSteps,
        string buttonLabel,
        string buttonColor,
        string buttonUrl,
        string footerNote,
        string? bodyNote = null)
    {
        // ── detail table ──────────────────────────────────────────────────
        var rows = new StringBuilder();
        foreach (var (label, value, highlight) in detailRows)
        {
            var valueStyle = highlight
                ? $"color:{GreenColor};font-weight:bold"
                : "color:#1a202c";
            rows.Append($"""
                <tr>
                  <td style="padding:10px 14px;color:{BrandColor};font-weight:normal;width:38%;border-bottom:1px solid #e2e8f0;white-space:nowrap">{label}</td>
                  <td style="padding:10px 14px;{valueStyle};border-bottom:1px solid #e2e8f0">{value}</td>
                </tr>
                """);
        }

        // ── reason box ────────────────────────────────────────────────────
        var reasonHtml = reasonBox.HasValue
            ? $"""
              <div style="background:#fff5f5;border:1px solid #fed7d7;border-radius:6px;padding:14px 16px;margin:20px 0">
                <p style="margin:0 0 6px;color:{reasonBox.Value.Color};font-weight:bold">{reasonBox.Value.Title}</p>
                <p style="margin:0;color:#1a202c;line-height:1.6">{reasonBox.Value.Body}</p>
              </div>
              """
            : "";

        // ── next steps ────────────────────────────────────────────────────
        var stepsHtml = "";
        if (nextSteps is not null)
        {
            var items = new StringBuilder();
            foreach (var step in nextSteps)
                items.Append($"<li style=\"margin-bottom:4px\">{step}</li>");
            stepsHtml = $"""
                <p style="margin:20px 0 8px;font-weight:bold">What happens next:</p>
                <ol style="margin:0;padding-left:20px;color:#1a202c;line-height:1.7">{items}</ol>
                """;
        }

        // ── body note (e.g. "After correction..." line) ──────────────────
        var bodyNoteHtml = !string.IsNullOrEmpty(bodyNote)
            ? $"""<p style="margin:16px 0 0;color:#1a202c;font-size:13px">{bodyNote}</p>"""
            : "";

        // ── CTA button ────────────────────────────────────────────────────
        var button = $"""
            <p style="margin:24px 0 0">
              <a href="{buttonUrl}"
                 style="display:inline-block;background:{buttonColor};color:#ffffff;font-weight:bold;
                        font-size:14px;padding:11px 24px;border-radius:6px;text-decoration:none">
                {buttonLabel}
              </a>
            </p>
            """;

        // ── assemble ──────────────────────────────────────────────────────
        return $"""
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8"/>
              <meta name="viewport" content="width=device-width,initial-scale=1"/>
            </head>
            <body style="margin:0;padding:0;background:#f0f2f5;font-family:Arial,Helvetica,sans-serif">
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f2f5;padding:32px 16px">
                <tr><td align="center">

                  <!-- White card -->
                  <table width="100%" cellpadding="0" cellspacing="0"
                         style="background:#ffffff;border-radius:8px;max-width:560px;
                                box-shadow:0 1px 4px rgba(0,0,0,.12);overflow:hidden">

                    <!-- Card header: C logo + ClaimsIQ + Bajaj Auto + blue underline -->
                    <tr>
                      <td style="padding:20px 28px 16px;border-bottom:2px solid {BrandColor}">
                        <table cellpadding="0" cellspacing="0">
                          <tr>
                            <td style="background:{BrandColor};border-radius:8px;
                                       width:38px;height:38px;text-align:center;vertical-align:middle">
                              <span style="color:#ffffff;font-size:20px;font-weight:bold;line-height:38px;display:block">C</span>
                            </td>
                            <td style="padding-left:12px;vertical-align:middle">
                              <span style="color:{BrandColor};font-size:20px;font-weight:bold;letter-spacing:-0.3px">{Brand}</span>
                              <span style="color:#a0aec0;font-size:13px;margin-left:10px;font-weight:normal">Bajaj Auto</span>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>

                    <!-- Card body -->
                    <tr>
                      <td style="padding:28px 28px 24px;color:#1a202c;font-size:14px;line-height:1.7">

                        <p style="margin:0 0 14px">
                          Dear <strong>{recipientName}</strong>,
                        </p>

                        <p style="margin:0 0 18px">{intro}</p>

                        <!-- Detail table -->
                        <table width="100%" cellpadding="0" cellspacing="0"
                               style="border:1px solid #e2e8f0;border-radius:6px;
                                      border-collapse:collapse;margin-bottom:4px">
                          <tbody>{rows}</tbody>
                        </table>

                        {reasonHtml}
                        {stepsHtml}
                        {bodyNoteHtml}
                        {button}

                      </td>
                    </tr>

                    <!-- Card footer note -->
                    <tr>
                      <td style="padding:14px 28px 20px;border-top:1px solid #e2e8f0;
                                 color:#a0aec0;font-size:11px;font-style:italic">
                        {footerNote}
                      </td>
                    </tr>

                  </table>
                  <!-- /White card -->

                </td></tr>
              </table>
            </body>
            </html>
            """;
    }
}
