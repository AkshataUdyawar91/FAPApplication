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
/// Property 17: Confidence Score Calculation
/// Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
/// 
/// Property: For any Document Package with extracted documents, the overall confidence score 
/// should equal (PO_confidence × 0.30) + (Invoice_confidence × 0.30) + (CostSummary_confidence × 0.20) 
/// + (Activity_confidence × 0.10) + (Photos_confidence × 0.10).
/// </summary>
public class ConfidenceScoreProperties
{
    private readonly IConfidenceScoreService _confidenceScoreService;

    public ConfidenceScoreProperties()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ConfidenceScoreService>>();

        _confidenceScoreService = new ConfidenceScoreService(
            mockContext.Object,
            mockLogger.Object);
    }

    /// <summary>
    /// Property 17: Confidence score calculation follows weighted formula
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ConfidenceScoreCalculation_ShouldFollowWeightedFormula(
        PositiveInt po,
        PositiveInt invoice,
        PositiveInt costSummary,
        PositiveInt activity,
        PositiveInt photos)
    {
        // Arrange - normalize to 0-100 range
        var poConf = po.Get % 101;
        var invoiceConf = invoice.Get % 101;
        var costSummaryConf = costSummary.Get % 101;
        var activityConf = activity.Get % 101;
        var photosConf = photos.Get % 101;

        // Calculate expected weighted score
        var expected = (poConf * 0.30) +
                      (invoiceConf * 0.30) +
                      (costSummaryConf * 0.20) +
                      (activityConf * 0.10) +
                      (photosConf * 0.10);

        // Act
        var actual = _confidenceScoreService.CalculateWeightedScore(
            poConf, invoiceConf, costSummaryConf, activityConf, photosConf);

        // Assert - allow small floating point tolerance
        var difference = Math.Abs(expected - actual);
        return (difference < 0.01).ToProperty()
            .Label($"Expected: {expected:F2}, Actual: {actual:F2}, Difference: {difference:F4}");
    }

    /// <summary>
    /// Property 18: Confidence score bounds - score must be between 0 and 100
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ConfidenceScoreBounds_ShouldBeBetween0And100(
        int po,
        int invoice,
        int costSummary,
        int activity,
        int photos)
    {
        // Act - use any integer values (including negative and > 100)
        var score = _confidenceScoreService.CalculateWeightedScore(
            po, invoice, costSummary, activity, photos);

        // Assert
        return (score >= 0 && score <= 100).ToProperty()
            .Label($"Score: {score:F2} (inputs: PO={po}, Invoice={invoice}, CostSummary={costSummary}, Activity={activity}, Photos={photos})");
    }

    /// <summary>
    /// Unit test: All confidences at 100 should give 100
    /// </summary>
    [Fact]
    public void ConfidenceScore_AllMax_ShouldBe100()
    {
        // Act
        var score = _confidenceScoreService.CalculateWeightedScore(100, 100, 100, 100, 100);

        // Assert
        Assert.Equal(100.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: All confidences at 0 should give 0
    /// </summary>
    [Fact]
    public void ConfidenceScore_AllZero_ShouldBe0()
    {
        // Act
        var score = _confidenceScoreService.CalculateWeightedScore(0, 0, 0, 0, 0);

        // Assert
        Assert.Equal(0.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Weights should sum to 1.0 (verified by all 100s = 100)
    /// </summary>
    [Fact]
    public void ConfidenceScore_WeightsSumTo1()
    {
        // Arrange - all confidences at 100
        var score = _confidenceScoreService.CalculateWeightedScore(100, 100, 100, 100, 100);

        // Assert - should equal 100 if weights sum to 1.0
        Assert.Equal(100.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: PO weight is 0.30
    /// </summary>
    [Fact]
    public void ConfidenceScore_POWeight_ShouldBe30Percent()
    {
        // Arrange - only PO has confidence
        var score = _confidenceScoreService.CalculateWeightedScore(100, 0, 0, 0, 0);

        // Assert
        Assert.Equal(30.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Invoice weight is 0.30
    /// </summary>
    [Fact]
    public void ConfidenceScore_InvoiceWeight_ShouldBe30Percent()
    {
        // Arrange - only Invoice has confidence
        var score = _confidenceScoreService.CalculateWeightedScore(0, 100, 0, 0, 0);

        // Assert
        Assert.Equal(30.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Cost Summary weight is 0.20
    /// </summary>
    [Fact]
    public void ConfidenceScore_CostSummaryWeight_ShouldBe20Percent()
    {
        // Arrange - only Cost Summary has confidence
        var score = _confidenceScoreService.CalculateWeightedScore(0, 0, 100, 0, 0);

        // Assert
        Assert.Equal(20.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Activity weight is 0.10
    /// </summary>
    [Fact]
    public void ConfidenceScore_ActivityWeight_ShouldBe10Percent()
    {
        // Arrange - only Activity has confidence
        var score = _confidenceScoreService.CalculateWeightedScore(0, 0, 0, 100, 0);

        // Assert
        Assert.Equal(10.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Photos weight is 0.10
    /// </summary>
    [Fact]
    public void ConfidenceScore_PhotosWeight_ShouldBe10Percent()
    {
        // Arrange - only Photos has confidence
        var score = _confidenceScoreService.CalculateWeightedScore(0, 0, 0, 0, 100);

        // Assert
        Assert.Equal(10.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Negative values should be clamped to 0
    /// </summary>
    [Fact]
    public void ConfidenceScore_NegativeValues_ShouldBeClampedTo0()
    {
        // Act
        var score = _confidenceScoreService.CalculateWeightedScore(-100, -100, -100, -100, -100);

        // Assert
        Assert.Equal(0.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Values over 100 should be clamped to 100
    /// </summary>
    [Fact]
    public void ConfidenceScore_ValuesOver100_ShouldBeClampedTo100()
    {
        // Act
        var score = _confidenceScoreService.CalculateWeightedScore(200, 200, 200, 200, 200);

        // Assert
        Assert.Equal(100.0, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Mixed positive and negative values
    /// </summary>
    [Fact]
    public void ConfidenceScore_MixedValues_ShouldCalculateCorrectly()
    {
        // Arrange
        var expected = (80 * 0.30) + (90 * 0.30) + (70 * 0.20) + (60 * 0.10) + (85 * 0.10);

        // Act
        var score = _confidenceScoreService.CalculateWeightedScore(80, 90, 70, 60, 85);

        // Assert
        Assert.Equal(expected, score, precision: 2);
    }

    /// <summary>
    /// Unit test: Score at exactly 70 (boundary for flagging)
    /// </summary>
    [Fact]
    public void ConfidenceScore_Exactly70_ShouldCalculateCorrectly()
    {
        // Arrange - calculate inputs that give exactly 70
        // 70 = (po * 0.30) + (invoice * 0.30) + (cs * 0.20) + (act * 0.10) + (photo * 0.10)
        // Using all 70s should give 70
        var expected = 70.0;

        // Act
        var score = _confidenceScoreService.CalculateWeightedScore(70, 70, 70, 70, 70);

        // Assert
        Assert.Equal(expected, score, precision: 2);
    }
}
