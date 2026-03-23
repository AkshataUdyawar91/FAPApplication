using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Conversation;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Tests for duplicate submission detection in ConversationalSubmissionService.
/// Validates Requirement 10: Warn when same PO + invoice number combination already exists.
/// </summary>
public class DuplicateSubmissionDetectionTests : IDisposable
{
    private readonly ApplicationDbContext _context;
    private readonly Mock<IDocumentAgent> _mockDocumentAgent;
    private readonly Mock<IProactiveValidationService> _mockProactiveValidation;
    private readonly Mock<ISubmissionNumberService> _mockSubmissionNumber;
    private readonly Mock<ILogger<ConversationalSubmissionService>> _mockLogger;
    private readonly ConversationalSubmissionService _service;

    private readonly Guid _agencyId = Guid.NewGuid();
    private readonly Guid _userId = Guid.NewGuid();

    public DuplicateSubmissionDetectionTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options);

        _mockDocumentAgent = new Mock<IDocumentAgent>();
        _mockProactiveValidation = new Mock<IProactiveValidationService>();
        _mockSubmissionNumber = new Mock<ISubmissionNumberService>();
        _mockLogger = new Mock<ILogger<ConversationalSubmissionService>>();

        _mockProactiveValidation
            .Setup(v => v.ValidateDocumentAsync(It.IsAny<Guid>(), It.IsAny<DocumentType>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ProactiveValidationResponse
            {
                DocumentId = Guid.NewGuid(),
                DocumentType = DocumentType.Invoice,
                AllPassed = true,
                PassCount = 9,
                FailCount = 0,
                WarningCount = 0,
                Rules = new List<ProactiveRuleResult>()
            });

        _service = new ConversationalSubmissionService(
            _context,
            _mockDocumentAgent.Object,
            _mockProactiveValidation.Object,
            _mockSubmissionNumber.Object,
            _mockLogger.Object);
    }

    public void Dispose() => _context.Dispose();

    #region Helpers

    private async Task<(DocumentPackage existing, DocumentPackage current, Invoice invoice)> SeedDuplicateScenarioAsync(
        PackageState existingState = PackageState.PendingCH,
        string poNumber = "PO-2026-001",
        string invoiceNumber = "INV-001")
    {
        var agency = new Agency { Id = _agencyId, SupplierCode = "V001", SupplierName = "Test Agency" };
        var user = new User { Id = _userId, Email = "test@test.com", FullName = "Test User", AgencyId = _agencyId };
        _context.Agencies.Add(agency);
        _context.Users.Add(user);

        // Existing submission with the same PO + invoice
        var existingPackageId = Guid.NewGuid();
        var existingPo = new PO
        {
            Id = Guid.NewGuid(),
            PackageId = existingPackageId,
            PONumber = poNumber,
            FileName = "po.pdf",
            BlobUrl = "https://blob/po.pdf",
            ContentType = "application/pdf"
        };

        var existingPackage = new DocumentPackage
        {
            Id = existingPackageId,
            AgencyId = _agencyId,
            SubmittedByUserId = _userId,
            State = existingState,
            SubmissionNumber = "CIQ-2026-00001",
            SelectedPOId = existingPo.Id,
            CurrentStep = (int)ConversationStep.Submitted,
            VersionNumber = 1
        };
        _context.DocumentPackages.Add(existingPackage);
        _context.POs.Add(existingPo);

        var existingInvoice = new Invoice
        {
            Id = Guid.NewGuid(),
            PackageId = existingPackage.Id,
            POId = existingPo.Id,
            InvoiceNumber = invoiceNumber,
            FileName = "inv.pdf",
            BlobUrl = "https://blob/inv.pdf",
            ContentType = "application/pdf"
        };
        _context.Invoices.Add(existingInvoice);

        // Current draft submission with its own PO (same PO number)
        var currentPackageId = Guid.NewGuid();
        var currentPo = new PO
        {
            Id = Guid.NewGuid(),
            PackageId = currentPackageId,
            PONumber = poNumber,
            FileName = "po2.pdf",
            BlobUrl = "https://blob/po2.pdf",
            ContentType = "application/pdf"
        };

        var currentPackage = new DocumentPackage
        {
            Id = currentPackageId,
            AgencyId = _agencyId,
            SubmittedByUserId = _userId,
            State = PackageState.Draft,
            SelectedPOId = currentPo.Id,
            CurrentStep = (int)ConversationStep.InvoiceUpload,
            VersionNumber = 1
        };
        _context.DocumentPackages.Add(currentPackage);
        _context.POs.Add(currentPo);

        // New invoice uploaded for the current package (same invoice number)
        var newInvoice = new Invoice
        {
            Id = Guid.NewGuid(),
            PackageId = currentPackage.Id,
            POId = currentPo.Id,
            InvoiceNumber = invoiceNumber,
            FileName = "inv2.pdf",
            BlobUrl = "https://blob/inv2.pdf",
            ContentType = "application/pdf"
        };
        _context.Invoices.Add(newInvoice);

        await _context.SaveChangesAsync();
        return (existingPackage, currentPackage, newInvoice);
    }

    #endregion

    [Fact]
    public async Task InvoiceUpload_DuplicateFound_ReturnsWarningWithButtons()
    {
        // Arrange
        var (existing, current, invoice) = await SeedDuplicateScenarioAsync();
        var request = new ConversationRequest
        {
            SubmissionId = current.Id,
            Action = "upload_confirmed",
            PayloadJson = JsonSerializer.Serialize(new { documentId = invoice.Id.ToString() })
        };

        // Act
        var response = await _service.ProcessMessageAsync(request, _userId, _agencyId);

        // Assert
        Assert.Contains("already exists", response.BotMessage);
        Assert.Contains("INV-001", response.BotMessage);
        Assert.Equal(2, response.Buttons.Count);
        Assert.Equal("View existing", response.Buttons[0].Label);
        Assert.Equal("view_existing", response.Buttons[0].Action);
        Assert.Equal("Submit anyway (new version)", response.Buttons[1].Label);
        Assert.Equal("submit_anyway", response.Buttons[1].Action);
        Assert.False(response.RequiresFileUpload);
    }

    [Fact]
    public async Task InvoiceUpload_NoDuplicate_ProceedsNormally()
    {
        // Arrange — no other package with the same PO + invoice number
        var agency = new Agency { Id = _agencyId, SupplierCode = "V001", SupplierName = "Test Agency" };
        var user = new User { Id = _userId, Email = "test@test.com", FullName = "Test User", AgencyId = _agencyId };
        _context.Agencies.Add(agency);
        _context.Users.Add(user);

        var packageId = Guid.NewGuid();
        var po = new PO { Id = Guid.NewGuid(), PackageId = packageId, PONumber = "PO-100", FileName = "po.pdf", BlobUrl = "https://blob/po.pdf", ContentType = "application/pdf" };

        var currentPackage = new DocumentPackage
        {
            Id = packageId, AgencyId = _agencyId, SubmittedByUserId = _userId,
            State = PackageState.Draft, SelectedPOId = po.Id,
            CurrentStep = (int)ConversationStep.InvoiceUpload, VersionNumber = 1
        };
        _context.DocumentPackages.Add(currentPackage);
        _context.POs.Add(po);

        var invoice = new Invoice
        {
            Id = Guid.NewGuid(), PackageId = currentPackage.Id, POId = po.Id,
            InvoiceNumber = "INV-UNIQUE", FileName = "inv.pdf", BlobUrl = "https://blob/inv.pdf", ContentType = "application/pdf"
        };
        _context.Invoices.Add(invoice);
        await _context.SaveChangesAsync();

        var request = new ConversationRequest
        {
            SubmissionId = currentPackage.Id,
            Action = "upload_confirmed",
            PayloadJson = JsonSerializer.Serialize(new { documentId = invoice.Id.ToString() })
        };

        // Act
        var response = await _service.ProcessMessageAsync(request, _userId, _agencyId);

        // Assert — should proceed to validation, not show duplicate warning
        Assert.DoesNotContain("already exists", response.BotMessage);
        Assert.Equal((int)ConversationStep.ActivitySummaryUpload, response.CurrentStep);
    }

    [Fact]
    public async Task InvoiceUpload_RejectedDuplicate_IsIgnored()
    {
        // Arrange — existing submission is CHRejected, should not trigger duplicate warning
        var (_, current, invoice) = await SeedDuplicateScenarioAsync(existingState: PackageState.CHRejected);
        var request = new ConversationRequest
        {
            SubmissionId = current.Id,
            Action = "upload_confirmed",
            PayloadJson = JsonSerializer.Serialize(new { documentId = invoice.Id.ToString() })
        };

        // Act
        var response = await _service.ProcessMessageAsync(request, _userId, _agencyId);

        // Assert — rejected submissions should be excluded from duplicate check
        Assert.DoesNotContain("already exists", response.BotMessage);
        Assert.Equal((int)ConversationStep.ActivitySummaryUpload, response.CurrentStep);
    }

    [Fact]
    public async Task SubmitAnyway_IncrementsVersionAndProceeds()
    {
        // Arrange
        var (existing, current, invoice) = await SeedDuplicateScenarioAsync();
        var request = new ConversationRequest
        {
            SubmissionId = current.Id,
            Action = "submit_anyway"
        };

        // Act
        var response = await _service.ProcessMessageAsync(request, _userId, _agencyId);

        // Assert — version should be incremented and flow should proceed
        var updated = await _context.DocumentPackages.FindAsync(current.Id);
        Assert.True(updated!.VersionNumber > 1);
        Assert.Equal((int)ConversationStep.ActivitySummaryUpload, response.CurrentStep);
    }

    [Fact]
    public async Task ViewExisting_ReturnsExistingSubmissionSummary()
    {
        // Arrange
        var (existing, current, _) = await SeedDuplicateScenarioAsync();
        var request = new ConversationRequest
        {
            SubmissionId = current.Id,
            Action = "view_existing",
            PayloadJson = JsonSerializer.Serialize(new { submissionId = existing.Id.ToString() })
        };

        // Act
        var response = await _service.ProcessMessageAsync(request, _userId, _agencyId);

        // Assert
        Assert.Contains("CIQ-2026-00001", response.BotMessage);
        Assert.Contains("PO-2026-001", response.BotMessage);
        Assert.Contains("INV-001", response.BotMessage);
        Assert.Contains("Submit anyway (new version)", response.Buttons.Select(b => b.Label));
    }
}
