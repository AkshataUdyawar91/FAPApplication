using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Query;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 13: Completeness Validation
/// Validates: Requirements 3.4
/// 
/// Property: For any Document Package, the completeness validation should pass if and only if 
/// all required documents are present (PO, Invoice, Cost Summary, and at least 1 photo).
/// </summary>
public class CompletenessValidationProperties
{
    private readonly IValidationAgent _validationAgent;
    private readonly Mock<IApplicationDbContext> _mockContext;

    public CompletenessValidationProperties()
    {
        _mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var mockCorrelationIdService = new Mock<ICorrelationIdService>();

        _validationAgent = new ValidationAgent(
            _mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object,
            mockCorrelationIdService.Object);
    }

    /// <summary>
    /// Property: When all required documents are present, validation should pass
    /// </summary>
    [Property(MaxTest = 100)]
    public Property CompletenessValidation_WhenAllRequiredDocumentsPresent_ShouldPass(PositiveInt photoCount)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange
                var package = CreatePackageWithDocuments(packageId, true, true, true, Math.Max(1, photoCount.Get % 20));
                SetupMockContext(package);

                // Act
                var result = _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None).Result;

                // Assert
                return result.IsComplete.ToProperty()
                    .Label($"Validation should pass when all required documents are present (photos: {Math.Max(1, photoCount.Get % 20)})");
            });
    }

    /// <summary>
    /// Property: When PO is missing, validation should fail
    /// </summary>
    [Property(MaxTest = 100)]
    public Property CompletenessValidation_WhenPOMissing_ShouldFail(PositiveInt photoCount)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange
                var package = CreatePackageWithDocuments(packageId, false, true, true, Math.Max(1, photoCount.Get % 20));
                SetupMockContext(package);

                // Act
                var result = _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None).Result;

                // Assert
                return (!result.IsComplete && result.MissingItems.Contains("PO")).ToProperty()
                    .Label("Validation should fail when PO is missing");
            });
    }

    /// <summary>
    /// Property: When Invoice is missing, validation should fail
    /// </summary>
    [Property(MaxTest = 100)]
    public Property CompletenessValidation_WhenInvoiceMissing_ShouldFail(PositiveInt photoCount)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange
                var package = CreatePackageWithDocuments(packageId, true, false, true, Math.Max(1, photoCount.Get % 20));
                SetupMockContext(package);

                // Act
                var result = _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None).Result;

                // Assert
                return (!result.IsComplete && result.MissingItems.Contains("Invoice")).ToProperty()
                    .Label("Validation should fail when Invoice is missing");
            });
    }

    /// <summary>
    /// Property: When Cost Summary is missing, validation should fail
    /// </summary>
    [Property(MaxTest = 100)]
    public Property CompletenessValidation_WhenCostSummaryMissing_ShouldFail(PositiveInt photoCount)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange
                var package = CreatePackageWithDocuments(packageId, true, true, false, Math.Max(1, photoCount.Get % 20));
                SetupMockContext(package);

                // Act
                var result = _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None).Result;

                // Assert
                return (!result.IsComplete && result.MissingItems.Contains("CostSummary")).ToProperty()
                    .Label("Validation should fail when Cost Summary is missing");
            });
    }

    /// <summary>
    /// Property: When photos are missing, validation should fail
    /// </summary>
    [Property(MaxTest = 100)]
    public void CompletenessValidation_WhenPhotosMissing_ShouldFail()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var package = CreatePackageWithDocuments(packageId, true, true, true, 0);
        SetupMockContext(package);

        // Act
        var result = _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None).Result;

        // Assert
        Assert.False(result.IsComplete);
        Assert.Contains("Photos", result.MissingItems.FirstOrDefault() ?? "");
    }

    /// <summary>
    /// Unit test: All documents present should pass
    /// </summary>
    [Fact]
    public async Task CompletenessValidation_AllDocumentsPresent_ShouldPass()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var package = CreatePackageWithDocuments(packageId, true, true, true, 5);
        SetupMockContext(package);

        // Act
        var result = await _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        // Assert
        Assert.True(result.IsComplete);
        Assert.Empty(result.MissingItems);
        Assert.Equal(4, result.PresentItemCount);
    }

    /// <summary>
    /// Unit test: Missing PO should fail
    /// </summary>
    [Fact]
    public async Task CompletenessValidation_MissingPO_ShouldFail()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var package = CreatePackageWithDocuments(packageId, false, true, true, 5);
        SetupMockContext(package);

        // Act
        var result = await _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        // Assert
        Assert.False(result.IsComplete);
        Assert.Contains("PO", result.MissingItems);
    }

    /// <summary>
    /// Unit test: Missing Invoice should fail
    /// </summary>
    [Fact]
    public async Task CompletenessValidation_MissingInvoice_ShouldFail()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var package = CreatePackageWithDocuments(packageId, true, false, true, 5);
        SetupMockContext(package);

        // Act
        var result = await _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        // Assert
        Assert.False(result.IsComplete);
        Assert.Contains("Invoice", result.MissingItems);
    }

    /// <summary>
    /// Unit test: Missing Cost Summary should fail
    /// </summary>
    [Fact]
    public async Task CompletenessValidation_MissingCostSummary_ShouldFail()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var package = CreatePackageWithDocuments(packageId, true, true, false, 5);
        SetupMockContext(package);

        // Act
        var result = await _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        // Assert
        Assert.False(result.IsComplete);
        Assert.Contains("CostSummary", result.MissingItems);
    }

    /// <summary>
    /// Unit test: Missing photos should fail
    /// </summary>
    [Fact]
    public async Task CompletenessValidation_MissingPhotos_ShouldFail()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var package = CreatePackageWithDocuments(packageId, true, true, true, 0);
        SetupMockContext(package);

        // Act
        var result = await _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        // Assert
        Assert.False(result.IsComplete);
        Assert.Contains("Photos", result.MissingItems.FirstOrDefault() ?? "");
    }

    /// <summary>
    /// Unit test: Package not found should fail
    /// </summary>
    [Fact]
    public async Task CompletenessValidation_PackageNotFound_ShouldFail()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        SetupMockContext(null);

        // Act
        var result = await _validationAgent.ValidateCompletenessAsync(packageId, CancellationToken.None);

        // Assert
        Assert.False(result.IsComplete);
        Assert.Contains("Package not found", result.MissingItems);
    }

    private DocumentPackage CreatePackageWithDocuments(
        Guid packageId,
        bool includePO,
        bool includeInvoice,
        bool includeCostSummary,
        int photoCount)
    {
        var package = new DocumentPackage
        {
            Id = packageId,
            State = PackageState.Uploaded,
            CreatedAt = DateTime.UtcNow,
            Teams = new List<Teams>()
        };

        if (includePO)
        {
            package.PO = new PO
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                FileName = "PO.pdf",
                CreatedAt = DateTime.UtcNow
            };
        }

        if (includeInvoice)
        {
            package.Invoices = new List<Invoice>
            {
                new Invoice
                {
                    Id = Guid.NewGuid(),
                    PackageId = packageId,
                    FileName = "Invoice.pdf",
                    CreatedAt = DateTime.UtcNow
                }
            };
        }

        if (includeCostSummary)
        {
            package.CostSummary = new CostSummary
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                FileName = "CostSummary.pdf",
                CreatedAt = DateTime.UtcNow
            };
        }

        if (photoCount > 0)
        {
            var team = new Teams
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                CampaignName = "Test Team",
                Photos = new List<TeamPhotos>()
            };
            for (int i = 0; i < photoCount; i++)
            {
                team.Photos.Add(new TeamPhotos
                {
                    Id = Guid.NewGuid(),
                    TeamId = team.Id,
                    PackageId = packageId,
                    FileName = $"Photo{i + 1}.jpg",
                    CreatedAt = DateTime.UtcNow
                });
            }
            package.Teams.Add(team);
        }

        return package;
    }

    private void SetupMockContext(DocumentPackage? package)
    {
        var packages = package != null ? new List<DocumentPackage> { package } : new List<DocumentPackage>();
        var mockDbSet = CreateMockDbSet(packages);

        _mockContext.Setup(c => c.DocumentPackages).Returns(mockDbSet.Object);
    }

    private Mock<DbSet<DocumentPackage>> CreateMockDbSet(List<DocumentPackage> data)
    {
        var queryable = data.AsQueryable();
        var mockSet = new Mock<DbSet<DocumentPackage>>();

        mockSet.As<IQueryable<DocumentPackage>>().Setup(m => m.Provider).Returns(queryable.Provider);
        mockSet.As<IQueryable<DocumentPackage>>().Setup(m => m.Expression).Returns(queryable.Expression);
        mockSet.As<IQueryable<DocumentPackage>>().Setup(m => m.ElementType).Returns(queryable.ElementType);
        mockSet.As<IQueryable<DocumentPackage>>().Setup(m => m.GetEnumerator()).Returns(queryable.GetEnumerator());

        // Setup async operations
        mockSet.As<IAsyncEnumerable<DocumentPackage>>()
            .Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns(new TestAsyncEnumerator<DocumentPackage>(queryable.GetEnumerator()));

        mockSet.As<IQueryable<DocumentPackage>>()
            .Setup(m => m.Provider)
            .Returns(new TestAsyncQueryProvider<DocumentPackage>(queryable.Provider));

        return mockSet;
    }
}

