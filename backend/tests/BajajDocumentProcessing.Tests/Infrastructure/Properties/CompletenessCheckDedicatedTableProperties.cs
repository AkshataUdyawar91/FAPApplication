using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Feature: remove-legacy-documents-table, Property 4: Completeness check from dedicated tables
/// 
/// Property: For any combination of present/missing dedicated document entities (PO, Invoice,
/// CostSummary, TeamPhotos) on a DocumentPackage, the completeness validation SHALL report
/// exactly the set of missing document types — a type is reported missing if and only if its
/// dedicated entity is null (for one-to-one) or empty (for one-to-many).
/// 
/// **Validates: Requirements 3.4, 5.7**
/// </summary>
public class CompletenessCheckDedicatedTableProperties
{
    /// <summary>
    /// Property 4: For any combination of present/missing document types, the completeness
    /// check reports exactly the missing types and IsComplete iff nothing is missing.
    /// </summary>
    [Property(MaxTest = 10)]
    public Property CompletenessCheck_ReportsExactlyMissingTypes(
        bool hasPO, bool hasInvoice, bool hasCostSummary, bool hasPhotos)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange
                var (agent, _) = CreateValidationAgent(packageId, hasPO, hasInvoice, hasCostSummary, hasPhotos);

                // Act
                var result = agent.ValidateCompletenessAsync(packageId, CancellationToken.None)
                    .GetAwaiter().GetResult();

                // Assert — IsComplete iff all present
                var allPresent = hasPO && hasInvoice && hasCostSummary && hasPhotos;
                var isCompleteCorrect = result.IsComplete == allPresent;

                // Assert — missing items match exactly
                var poMissingCorrect = !hasPO == result.MissingItems.Contains("PO");
                var invoiceMissingCorrect = !hasInvoice == result.MissingItems.Contains("Invoice");
                var csMissingCorrect = !hasCostSummary == result.MissingItems.Contains("CostSummary");
                var photosMissingCorrect = !hasPhotos == result.MissingItems.Any(m => m.Contains("Photos"));

