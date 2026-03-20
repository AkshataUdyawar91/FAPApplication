using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
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
/// Tests for WorkflowOrchestrator state transitions.
/// Verifies the complete submission flow: Uploaded → Extracting → Validating → PendingCH.
/// Also verifies that workflow failures are handled gracefully.
/// </summary>
public class WorkflowOrchestratorTests : IDisposable
{
    private readonly ApplicationDbContext _context;
    private readonly Mock<IDocumentAgent> _mockDocumentAgent;
    private readonly Mock<IValidationAgent> _mockValidationAgent;
    private readonly Mock<IConfidenceScoreService> _mockConfidenceScoreService;
    private readonly Mock<IRecommendationAgent> _mockRecommendationAgent;
    private readonly Mock<INotificationAgent> _mockNotificationAgent;
    private readonly Mock<INotificationDispatcher> _mockNotificationDispatcher;
    private readonly Mock<IEmailAgent> _mockEmailAgent;
    private readonly Mock<ISubmissionNotificationService> _mockSubmissionNotificationService;
    private readonly Mock<IFileStorageService> _mockFileStorageService;
    private readonly Mock<ILogger<WorkflowOrchestrator>> _mockLogger;
    private readonly Mock<ICorrelationIdService> _mockCorrelationIdService;
    private readonly Mock<ICircleHeadAssignmentService> _mockCircleHeadAssignmentService;
    private readonly Mock<ISubmissionNumberService> _mockSubmissionNumberService;
    private readonly WorkflowOrchestrator _orchestrator;