// Helper classes for async EF Core mocking
internal class TestAsyncQueryProvider<TEntity> : IAsyncQueryProvider
{
    private readonly IQueryProvider _inner;

    internal TestAsyncQueryProvider(IQueryProvider inner)
    {
        _inner = inner;
    }

    public IQueryable CreateQuery(System.Linq.Expressions.Expression expression)
    {
        return new TestAsyncEnumerable<TEntity>(expression);
    }

    public IQueryable<TElement> CreateQuery<TElement>(System.Linq.Expressions.Expression expression)
    {
        return new TestAsyncEnumerable<TElement>(expression);
    }

    public object Execute(System.Linq.Expressions.Expression expression)
    {
        return _inner.Execute(expression)!;
    }

    public TResult Execute<TResult>(System.Linq.Expressions.Expression expression)
    {
        return _inner.Execute<TResult>(expression);
    }

    public TResult ExecuteAsync<TResult>(System.Linq.Expressions.Expression expression, CancellationToken cancellationToken = default)
    {
        var resultType = typeof(TResult).GetGenericArguments()[0];
        var executeMethod = typeof(TestAsyncQueryProvider<TEntity>)
            .GetMethod(nameof(ExecuteAsyncInternal), System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)!
            .MakeGenericMethod(resultType);
        return (TResult)executeMethod.Invoke(this, new object[] { expression, cancellationToken })!;
    }