                return (isCompleteCorrect && poMissingCorrect && invoiceMissingCorrect &&
                        csMissingCorrect && photosMissingCorrect)
                    .ToProperty()
                    .Label($"PO={hasPO}, Invoice={hasInvoice}, CS={hasCostSummary}, Photos={hasPhotos}, " +
                           $"IsComplete={result.IsComplete} (expected {allPresent}), " +
                           $"Missing=[{string.Join(", ", result.MissingItems)}]");
            });
    }

    /// <summary>
    /// Property 4b: PresentItemCount equals the number of present document types.
    /// </summary>
    [Property(MaxTest = 10)]
    public Property CompletenessCheck_PresentItemCount_MatchesActualPresent(
        bool hasPO, bool hasInvoice, bool hasCostSummary, bool hasPhotos)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                var (agent, _) = CreateValidationAgent(packageId, hasPO, hasInvoice, hasCostSummary, hasPhotos);
                var result = agent.ValidateCompletenessAsync(packageId, CancellationToken.None)
                    .GetAwaiter().GetResult();

                var expectedCount = (hasPO ? 1 : 0) + (hasInvoice ? 1 : 0) +
                                    (hasCostSummary ? 1 : 0) + (hasPhotos ? 1 : 0);

                return (result.PresentItemCount == expectedCount)
                    .ToProperty()
                    .Label($"Expected {expectedCount} present items, got {result.PresentItemCount}");
            });
    }

    /// <summary>
    /// Unit test: All documents present → IsComplete = true, no missing items.
    /// </summary>
    [Fact]
    public async Task CompletenessCheck_AllPresent_IsComplete()
    {
        var packageId = Guid.NewGuid();
        var (agent, _) = CreateValidationAgent(packageId, true, true, true, true);

        var result = await agent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        Assert.True(result.IsComplete);
        Assert.Empty(result.MissingItems);
        Assert.Equal(4, result.PresentItemCount);
    }

    /// <summary>
    /// Unit test: No documents present → IsComplete = false, all types missing.
    /// </summary>
    [Fact]
    public async Task CompletenessCheck_NonePresent_AllMissing()
    {
        var packageId = Guid.NewGuid();
        var (agent, _) = CreateValidationAgent(packageId, false, false, false, false);

        var result = await agent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        Assert.False(result.IsComplete);
        Assert.Equal(0, result.PresentItemCount);
        Assert.Contains("PO", result.MissingItems);
        Assert.Contains("Invoice", result.MissingItems);
        Assert.Contains("CostSummary", result.MissingItems);
        Assert.Contains(result.MissingItems, m => m.Contains("Photos"));
    }

    private static (IValidationAgent agent, Mock<IApplicationDbContext> mockContext) CreateValidationAgent(
        Guid packageId, bool hasPO, bool hasInvoice, bool hasCostSummary, bool hasPhotos)
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        var mockPerceptualHashService = new Mock<IPerceptualHashService>();

        var package = new DocumentPackage
        {
            Id = packageId,
            State = PackageState.Uploaded,
            CreatedAt = DateTime.UtcNow,
            Invoices = new List<Invoice>(),
            Teams = new List<Teams>()
        };

        if (hasPO)
        {
            package.PO = new PO
            {
                Id = Guid.NewGuid(), PackageId = packageId,
                FileName = "PO.pdf", CreatedAt = DateTime.UtcNow
            };
        }

        if (hasInvoice)
        {
            package.Invoices.Add(new Invoice
            {
                Id = Guid.NewGuid(), PackageId = packageId,
                FileName = "Invoice.pdf", CreatedAt = DateTime.UtcNow
            });
        }

        if (hasCostSummary)
        {
            package.CostSummary = new CostSummary
            {
                Id = Guid.NewGuid(), PackageId = packageId,
                FileName = "CostSummary.xlsx", CreatedAt = DateTime.UtcNow
            };
        }

        if (hasPhotos)
        {
            var team = new Teams
            {
                Id = Guid.NewGuid(), PackageId = packageId,
                CampaignName = "Test", Photos = new List<TeamPhotos>()
            };
            team.Photos.Add(new TeamPhotos
            {
                Id = Guid.NewGuid(), TeamId = team.Id, PackageId = packageId,
                FileName = "Photo1.jpg", CreatedAt = DateTime.UtcNow
            });
            package.Teams.Add(team);
        }
        else
        {
            // Add a team with no photos to ensure Teams collection is initialized
            var emptyTeam = new Teams
            {
                Id = Guid.NewGuid(), PackageId = packageId,
                CampaignName = "Empty", Photos = new List<TeamPhotos>()
            };
            package.Teams.Add(emptyTeam);
        }

        var packages = new List<DocumentPackage> { package };
        var mockDbSet = CreateMockDbSet(packages);
        mockContext.Setup(c => c.DocumentPackages).Returns(mockDbSet.Object);

        var agent = new ValidationAgent(
            mockContext.Object, mockLogger.Object, mockHttpClientFactory.Object,
            mockReferenceDataService.Object, mockCorrelationIdService.Object, mockPerceptualHashService.Object);

        return (agent, mockContext);
    }

    private static Mock<DbSet<DocumentPackage>> CreateMockDbSet(List<DocumentPackage> data)
    {
        var queryable = data.AsQueryable();
        var mockSet = new Mock<DbSet<DocumentPackage>>();

        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.Provider)
            .Returns(new TestAsyncQueryProvider<DocumentPackage>(queryable.Provider));
        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.Expression).Returns(queryable.Expression);
        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.ElementType).Returns(queryable.ElementType);
        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.GetEnumerator()).Returns(queryable.GetEnumerator());
        mockSet.As<IAsyncEnumerable<DocumentPackage>>()
            .Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns(new TestAsyncEnumerator<DocumentPackage>(queryable.GetEnumerator()));

        return mockSet;
    }
}
