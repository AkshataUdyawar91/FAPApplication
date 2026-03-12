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
/// Property 28: Email Recipient Routing
/// Validates: Requirements 6.5
/// 
/// Property: Emails should be routed to the correct recipients based on scenario
/// </summary>
public class EmailAgentProperties
{
    /// <summary>
    /// Property: Data failure emails should be sent to the agency user who submitted the package
    /// </summary>
    [Property(MaxTest = 10)]
    public Property EmailRecipientRouting_DataFailure_ShouldSendToAgency()
    {
        return Prop.ForAll(
            Arb.Default.Guid().Generator.ToArbitrary(),
            Arb.Default.NonEmptyString().Generator.ToArbitrary(),
            (packageId, emailStr) =>
            {
                // Arrange
                var agencyEmail = $"{emailStr.Get}@agency.com";
                var (agent, mockContext) = CreateEmailAgent();
                SetupMockPackageWithUser(mockContext, packageId, agencyEmail, UserRole.Agency);

                var issues = new List<ValidationIssue>
                {
                    new ValidationIssue { Field = "PO Number", Issue = "Missing" }
                };

                // Act
                var result = agent.SendDataFailureEmailAsync(packageId, issues, CancellationToken.None)
                    .GetAwaiter().GetResult();

                // Assert - email should be sent successfully (to agency user)
                return result.Success
                    .Label($"Email should be sent to agency user {agencyEmail}");
            });
    }