    private async Task<TResult> ExecuteAsyncInternal<TResult>(System.Linq.Expressions.Expression expression, CancellationToken cancellationToken)
    {
        var result = _inner.Execute<TResult>(expression);
        return await Task.FromResult(result);
    }
}

internal class TestAsyncEnumerable<T> : EnumerableQuery<T>, IAsyncEnumerable<T>, IQueryable<T>
{
    public TestAsyncEnumerable(System.Linq.Expressions.Expression expression)
        : base(expression)
    {
    }

    public IAsyncEnumerator<T> GetAsyncEnumerator(CancellationToken cancellationToken = default)
    {
        return new TestAsyncEnumerator<T>(this.AsEnumerable().GetEnumerator());
    }

    IQueryProvider IQueryable.Provider => new TestAsyncQueryProvider<T>(this);
}

internal class TestAsyncEnumerator<T> : IAsyncEnumerator<T>
{
    private readonly IEnumerator<T> _inner;

    public TestAsyncEnumerator(IEnumerator<T> inner)
    {
        _inner = inner;
    }

    public T Current => _inner.Current;

    public ValueTask<bool> MoveNextAsync()
    {
        return new ValueTask<bool>(_inner.MoveNext());
    }

    public ValueTask DisposeAsync()
    {
        _inner.Dispose();
        return new ValueTask();
    }
}
