using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

public class AnalyticsEmbeddingPipelineTests
{
    private readonly Mock<IApplicationDbContext> _mockContext;
    private readonly Mock<IEmbeddingService> _mockEmbeddingService;
    private readonly Mock<IVectorSearchService> _mockVectorSearchService;
    private readonly Mock<ILogger<AnalyticsEmbeddingPipeline>> _mockLogger;
    private readonly AnalyticsEmbeddingPipeline _pipeline;

    public AnalyticsEmbeddingPipelineTests()
    {
        _mockContext = new Mock<IApplicationDbContext>();
        _mockEmbeddingService = new Mock<IEmbeddingService>();
        _mockVectorSearchService = new Mock<IVectorSearchService>();
        _mockLogger = new Mock<ILogger<AnalyticsEmbeddingPipeline>>();

        _pipeline = new AnalyticsEmbeddingPipeline(
            _mockContext.Object,
            _mockEmbeddingService.Object,
            _mockVectorSearchService.Object,
            _mockLogger.Object);
    }

    [Fact]
    public async Task AggregateAnalyticsDataAsync_WithPackages_ReturnsDataPoints()
    {
        // Arrange
        var startDate = new DateTime(2024, 1, 1);
        var endDate = new DateTime(2024, 1, 31);

        var packages = new List<DocumentPackage>
        {
            new DocumentPackage
            {
                Id = Guid.NewGuid(),
                State = PackageState.Approved,
                CreatedAt = new DateTime(2024, 1, 15),
                UpdatedAt = new DateTime(2024, 1, 16),
                ConfidenceScore = new ConfidenceScore { OverallConfidence = 85.0 },
                Recommendation = new Recommendation { Type = RecommendationType.Approve }
            },
            new DocumentPackage
            {
                Id = Guid.NewGuid(),
                State = PackageState.Approved,
                CreatedAt = new DateTime(2024, 1, 20),
                UpdatedAt = new DateTime(2024, 1, 21),
                ConfidenceScore = new ConfidenceScore { OverallConfidence = 90.0 },
                Recommendation = new Recommendation { Type = RecommendationType.Approve }
            },
            new DocumentPackage
            {
                Id = Guid.NewGuid(),
                State = PackageState.Rejected,
                CreatedAt = new DateTime(2024, 1, 25),
                UpdatedAt = new DateTime(2024, 1, 26),
                ConfidenceScore = new ConfidenceScore { OverallConfidence = 60.0 },
                Recommendation = new Recommendation { Type = RecommendationType.Reject }
            }
        };

        var mockSet = CreateMockDbSet(packages);
        _mockContext.Setup(c => c.DocumentPackages).Returns(mockSet.Object);

        // Act
        var result = await _pipeline.AggregateAnalyticsDataAsync(startDate, endDate);

        // Assert
        Assert.NotEmpty(result);
        
        // Should have at least one data point for "ALL"
        var allDataPoint = result.FirstOrDefault(dp => dp.State == null);
        Assert.NotNull(allDataPoint);
        Assert.Equal(3, allDataPoint.SubmissionCount);
        Assert.Equal(2, allDataPoint.ApprovedCount);
        Assert.Equal(1, allDataPoint.RejectedCount);
        Assert.Equal(2.0 / 3.0, allDataPoint.ApprovalRate, precision: 2);
        Assert.Equal(2, allDataPoint.AutoApprovalCount);
    }

    [Fact]
    public async Task AggregateAnalyticsDataAsync_WithNoPackages_ReturnsEmptyList()
    {
        // Arrange
        var startDate = new DateTime(2024, 1, 1);
        var endDate = new DateTime(2024, 1, 31);

        var packages = new List<DocumentPackage>();
        var mockSet = CreateMockDbSet(packages);
        _mockContext.Setup(c => c.DocumentPackages).Returns(mockSet.Object);

        // Act
        var result = await _pipeline.AggregateAnalyticsDataAsync(startDate, endDate);

        // Assert
        Assert.Empty(result);
    }

