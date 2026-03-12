using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Query;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 22: Recommendation Logic
/// Validates: Requirements 5.3, 5.4, 5.5
/// 
/// Property: The recommendation type should be determined by:
/// - APPROVE if confidence >= 85 and validation passed
/// - REVIEW if confidence between 70-85
/// - REJECT if confidence < 70 or validation failed
/// </summary>
public class RecommendationLogicProperties
{
    /// <summary>
    /// Property: High confidence (>= 85) with validation passed should recommend APPROVE
    /// </summary>
    [Property(MaxTest = 20)]
    public Property RecommendationLogic_HighConfidenceAndValidationPassed_ShouldApprove(PositiveInt confidence)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange - confidence >= 85
                var conf = 85 + (confidence.Get % 16); // 85-100
                var (agent, mockContext) = CreateRecommendationAgent();
                SetupMockData(mockContext, packageId, conf, true);

                // Act
                var recommendation = agent.GenerateRecommendationAsync(packageId, CancellationToken.None).GetAwaiter().GetResult();

                // Assert
                return (recommendation.Type == RecommendationType.Approve)
                    .Label($"Confidence: {conf:F2}, Validation: Passed, Expected: APPROVE, Actual: {recommendation.Type}");
            });
    }

    /// <summary>
    /// Property: Moderate confidence (70-85) should recommend REVIEW
    /// </summary>
    [Property(MaxTest = 20)]
    public Property RecommendationLogic_ModerateConfidence_ShouldReview(PositiveInt confidence)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange - confidence between 70 and 85
                var conf = 70 + (confidence.Get % 15); // 70-84
                var (agent, mockContext) = CreateRecommendationAgent();
                SetupMockData(mockContext, packageId, conf, true);

                // Act
                var recommendation = agent.GenerateRecommendationAsync(packageId, CancellationToken.None).GetAwaiter().GetResult();

                // Assert
                return (recommendation.Type == RecommendationType.Review)
                    .Label($"Confidence: {conf:F2}, Validation: Passed, Expected: REVIEW, Actual: {recommendation.Type}");
            });
    }

    /// <summary>
    /// Property: Low confidence (< 70) should recommend REJECT
    /// </summary>
    [Property(MaxTest = 20)]
    public Property RecommendationLogic_LowConfidence_ShouldReject(PositiveInt confidence)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange - confidence < 70
                var conf = confidence.Get % 70; // 0-69
                var (agent, mockContext) = CreateRecommendationAgent();
                SetupMockData(mockContext, packageId, conf, true);

                // Act
                var recommendation = agent.GenerateRecommendationAsync(packageId, CancellationToken.None).GetAwaiter().GetResult();

                // Assert
                return (recommendation.Type == RecommendationType.Reject)
                    .Label($"Confidence: {conf:F2}, Validation: Passed, Expected: REJECT, Actual: {recommendation.Type}");
            });
    }

    /// <summary>
    /// Property: Validation failed should always recommend REJECT regardless of confidence
    /// </summary>
    [Property(MaxTest = 20)]
    public Property RecommendationLogic_ValidationFailed_ShouldAlwaysReject(PositiveInt confidence)
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            packageId =>
            {
                // Arrange - any confidence, validation failed
                var conf = confidence.Get % 101; // 0-100
                var (agent, mockContext) = CreateRecommendationAgent();
                SetupMockData(mockContext, packageId, conf, false);

                // Act
                var recommendation = agent.GenerateRecommendationAsync(packageId, CancellationToken.None).GetAwaiter().GetResult();

                // Assert
                return (recommendation.Type == RecommendationType.Reject)
                    .Label($"Confidence: {conf:F2}, Validation: Failed, Expected: REJECT, Actual: {recommendation.Type}");
            });
    }

    /// <summary>
    /// Unit test: Exactly 85 confidence with validation passed should APPROVE
    /// </summary>
    [Fact]
    public async Task RecommendationLogic_Exactly85WithValidation_ShouldApprove()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var (agent, mockContext) = CreateRecommendationAgent();
        SetupMockData(mockContext, packageId, 85.0, true);

        // Act
        var recommendation = await agent.GenerateRecommendationAsync(packageId, CancellationToken.None);

        // Assert
        Assert.Equal(RecommendationType.Approve, recommendation.Type);
    }

    /// <summary>
    /// Unit test: Exactly 70 confidence with validation passed should REVIEW
    /// </summary>
    [Fact]
    public async Task RecommendationLogic_Exactly70WithValidation_ShouldReview()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var (agent, mockContext) = CreateRecommendationAgent();
        SetupMockData(mockContext, packageId, 70.0, true);

        // Act
        var recommendation = await agent.GenerateRecommendationAsync(packageId, CancellationToken.None);

        // Assert
        Assert.Equal(RecommendationType.Review, recommendation.Type);
    }

    /// <summary>
    /// Unit test: Just below 70 confidence should REJECT
    /// </summary>
    [Fact]
    public async Task RecommendationLogic_JustBelow70_ShouldReject()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var (agent, mockContext) = CreateRecommendationAgent();
        SetupMockData(mockContext, packageId, 69.9, true);

        // Act
        var recommendation = await agent.GenerateRecommendationAsync(packageId, CancellationToken.None);

        // Assert
        Assert.Equal(RecommendationType.Reject, recommendation.Type);
    }

    /// <summary>
    /// Unit test: Just below 85 confidence should REVIEW
    /// </summary>
    [Fact]
    public async Task RecommendationLogic_JustBelow85_ShouldReview()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var (agent, mockContext) = CreateRecommendationAgent();
        SetupMockData(mockContext, packageId, 84.9, true);

        // Act
        var recommendation = await agent.GenerateRecommendationAsync(packageId, CancellationToken.None);

        // Assert
        Assert.Equal(RecommendationType.Review, recommendation.Type);
    }

    /// <summary>
    /// Unit test: 100 confidence with validation failed should REJECT
    /// </summary>
    [Fact]
    public async Task RecommendationLogic_PerfectConfidenceButValidationFailed_ShouldReject()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var (agent, mockContext) = CreateRecommendationAgent();
        SetupMockData(mockContext, packageId, 100.0, false);

        // Act
        var recommendation = await agent.GenerateRecommendationAsync(packageId, CancellationToken.None);

        // Assert
        Assert.Equal(RecommendationType.Reject, recommendation.Type);
    }

    /// <summary>
    /// Unit test: Evidence should contain confidence score
    /// </summary>
    [Fact]
    public async Task RecommendationLogic_Evidence_ShouldContainConfidenceScore()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var (agent, mockContext) = CreateRecommendationAgent();
        SetupMockData(mockContext, packageId, 85.0, true);

        // Act
        var recommendation = await agent.GenerateRecommendationAsync(packageId, CancellationToken.None);

        // Assert
        Assert.Contains("85", recommendation.Evidence);
        Assert.Contains("Confidence", recommendation.Evidence);
    }

    /// <summary>
    /// Unit test: Evidence should contain validation results
    /// </summary>
    [Fact]
    public async Task RecommendationLogic_Evidence_ShouldContainValidationResults()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var (agent, mockContext) = CreateRecommendationAgent();
        SetupMockData(mockContext, packageId, 85.0, true);

        // Act
        var recommendation = await agent.GenerateRecommendationAsync(packageId, CancellationToken.None);

        // Assert
        Assert.Contains("Validation", recommendation.Evidence);
        Assert.Contains("PASSED", recommendation.Evidence);
    }

    private (IRecommendationAgent, Mock<IApplicationDbContext>) CreateRecommendationAgent()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<RecommendationAgent>>();
        var mockConfiguration = new Mock<IConfiguration>();
        
        // Setup configuration mocks with IConfigurationSection
        var mockEndpointSection = new Mock<IConfigurationSection>();
        mockEndpointSection.Setup(s => s.Value).Returns("https://test.openai.azure.com/");
        mockConfiguration.Setup(c => c.GetSection("AzureOpenAI:Endpoint")).Returns(mockEndpointSection.Object);
        mockConfiguration.Setup(c => c["AzureOpenAI:Endpoint"]).Returns("https://test.openai.azure.com/");
        
        var mockApiKeySection = new Mock<IConfigurationSection>();
        mockApiKeySection.Setup(s => s.Value).Returns("test-api-key");
        mockConfiguration.Setup(c => c.GetSection("AzureOpenAI:ApiKey")).Returns(mockApiKeySection.Object);
        mockConfiguration.Setup(c => c["AzureOpenAI:ApiKey"]).Returns("test-api-key");
        
        var mockDeploymentSection = new Mock<IConfigurationSection>();
        mockDeploymentSection.Setup(s => s.Value).Returns("gpt-4");
        mockConfiguration.Setup(c => c.GetSection("AzureOpenAI:DeploymentName")).Returns(mockDeploymentSection.Object);
        mockConfiguration.Setup(c => c["AzureOpenAI:DeploymentName"]).Returns("gpt-4");

        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        var agent = new RecommendationAgent(mockContext.Object, mockConfiguration.Object, mockLogger.Object, mockCorrelationIdService.Object);

        return (agent, mockContext);
    }

    private void SetupMockData(
        Mock<IApplicationDbContext> mockContext,
        Guid packageId,
        double confidenceScore,
        bool validationPassed)
    {
        // Create package
        var package = new DocumentPackage
        {
            Id = packageId,
            State = PackageState.Validating,
            CreatedAt = DateTime.UtcNow,
            Documents = new List<Document>()
        };

        var packages = new List<DocumentPackage> { package };
        var mockPackageSet = CreateMockDbSet(packages);
        mockContext.Setup(c => c.DocumentPackages).Returns(mockPackageSet.Object);

        // Create validation result
        var validationResult = new ValidationResult
        {
            Id = Guid.NewGuid(),
            DocumentType = DocumentType.PO,
            DocumentId = packageId,
            AllValidationsPassed = validationPassed,
            SapVerificationPassed = validationPassed,
            AmountConsistencyPassed = validationPassed,
            LineItemMatchingPassed = validationPassed,
            CompletenessCheckPassed = validationPassed,
            DateValidationPassed = validationPassed,
            VendorMatchingPassed = validationPassed,
            CreatedAt = DateTime.UtcNow
        };

        var validationResults = new List<ValidationResult> { validationResult };
        var mockValidationSet = CreateMockDbSet(validationResults);
        mockContext.Setup(c => c.ValidationResults).Returns(mockValidationSet.Object);

        // Create confidence score
        var confidence = new ConfidenceScore
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            OverallConfidence = confidenceScore,
            PoConfidence = confidenceScore,
            InvoiceConfidence = confidenceScore,
            CostSummaryConfidence = confidenceScore,
            ActivityConfidence = confidenceScore,
            PhotosConfidence = confidenceScore,
            IsFlaggedForReview = confidenceScore < 70,
            CreatedAt = DateTime.UtcNow
        };

        var confidenceScores = new List<ConfidenceScore> { confidence };
        var mockConfidenceSet = CreateMockDbSet(confidenceScores);
        mockContext.Setup(c => c.ConfidenceScores).Returns(mockConfidenceSet.Object);

        // Create empty recommendations set
        var recommendations = new List<Recommendation>();
        var mockRecommendationSet = CreateMockDbSet(recommendations);
        mockContext.Setup(c => c.Recommendations).Returns(mockRecommendationSet.Object);

        // Setup SaveChangesAsync
        mockContext.Setup(c => c.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);
    }

    private Mock<DbSet<T>> CreateMockDbSet<T>(List<T> data) where T : class
    {
        var queryable = data.AsQueryable();
        var mockSet = new Mock<DbSet<T>>();

        mockSet.As<IQueryable<T>>().Setup(m => m.Provider).Returns(new TestAsyncQueryProvider<T>(queryable.Provider));
        mockSet.As<IQueryable<T>>().Setup(m => m.Expression).Returns(queryable.Expression);
        mockSet.As<IQueryable<T>>().Setup(m => m.ElementType).Returns(queryable.ElementType);
        mockSet.As<IQueryable<T>>().Setup(m => m.GetEnumerator()).Returns(queryable.GetEnumerator());

        mockSet.As<IAsyncEnumerable<T>>()
            .Setup(m => m.GetAsyncEnumerator(It.IsAny<CancellationToken>()))
            .Returns(new TestAsyncEnumerator<T>(queryable.GetEnumerator()));

        return mockSet;
    }
}