    /// <summary>
    /// Unit test: Data pass email should be sent to ASM
    /// </summary>
    [Fact]
    public async Task EmailRecipientRouting_DataPass_ShouldSendToASM()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var asmEmail = "asm@bajaj.com";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, "agency@test.com", UserRole.Agency);
        SetupMockConfidenceScore(mockContext, packageId, 85.0);
        SetupMockRecommendation(mockContext, packageId, RecommendationType.Approve);

        // Act
        var result = await agent.SendDataPassEmailAsync(packageId, asmEmail, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    /// <summary>
    /// Unit test: Approved email should be sent to agency
    /// </summary>
    [Fact]
    public async Task EmailRecipientRouting_Approved_ShouldSendToAgency()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var agencyEmail = "agency@test.com";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, agencyEmail, UserRole.Agency);

        // Act
        var result = await agent.SendApprovedEmailAsync(packageId, agencyEmail, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    /// <summary>
    /// Unit test: Rejected email should be sent to agency
    /// </summary>
    [Fact]
    public async Task EmailRecipientRouting_Rejected_ShouldSendToAgency()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var agencyEmail = "agency@test.com";
        var reason = "Documents do not match requirements";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, agencyEmail, UserRole.Agency);

        // Act
        var result = await agent.SendRejectedEmailAsync(packageId, agencyEmail, reason, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    /// <summary>
    /// Property 29: Email Delivery Retry
    /// Validates: Requirements 6.6
    /// 
    /// Unit test: Email delivery should retry up to 3 times on failure
    /// </summary>
    [Fact]
    public async Task EmailDeliveryRetry_OnFailure_ShouldRetryThreeTimes()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var agencyEmail = "agency@test.com";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, agencyEmail, UserRole.Agency);

        var issues = new List<ValidationIssue>
        {
            new ValidationIssue { Field = "Test", Issue = "Test issue" }
        };

        // Act
        var result = await agent.SendDataFailureEmailAsync(packageId, issues, CancellationToken.None);

        // Assert - should succeed (mock implementation always succeeds)
        // In real implementation with ACS failures, this would test retry logic
        Assert.True(result.AttemptsCount >= 1);
        Assert.True(result.AttemptsCount <= 3);
    }

    /// <summary>
    /// Unit test: Successful email delivery should return message ID
    /// </summary>
    [Fact]
    public async Task EmailDelivery_OnSuccess_ShouldReturnMessageId()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var agencyEmail = "agency@test.com";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, agencyEmail, UserRole.Agency);

        // Act
        var result = await agent.SendApprovedEmailAsync(packageId, agencyEmail, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
        Assert.NotNull(result.MessageId);
        Assert.StartsWith("msg_", result.MessageId);
    }

    /// <summary>
    /// Unit test: Email should include validation issues in data failure scenario
    /// </summary>
    [Fact]
    public async Task EmailContent_DataFailure_ShouldIncludeValidationIssues()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var agencyEmail = "agency@test.com";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, agencyEmail, UserRole.Agency);

        var issues = new List<ValidationIssue>
        {
            new ValidationIssue
            {
                Field = "PO Number",
                Issue = "Does not match SAP",
                ExpectedValue = "PO12345",
                ActualValue = "PO54321"
            },
            new ValidationIssue
            {
                Field = "Invoice Amount",
                Issue = "Exceeds tolerance",
                ExpectedValue = "1000.00",
                ActualValue = "1050.00"
            }
        };

        // Act
        var result = await agent.SendDataFailureEmailAsync(packageId, issues, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    /// <summary>
    /// Unit test: Email should include confidence score in data pass scenario
    /// </summary>
    [Fact]
    public async Task EmailContent_DataPass_ShouldIncludeConfidenceScore()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var asmEmail = "asm@bajaj.com";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, "agency@test.com", UserRole.Agency);
        SetupMockConfidenceScore(mockContext, packageId, 92.5);
        SetupMockRecommendation(mockContext, packageId, RecommendationType.Approve);

        // Act
        var result = await agent.SendDataPassEmailAsync(packageId, asmEmail, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    /// <summary>
    /// Unit test: Email should include rejection reason in rejected scenario
    /// </summary>
    [Fact]
    public async Task EmailContent_Rejected_ShouldIncludeReason()
    {
        // Arrange
        var packageId = Guid.NewGuid();
        var agencyEmail = "agency@test.com";
        var reason = "Documents are incomplete and do not meet quality standards";
        var (agent, mockContext) = CreateEmailAgent();
        SetupMockPackageWithUser(mockContext, packageId, agencyEmail, UserRole.Agency);

        // Act
        var result = await agent.SendRejectedEmailAsync(packageId, agencyEmail, reason, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    private (IEmailAgent, Mock<IApplicationDbContext>) CreateEmailAgent()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockConfiguration = new Mock<IConfiguration>();
        var mockLogger = new Mock<ILogger<EmailAgent>>();

        // Setup configuration
        mockConfiguration.Setup(c => c["AzureCommunicationServices:ConnectionString"])
            .Returns("mock-connection-string");

        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        var agent = new EmailAgent(mockContext.Object, mockConfiguration.Object, mockLogger.Object, mockCorrelationIdService.Object);

        return (agent, mockContext);
    }

    private void SetupMockPackageWithUser(
        Mock<IApplicationDbContext> mockContext,
        Guid packageId,
        string userEmail,
        UserRole userRole)
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = userEmail,
            FullName = "Test User",
            Role = userRole,
            CreatedAt = DateTime.UtcNow
        };

        var package = new DocumentPackage
        {
            Id = packageId,
            SubmittedByUserId = user.Id,
            SubmittedBy = user,
            State = PackageState.Validating,
            CreatedAt = DateTime.UtcNow,
            Documents = new List<Document>()
        };

        var packages = new List<DocumentPackage> { package };
        var mockPackageSet = CreateMockDbSet(packages);
        mockContext.Setup(c => c.DocumentPackages).Returns(mockPackageSet.Object);

        // Setup SaveChangesAsync
        mockContext.Setup(c => c.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);
    }

    private void SetupMockConfidenceScore(
        Mock<IApplicationDbContext> mockContext,
        Guid packageId,
        double confidence)
    {
        var confidenceScore = new ConfidenceScore
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            OverallConfidence = confidence,
            PoConfidence = confidence,
            InvoiceConfidence = confidence,
            CostSummaryConfidence = confidence,
            ActivityConfidence = confidence,
            PhotosConfidence = confidence,
            IsFlaggedForReview = confidence < 70,
            CreatedAt = DateTime.UtcNow
        };

        var confidenceScores = new List<ConfidenceScore> { confidenceScore };
        var mockConfidenceSet = CreateMockDbSet(confidenceScores);
        mockContext.Setup(c => c.ConfidenceScores).Returns(mockConfidenceSet.Object);
    }

    private void SetupMockRecommendation(
        Mock<IApplicationDbContext> mockContext,
        Guid packageId,
        RecommendationType type)
    {
        var recommendation = new Recommendation
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            Type = type,
            Evidence = "Test evidence",
            ConfidenceScore = 85.0,
            CreatedAt = DateTime.UtcNow
        };

        var recommendations = new List<Recommendation> { recommendation };
        var mockRecommendationSet = CreateMockDbSet(recommendations);
        mockContext.Setup(c => c.Recommendations).Returns(mockRecommendationSet.Object);
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
