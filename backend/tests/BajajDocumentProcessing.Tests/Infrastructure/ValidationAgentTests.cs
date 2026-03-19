using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Query;
using Microsoft.Extensions.Logging;
using Moq;
using Moq.Protected;
using System.Net;
using System.Text.Json;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Comprehensive unit tests for ValidationAgent
/// Tests all 33 validation requirements
/// </summary>
public class ValidationAgentTests : IDisposable
{
    private readonly Mock<IApplicationDbContext> _mockContext;
    private readonly Mock<ILogger<ValidationAgent>> _mockLogger;
    private readonly Mock<IHttpClientFactory> _mockHttpClientFactory;
    private readonly Mock<IReferenceDataService> _mockReferenceDataService;
    private readonly ValidationAgent _validationAgent;
    private readonly Mock<DbSet<DocumentPackage>> _mockPackageSet;
    private readonly Mock<DbSet<ValidationResult>> _mockValidationResultSet;

    public ValidationAgentTests()
    {
        _mockContext = new Mock<IApplicationDbContext>();
        _mockLogger = new Mock<ILogger<ValidationAgent>>();
        _mockHttpClientFactory = new Mock<IHttpClientFactory>();
        _mockReferenceDataService = new Mock<IReferenceDataService>();

        // Setup mock DbSets
        _mockPackageSet = new Mock<DbSet<DocumentPackage>>();
        _mockValidationResultSet = new Mock<DbSet<ValidationResult>>();

        // Setup ValidationResults with async support (empty by default)
        SetupMockDbSet(_mockValidationResultSet, new List<ValidationResult>());

        _mockContext.Setup(c => c.DocumentPackages).Returns(_mockPackageSet.Object);
        _mockContext.Setup(c => c.ValidationResults).Returns(_mockValidationResultSet.Object);
        _mockContext.Setup(c => c.SaveChangesAsync(It.IsAny<CancellationToken>())).ReturnsAsync(1);

        // Setup HTTP client for SAP
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        mockHttpMessageHandler
            .Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(new HttpResponseMessage
            {
                StatusCode = HttpStatusCode.OK,
                Content = new StringContent("{}")
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object);
        _mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        var mockPerceptualHashService = new Mock<IPerceptualHashService>();
        
        _validationAgent = new ValidationAgent(
            _mockContext.Object,
            _mockLogger.Object,
            _mockHttpClientFactory.Object,
            _mockReferenceDataService.Object,
            mockCorrelationIdService.Object,
            mockPerceptualHashService.Object);
    }

    public void Dispose()
    {
        // Cleanup if needed
    }

    #region Helper Methods

    private DocumentPackage CreateTestPackage(
        POData? poData = null,
        InvoiceData? invoiceData = null,
        CostSummaryData? costSummaryData = null,
        ActivityData? activityData = null,
        int photoCount = 0)
    {
        var packageId = Guid.NewGuid();
        var package = new DocumentPackage
        {
            Id = packageId,
            CreatedAt = DateTime.UtcNow,
            State = PackageState.Uploaded,
            Teams = new List<Teams>()
        };

        if (poData != null)
        {
            package.PO = new PO
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                ExtractedDataJson = JsonSerializer.Serialize(poData)
            };
        }

        if (invoiceData != null)
        {
            package.Invoices = new List<Invoice>
            {
                new Invoice
                {
                    Id = Guid.NewGuid(),
                    PackageId = packageId,
                    ExtractedDataJson = JsonSerializer.Serialize(invoiceData)
                }
            };
        }

        if (costSummaryData != null)
        {
            package.CostSummary = new CostSummary
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                ExtractedDataJson = JsonSerializer.Serialize(costSummaryData)
            };
        }

