using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Edge-case unit tests for dedicated table migration.
/// Validates: Requirements 1.7, 1.10, 2.7
/// </summary>
public class DedicatedTableEdgeCaseTests
{
    /// <summary>
    /// Confidence score with missing PO → PO contributes 0.0 to weighted sum.
    /// </summary>
    [Fact]
    public void ConfidenceScore_MissingPO_ContributesZero()
    {
        var service = CreateConfidenceScoreService();
        // PO=0, Invoice=80, CostSummary=90, Activity=70, Photos=60
        var result = service.CalculateWeightedScore(0, 80, 90, 70, 60);

        var expected = (0 * 0.30) + (80 * 0.30) + (90 * 0.20) + (70 * 0.10) + (60 * 0.10);
        Assert.Equal(expected, result, 2);
    }

    /// <summary>
    /// Confidence score with missing Invoice → Invoice contributes 0.0.
    /// </summary>
    [Fact]
    public void ConfidenceScore_MissingInvoice_ContributesZero()
    {
        var service = CreateConfidenceScoreService();
        var result = service.CalculateWeightedScore(80, 0, 90, 70, 60);

        var expected = (80 * 0.30) + (0 * 0.30) + (90 * 0.20) + (70 * 0.10) + (60 * 0.10);
        Assert.Equal(expected, result, 2);
    }

    /// <summary>
    /// Confidence score with all documents missing → overall = 0.
    /// </summary>
    [Fact]
    public void ConfidenceScore_AllMissing_ReturnsZero()
    {
        var service = CreateConfidenceScoreService();
        var result = service.CalculateWeightedScore(0, 0, 0, 0, 0);
        Assert.Equal(0.0, result, 2);
    }

    /// <summary>
    /// Confidence score with boundary value 100 for all → overall = 100.
    /// </summary>
    [Fact]
    public void ConfidenceScore_AllAt100_Returns100()
    {
        var service = CreateConfidenceScoreService();
        var result = service.CalculateWeightedScore(100, 100, 100, 100, 100);
        Assert.Equal(100.0, result, 2);
    }

    /// <summary>
    /// Completeness check: package not found returns failure with descriptive message.
    /// </summary>
    [Fact]
    public async Task CompletenessCheck_PackageNotFound_ReturnsFailure()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var packages = new List<DocumentPackage>();
        var mockDbSet = CreateMockDbSet(packages);
        mockContext.Setup(c => c.DocumentPackages).Returns(mockDbSet.Object);

        var agent = CreateValidationAgent(mockContext);
        var result = await agent.ValidateCompletenessAsync(Guid.NewGuid(), CancellationToken.None);

        Assert.False(result.IsComplete);
        Assert.Contains("Package not found", result.MissingItems);
    }

    /// <summary>
    /// Completeness check: photo count at exactly 0 → reports photos missing.
    /// </summary>
    [Fact]
    public async Task CompletenessCheck_ZeroPhotos_ReportsMissing()
    {
        var packageId = Guid.NewGuid();
        var package = CreatePackage(packageId, hasPO: true, hasInvoice: true, hasCostSummary: true, photoCount: 0);
        var mockContext = SetupContext(package);

        var agent = CreateValidationAgent(mockContext);
        var result = await agent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        Assert.False(result.IsComplete);
        Assert.Contains(result.MissingItems, m => m.Contains("Photos"));
    }

    /// <summary>
    /// Completeness check: exactly 1 photo → passes photo requirement.
    /// </summary>
    [Fact]
    public async Task CompletenessCheck_ExactlyOnePhoto_Passes()
    {
        var packageId = Guid.NewGuid();
        var package = CreatePackage(packageId, hasPO: true, hasInvoice: true, hasCostSummary: true, photoCount: 1);
        var mockContext = SetupContext(package);

        var agent = CreateValidationAgent(mockContext);
        var result = await agent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        Assert.True(result.IsComplete);
        Assert.Empty(result.MissingItems);
    }

    private static ConfidenceScoreService CreateConfidenceScoreService()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ConfidenceScoreService>>();
        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        return new ConfidenceScoreService(mockContext.Object, mockLogger.Object, mockCorrelationIdService.Object);
    }

    private static ValidationAgent CreateValidationAgent(Mock<IApplicationDbContext> mockContext)
    {
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        var mockPerceptualHashService = new Mock<IPerceptualHashService>();
        return new ValidationAgent(
            mockContext.Object, mockLogger.Object, mockHttpClientFactory.Object,
            mockReferenceDataService.Object, mockCorrelationIdService.Object, mockPerceptualHashService.Object);
    }

    private static DocumentPackage CreatePackage(Guid packageId, bool hasPO, bool hasInvoice, bool hasCostSummary, int photoCount)
    {
        var package = new DocumentPackage
        {
            Id = packageId,
            State = PackageState.Uploaded,
            CreatedAt = DateTime.UtcNow,
            Invoices = new List<Invoice>(),
            Teams = new List<Teams>()
        };

        if (hasPO)
            package.PO = new PO { Id = Guid.NewGuid(), PackageId = packageId, FileName = "PO.pdf", CreatedAt = DateTime.UtcNow };

        if (hasInvoice)
            package.Invoices.Add(new Invoice { Id = Guid.NewGuid(), PackageId = packageId, FileName = "Invoice.pdf", CreatedAt = DateTime.UtcNow });

        if (hasCostSummary)
            package.CostSummary = new CostSummary { Id = Guid.NewGuid(), PackageId = packageId, FileName = "CS.xlsx", CreatedAt = DateTime.UtcNow };

        var team = new Teams
        {
            Id = Guid.NewGuid(), PackageId = packageId, CampaignName = "Test",
            Photos = new List<TeamPhotos>()
        };
        for (int i = 0; i < photoCount; i++)
        {
            team.Photos.Add(new TeamPhotos
            {
                Id = Guid.NewGuid(), TeamId = team.Id, PackageId = packageId,
                FileName = $"Photo{i + 1}.jpg", CreatedAt = DateTime.UtcNow
            });
        }
        package.Teams.Add(team);

        return package;
    }

    private static Mock<IApplicationDbContext> SetupContext(DocumentPackage package)
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var packages = new List<DocumentPackage> { package };
        var mockDbSet = CreateMockDbSet(packages);
        mockContext.Setup(c => c.DocumentPackages).Returns(mockDbSet.Object);
        return mockContext;
    }

    private static Mock<DbSet<DocumentPackage>> CreateMockDbSet(List<DocumentPackage> data)
    {
        var queryable = data.AsQueryable();
        var mockSet = new Mock<DbSet<DocumentPackage>>();

        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.Provider)
            .Returns(new Properties.TestAsyncQueryProvider<DocumentPackage>(queryable.Provider));
        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.Expression).Returns(queryable.Expression);
        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.ElementType).Returns(queryable.ElementType);
        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.GetEnumerator()).Returns(queryable.GetEnumerator());
        mockSet.As<IAsyncEnumerable<DocumentPackage>>()
            .Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns(new Properties.TestAsyncEnumerator<DocumentPackage>(queryable.GetEnumerator()));

        return mockSet;
    }
}