    [Fact]
    public async Task GenerateVectorDocumentsAsync_CreatesDocumentsWithEmbeddings()
    {
        // Arrange
        var dataPoints = new List<AnalyticsDataPoint>
        {
            new AnalyticsDataPoint
            {
                Id = "TEST_20240101_20240131",
                State = "Maharashtra",
                StartDate = new DateTime(2024, 1, 1),
                EndDate = new DateTime(2024, 1, 31),
                SubmissionCount = 100,
                ApprovedCount = 85,
                RejectedCount = 15,
                ApprovalRate = 0.85,
                AvgConfidenceScore = 82.5,
                AvgProcessingTimeHours = 24.5,
                AutoApprovalCount = 70
            }
        };

        var mockEmbedding = new float[] { 0.1f, 0.2f, 0.3f };
        _mockEmbeddingService
            .Setup(s => s.GenerateEmbeddingsAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<float[]> { mockEmbedding });

        // Act
        var result = await _pipeline.GenerateVectorDocumentsAsync(dataPoints);

        // Assert
        Assert.Single(result);
        var doc = result[0];
        Assert.Equal("TEST_20240101_20240131", doc.Id);
        Assert.Contains("Maharashtra", doc.Content);
        Assert.Contains("100 submissions", doc.Content);
        Assert.Contains("85.0% approval rate", doc.Content);
        Assert.Equal(mockEmbedding, doc.ContentVector);
        Assert.Equal("Maharashtra", doc.Metadata.State);
        Assert.Equal(100, doc.Metadata.SubmissionCount);
        Assert.Equal(0.85, doc.Metadata.ApprovalRate);
    }

    [Fact]
    public async Task RunPipelineAsync_ExecutesAllSteps()
    {
        // Arrange
        var startDate = new DateTime(2024, 1, 1);
        var endDate = new DateTime(2024, 1, 31);

        var packages = new List<DocumentPackage>
        {
            new DocumentPackage
            {
                Id = Guid.NewGuid(),
                State = PackageState.Approved,
                CreatedAt = new DateTime(2024, 1, 15),
                UpdatedAt = new DateTime(2024, 1, 16),
                ConfidenceScore = new ConfidenceScore { OverallConfidence = 85.0 },
                Recommendation = new Recommendation { Type = RecommendationType.Approve }
            }
        };

        var mockSet = CreateMockDbSet(packages);
        _mockContext.Setup(c => c.DocumentPackages).Returns(mockSet.Object);

        var mockEmbedding = new float[] { 0.1f, 0.2f, 0.3f };
        _mockEmbeddingService
            .Setup(s => s.GenerateEmbeddingsAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<float[]> { mockEmbedding, mockEmbedding });

        _mockVectorSearchService
            .Setup(s => s.UpsertDocumentsAsync(It.IsAny<IEnumerable<VectorDocument>>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        await _pipeline.RunPipelineAsync(startDate, endDate);

        // Assert
        _mockEmbeddingService.Verify(
            s => s.GenerateEmbeddingsAsync(It.IsAny<IEnumerable<string>>(), It.IsAny<CancellationToken>()),
            Times.Once);

        _mockVectorSearchService.Verify(
            s => s.UpsertDocumentsAsync(It.IsAny<IEnumerable<VectorDocument>>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task RunPipelineAsync_WithNoData_DoesNotCallUpsert()
    {
        // Arrange
        var startDate = new DateTime(2024, 1, 1);
        var endDate = new DateTime(2024, 1, 31);

        var packages = new List<DocumentPackage>();
        var mockSet = CreateMockDbSet(packages);
        _mockContext.Setup(c => c.DocumentPackages).Returns(mockSet.Object);

        // Act
        await _pipeline.RunPipelineAsync(startDate, endDate);

        // Assert
        _mockVectorSearchService.Verify(
            s => s.UpsertDocumentsAsync(It.IsAny<IEnumerable<VectorDocument>>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    private Mock<DbSet<T>> CreateMockDbSet<T>(List<T> data) where T : class
    {
        var queryable = data.AsQueryable();
        var mockSet = new Mock<DbSet<T>>();

        mockSet.As<IQueryable<T>>().Setup(m => m.Provider).Returns(queryable.Provider);
        mockSet.As<IQueryable<T>>().Setup(m => m.Expression).Returns(queryable.Expression);
        mockSet.As<IQueryable<T>>().Setup(m => m.ElementType).Returns(queryable.ElementType);
        mockSet.As<IQueryable<T>>().Setup(m => m.GetEnumerator()).Returns(queryable.GetEnumerator());

        return mockSet;
    }
}