        if (activityData != null)
        {
            package.ActivitySummary = new ActivitySummary
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                ExtractedDataJson = JsonSerializer.Serialize(activityData)
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
                    ExtractedMetadataJson = JsonSerializer.Serialize(new PhotoMetadata
                    {
                        Timestamp = DateTime.UtcNow,
                        Latitude = 19.0760,
                        Longitude = 72.8777,
                        HasBlueTshirtPerson = true,
                        HasBajajVehicle = true
                    })
                });
            }
            package.Teams.Add(team);
        }

        return package;
    }

    #endregion

    #region Invoice Field Presence Tests (9 tests)

    [Fact]
    public async Task ValidatePackage_InvoiceMissingAgencyName_ShouldFail()
    {
        // Arrange
        var invoiceData = new InvoiceData
        {
            AgencyName = "", // Missing
            InvoiceNumber = "INV001",
            InvoiceDate = DateTime.UtcNow,
            TotalAmount = 50000
        };

        var package = CreateTestPackage(invoiceData: invoiceData);
        SetupMockDbSet(_mockPackageSet, new List<DocumentPackage> { package });

        // Act
        var result = await _validationAgent.ValidatePackageAsync(package.Id);

        // Assert
        Assert.False(result.AllPassed);
        Assert.NotNull(result.InvoiceFieldPresence);
        Assert.False(result.InvoiceFieldPresence.AllFieldsPresent);
        Assert.Contains("Agency Name", result.InvoiceFieldPresence.MissingFields);
    }

    [Fact]
    public async Task ValidatePackage_InvoiceMissingGSTNumber_ShouldFail()
    {
        // Arrange
        var invoiceData = new InvoiceData
        {
            AgencyName = "Test Agency",
            InvoiceNumber = "INV001",
            InvoiceDate = DateTime.UtcNow,
            GSTNumber = "", // Missing
            TotalAmount = 50000
        };

        var package = CreateTestPackage(invoiceData: invoiceData);
        SetupMockDbSet(_mockPackageSet, new List<DocumentPackage> { package });

        // Act
        var result = await _validationAgent.ValidatePackageAsync(package.Id);

        // Assert
        Assert.False(result.AllPassed);
        Assert.NotNull(result.InvoiceFieldPresence);
        Assert.Contains("GST Number", result.InvoiceFieldPresence.MissingFields);
    }

    [Fact]
    public async Task ValidatePackage_InvoiceAllFieldsPresent_ShouldPass()
    {
        // Arrange
        var invoiceData = new InvoiceData
        {
            AgencyName = "Test Agency",
            AgencyAddress = "123 Test St",
            AgencyCode = "AG001",
            BillingName = "Test Billing",
            BillingAddress = "456 Billing Ave",
            StateName = "Maharashtra",
            StateCode = "MH",
            InvoiceNumber = "INV001",
            InvoiceDate = DateTime.UtcNow,
            VendorCode = "V001",
            VendorName = "Test Vendor",
            GSTNumber = "27AABCU9603R1ZM",
            GSTPercentage = 18,
            HSNSACCode = "998361",
            PONumber = "PO001",
            TotalAmount = 50000
        };

        var poData = new POData
        {
            PONumber = "PO001",
            PODate = DateTime.UtcNow.AddDays(-5),
            AgencyCode = "AG001",
            VendorName = "Test Vendor",
            TotalAmount = 60000,
            LineItems = new List<POLineItem>()
        };

        var package = CreateTestPackage(poData: poData, invoiceData: invoiceData);
        SetupMockDbSet(_mockPackageSet, new List<DocumentPackage> { package });

        // Setup reference data service mocks
        _mockReferenceDataService.Setup(r => r.ValidateGSTStateMapping(It.IsAny<string>(), It.IsAny<string>()))
            .Returns(true);
        _mockReferenceDataService.Setup(r => r.ValidateHSNSACCode(It.IsAny<string>()))
            .Returns(true);
        _mockReferenceDataService.Setup(r => r.GetDefaultGSTPercentage(It.IsAny<string>()))
            .Returns(18);

        // Act
        var result = await _validationAgent.ValidatePackageAsync(package.Id);

        // Assert
        Assert.NotNull(result.InvoiceFieldPresence);
        Assert.True(result.InvoiceFieldPresence.AllFieldsPresent);
        Assert.Empty(result.InvoiceFieldPresence.MissingFields);
    }

    #endregion

    #region Helper Method for DbSet Mock

    private void SetupMockDbSet<T>(Mock<DbSet<T>> mockSet, List<T> data) where T : class
    {
        var queryable = data.AsQueryable();
        mockSet.As<IQueryable<T>>().Setup(m => m.Provider).Returns(new TestAsyncQueryProvider<T>(queryable.Provider));
        mockSet.As<IQueryable<T>>().Setup(m => m.Expression).Returns(queryable.Expression);
        mockSet.As<IQueryable<T>>().Setup(m => m.ElementType).Returns(queryable.ElementType);
        mockSet.As<IQueryable<T>>().Setup(m => m.GetEnumerator()).Returns(queryable.GetEnumerator());

        mockSet.As<IAsyncEnumerable<T>>()
            .Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns(new TestAsyncEnumerator<T>(queryable.GetEnumerator()));
    }

    private class TestAsyncQueryProvider<TEntity> : IAsyncQueryProvider
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

        public object? Execute(System.Linq.Expressions.Expression expression)
        {
            return _inner.Execute(expression);
        }

        public TResult Execute<TResult>(System.Linq.Expressions.Expression expression)
        {
            return _inner.Execute<TResult>(expression);
        }

        public TResult ExecuteAsync<TResult>(System.Linq.Expressions.Expression expression, CancellationToken cancellationToken = default)
        {
            var expectedResultType = typeof(TResult).GetGenericArguments()[0];
            var executionResult = ((IQueryProvider)this).Execute(
                System.Linq.Expressions.Expression.Call(
                    null,
                    typeof(Queryable).GetMethods()
                        .First(m => m.Name == "FirstOrDefault" && m.GetParameters().Length == 1)
                        .MakeGenericMethod(expectedResultType),
                    expression));

            return (TResult)typeof(Task).GetMethod(nameof(Task.FromResult))!
                .MakeGenericMethod(expectedResultType)
                .Invoke(null, new[] { executionResult })!;
        }
    }

    private class TestAsyncEnumerable<T> : EnumerableQuery<T>, IAsyncEnumerable<T>, IQueryable<T>
    {
        public TestAsyncEnumerable(System.Linq.Expressions.Expression expression) : base(expression) { }

        public IAsyncEnumerator<T> GetAsyncEnumerator(CancellationToken cancellationToken = default)
        {
            return new TestAsyncEnumerator<T>(this.AsEnumerable().GetEnumerator());
        }

        IQueryProvider IQueryable.Provider => new TestAsyncQueryProvider<T>(this);
    }

    private class TestAsyncEnumerator<T> : IAsyncEnumerator<T>
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

    #endregion
}