    public WorkflowOrchestratorTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options);

        _mockDocumentAgent = new Mock<IDocumentAgent>();
        _mockValidationAgent = new Mock<IValidationAgent>();
        _mockConfidenceScoreService = new Mock<IConfidenceScoreService>();
        _mockRecommendationAgent = new Mock<IRecommendationAgent>();
        _mockNotificationAgent = new Mock<INotificationAgent>();
        _mockNotificationDispatcher = new Mock<INotificationDispatcher>();
        _mockEmailAgent = new Mock<IEmailAgent>();
        _mockSubmissionNotificationService = new Mock<ISubmissionNotificationService>();
        _mockFileStorageService = new Mock<IFileStorageService>();
        _mockLogger = new Mock<ILogger<WorkflowOrchestrator>>();
        _mockCorrelationIdService = new Mock<ICorrelationIdService>();
        _mockCircleHeadAssignmentService = new Mock<ICircleHeadAssignmentService>();
        _mockSubmissionNumberService = new Mock<ISubmissionNumberService>();

        _mockCorrelationIdService.Setup(c => c.GetCorrelationId()).Returns("test-correlation-id");
        // Default: all blobs are accessible in tests
        _mockFileStorageService.Setup(f => f.IsBlobAccessibleAsync(It.IsAny<string>())).ReturnsAsync(true);
        _mockSubmissionNumberService.Setup(s => s.GenerateAsync(It.IsAny<CancellationToken>())).ReturnsAsync("CIQ-2026-99999");

        _orchestrator = new WorkflowOrchestrator(
            _context,
            _mockDocumentAgent.Object,
            _mockValidationAgent.Object,
            _mockConfidenceScoreService.Object,
            _mockRecommendationAgent.Object,
            _mockNotificationAgent.Object,
            _mockNotificationDispatcher.Object,
            _mockEmailAgent.Object,
            _mockSubmissionNotificationService.Object,
            _mockFileStorageService.Object,
            _mockLogger.Object,
            _mockCorrelationIdService.Object,
            _mockCircleHeadAssignmentService.Object,
            _mockSubmissionNumberService.Object);
    }

    public void Dispose()
    {
        _context.Dispose();
    }

    #region Helper Methods

    /// <summary>
    /// Seeds a test package with a PO document in Uploaded state
    /// </summary>
    private async Task<DocumentPackage> SeedUploadedPackageAsync()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            FullName = "Test Agency",
            Email = "test@agency.com",
            PasswordHash = "hash",
            Role = UserRole.Agency,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.Users.Add(user);

        var package = new DocumentPackage
        {
            Id = Guid.NewGuid(),
            SubmittedByUserId = user.Id,
            State = PackageState.Uploaded,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.DocumentPackages.Add(package);

        var po = new PO
        {
            Id = Guid.NewGuid(),
            PackageId = package.Id,
            FileName = "test-po.pdf",
            BlobUrl = "https://storage/test-po.pdf",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _context.POs.Add(po);

        await _context.SaveChangesAsync();
        return package;
    }

    /// <summary>
    /// Sets up all agents to succeed (happy path)
    /// </summary>
    private void SetupAllAgentsSucceed()
    {
        _mockDocumentAgent.Setup(d => d.ExtractPOAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new POData { PONumber = "PO001", TotalAmount = 50000 });

        var validationResult = new PackageValidationResult { AllPassed = true };
        _mockValidationAgent.Setup(v => v.ValidatePackageAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(validationResult);

        _mockConfidenceScoreService.Setup(s => s.CalculateConfidenceScoreAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ConfidenceScore
            {
                Id = Guid.NewGuid(),
                OverallConfidence = 85.0,
                PoConfidence = 90.0,
                InvoiceConfidence = 80.0,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });

        _mockRecommendationAgent.Setup(r => r.GenerateRecommendationAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Recommendation
            {
                Id = Guid.NewGuid(),
                Type = RecommendationType.Approve,
                Evidence = "All validations passed",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });

        _mockNotificationAgent.Setup(n => n.NotifySubmissionReceivedAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
    }

    #endregion

    #region Happy Path Tests

    /// <summary>
    /// A successful workflow must end at PendingCH.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_HappyPath_EndsAtPendingCH()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();
        SetupAllAgentsSucceed();

        // Act
        var result = await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        Assert.True(result, "Workflow should succeed");
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.Equal(PackageState.PendingCH, updated!.State);
    }

    /// <summary>
    /// A new submission must NEVER end at CHRejected on the happy path.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_HappyPath_NeverSetsCHRejected()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();
        SetupAllAgentsSucceed();

        // Act
        await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.NotEqual(PackageState.CHRejected, updated!.State);
    }

    #endregion

    #region Failure / Compensation Tests

    /// <summary>
    /// When extraction fails, the package should not end at PendingCH or Approved.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_ExtractionFails_DoesNotReachPendingCH()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();

        _mockDocumentAgent.Setup(d => d.ExtractPOAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Azure OpenAI unavailable"));

        _mockNotificationAgent.Setup(n => n.NotifyRejectedAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        Assert.False(result, "Workflow should fail");
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.NotEqual(PackageState.PendingCH, updated!.State);
        Assert.NotEqual(PackageState.Approved, updated.State);
    }

    /// <summary>
    /// When validation fails, the package should not reach PendingCH.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_ValidationFails_DoesNotReachPendingCH()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();

        _mockDocumentAgent.Setup(d => d.ExtractPOAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new POData { PONumber = "PO001" });

        _mockValidationAgent.Setup(v => v.ValidatePackageAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Validation service error"));

        _mockNotificationAgent.Setup(n => n.NotifyRejectedAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        Assert.False(result);
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.NotEqual(PackageState.PendingCH, updated!.State);
    }

    /// <summary>
    /// When scoring fails, the package should not reach PendingCH.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_ScoringFails_DoesNotReachPendingCH()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();

        _mockDocumentAgent.Setup(d => d.ExtractPOAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new POData { PONumber = "PO001" });

        var validationResult = new PackageValidationResult { AllPassed = true };
        _mockValidationAgent.Setup(v => v.ValidatePackageAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(validationResult);

        _mockConfidenceScoreService.Setup(s => s.CalculateConfidenceScoreAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Scoring service error"));

        _mockNotificationAgent.Setup(n => n.NotifyRejectedAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        Assert.False(result);
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.NotEqual(PackageState.PendingCH, updated!.State);
    }

    /// <summary>
    /// When recommendation fails, the package should not reach PendingCH.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_RecommendationFails_DoesNotReachPendingCH()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();

        _mockDocumentAgent.Setup(d => d.ExtractPOAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new POData { PONumber = "PO001" });

        var validationResult = new PackageValidationResult { AllPassed = true };
        _mockValidationAgent.Setup(v => v.ValidatePackageAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(validationResult);

        _mockConfidenceScoreService.Setup(s => s.CalculateConfidenceScoreAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new ConfidenceScore { Id = Guid.NewGuid(), OverallConfidence = 85.0, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow });

        _mockRecommendationAgent.Setup(r => r.GenerateRecommendationAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new Exception("Recommendation service error"));

        _mockNotificationAgent.Setup(n => n.NotifyRejectedAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        Assert.False(result);
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.NotEqual(PackageState.PendingCH, updated!.State);
    }

    #endregion

    #region Idempotency Tests

    /// <summary>
    /// Packages already in PendingCH must not be reprocessed.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_AlreadyPendingCH_SkipsProcessing()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();
        package.State = PackageState.PendingCH;
        await _context.SaveChangesAsync();

        // Act
        var result = await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        Assert.True(result);
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.Equal(PackageState.PendingCH, updated!.State);
        _mockDocumentAgent.Verify(d => d.ExtractPOAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    /// <summary>
    /// Packages in CHRejected state must not be reprocessed by the orchestrator.
    /// </summary>
    [Fact]
    public async Task ProcessSubmission_CHRejected_SkipsProcessing()
    {
        // Arrange
        var package = await SeedUploadedPackageAsync();
        package.State = PackageState.CHRejected;
        await _context.SaveChangesAsync();

        // Act
        var result = await _orchestrator.ProcessSubmissionAsync(package.Id);

        // Assert
        Assert.True(result);
        var updated = await _context.DocumentPackages.FindAsync(package.Id);
        Assert.Equal(PackageState.CHRejected, updated!.State);
        _mockDocumentAgent.Verify(d => d.ExtractPOAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    #endregion

    #region PackageState Enum Tests

    /// <summary>
    /// PendingCH and CHRejected must be distinct values.
    /// </summary>
    [Fact]
    public void PackageState_PendingCH_IsDifferentFromCHRejected()
    {
        Assert.NotEqual((int)PackageState.PendingCH, (int)PackageState.CHRejected);
    }

    /// <summary>
    /// All PackageState values must be unique.
    /// </summary>
    [Fact]
    public void PackageState_AllValues_AreUnique()
    {
        var values = Enum.GetValues<PackageState>().Select(v => (int)v).ToList();
        Assert.Equal(values.Count, values.Distinct().Count());
    }

    #endregion
}
