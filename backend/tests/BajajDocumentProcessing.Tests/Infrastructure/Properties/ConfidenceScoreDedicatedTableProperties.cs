using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Feature: remove-legacy-documents-table, Property 3: Confidence score calculation from dedicated tables
/// 
/// Property: For any DocumentPackage with dedicated document entities (PO, Invoice, CostSummary,
/// ActivitySummary, TeamPhotos) each having an ExtractionConfidence value between 0 and 100,
/// calculating the confidence score SHALL produce an OverallConfidence equal to the weighted sum
/// (PO×0.30 + Invoice×0.30 + CostSummary×0.20 + Activity×0.10 + Photos×0.10),
/// and missing document types SHALL contribute 0.0 to their weight.
/// 
/// **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7**
/// </summary>
public class ConfidenceScoreDedicatedTableProperties
{
    private const double PO_WEIGHT = 0.30;
    private const double INVOICE_WEIGHT = 0.30;
    private const double COST_SUMMARY_WEIGHT = 0.20;
    private const double ACTIVITY_WEIGHT = 0.10;
    private const double PHOTOS_WEIGHT = 0.10;
    private const double TOLERANCE = 0.001;

    /// <summary>
    /// Property 3: Weighted score formula is correct for any confidence values in [0, 100].
    /// </summary>
    [Property(MaxTest = 10)]
    public Property WeightedScore_ForAnyConfidenceValues_EqualsWeightedSum(
        PositiveInt po, PositiveInt inv, PositiveInt cs, PositiveInt act, PositiveInt photo)
    {
        // Constrain to [0, 100]
        var poConf = po.Get % 101;
        var invConf = inv.Get % 101;
        var csConf = cs.Get % 101;
        var actConf = act.Get % 101;
        var photoConf = photo.Get % 101;

        var service = CreateService();
        var result = service.CalculateWeightedScore(poConf, invConf, csConf, actConf, photoConf);

        var expected = (poConf * PO_WEIGHT) + (invConf * INVOICE_WEIGHT) +
                       (csConf * COST_SUMMARY_WEIGHT) + (actConf * ACTIVITY_WEIGHT) +
                       (photoConf * PHOTOS_WEIGHT);
        expected = Math.Max(0, Math.Min(100, expected));

        return (Math.Abs(result - expected) < TOLERANCE)
            .ToProperty()
            .Label($"PO={poConf}, Inv={invConf}, CS={csConf}, Act={actConf}, Photo={photoConf} => Expected={expected:F2}, Got={result:F2}");
    }

    /// <summary>
    /// Property 3b: Missing document types contribute 0.0 — passing 0 for any subset
    /// produces the same result as the weighted formula with those values at 0.
    /// </summary>
    [Property(MaxTest = 10)]
    public Property WeightedScore_MissingDocTypes_ContributeZero(
        PositiveInt po, PositiveInt inv, bool hasCostSummary, bool hasActivity, bool hasPhotos)
    {
        var poConf = (double)(po.Get % 101);
        var invConf = (double)(inv.Get % 101);
        var csConf = hasCostSummary ? 75.0 : 0.0;
        var actConf = hasActivity ? 80.0 : 0.0;
        var photoConf = hasPhotos ? 90.0 : 0.0;

        var service = CreateService();
        var result = service.CalculateWeightedScore(poConf, invConf, csConf, actConf, photoConf);

        var expected = (poConf * PO_WEIGHT) + (invConf * INVOICE_WEIGHT) +
                       (csConf * COST_SUMMARY_WEIGHT) + (actConf * ACTIVITY_WEIGHT) +
                       (photoConf * PHOTOS_WEIGHT);
        expected = Math.Max(0, Math.Min(100, expected));

        return (Math.Abs(result - expected) < TOLERANCE)
            .ToProperty()
            .Label($"Missing types contribute 0: expected={expected:F2}, got={result:F2}");
    }

    /// <summary>
    /// Property 3c: Result is always clamped to [0, 100].
    /// </summary>
    [Property(MaxTest = 10)]
    public Property WeightedScore_AlwaysClampedTo0And100(
        PositiveInt po, PositiveInt inv, PositiveInt cs, PositiveInt act, PositiveInt photo)
    {
        var poConf = (double)(po.Get % 101);
        var invConf = (double)(inv.Get % 101);
        var csConf = (double)(cs.Get % 101);
        var actConf = (double)(act.Get % 101);
        var photoConf = (double)(photo.Get % 101);

        var service = CreateService();
        var result = service.CalculateWeightedScore(poConf, invConf, csConf, actConf, photoConf);

        return (result >= 0.0 && result <= 100.0)
            .ToProperty()
            .Label($"Result={result:F2} should be in [0, 100]");
    }

    /// <summary>
    /// Unit test: All documents at 100% confidence → overall = 100.
    /// </summary>
    [Fact]
    public void WeightedScore_AllAt100_Returns100()
    {
        var service = CreateService();
        var result = service.CalculateWeightedScore(100, 100, 100, 100, 100);
        Assert.Equal(100.0, result, 2);
    }

    /// <summary>
    /// Unit test: All documents at 0% confidence → overall = 0.
    /// </summary>
    [Fact]
    public void WeightedScore_AllAtZero_ReturnsZero()
    {
        var service = CreateService();
        var result = service.CalculateWeightedScore(0, 0, 0, 0, 0);
        Assert.Equal(0.0, result, 2);
    }

    /// <summary>
    /// Unit test: Only PO present at 100% → overall = 30.
    /// </summary>
    [Fact]
    public void WeightedScore_OnlyPOAt100_Returns30()
    {
        var service = CreateService();
        var result = service.CalculateWeightedScore(100, 0, 0, 0, 0);
        Assert.Equal(30.0, result, 2);
    }

    /// <summary>
    /// Unit test: Weights sum to 1.0.
    /// </summary>
    [Fact]
    public void Weights_SumToOne()
    {
        var sum = PO_WEIGHT + INVOICE_WEIGHT + COST_SUMMARY_WEIGHT + ACTIVITY_WEIGHT + PHOTOS_WEIGHT;
        Assert.Equal(1.0, sum, 10);
    }

    private static ConfidenceScoreService CreateService()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ConfidenceScoreService>>();
        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        return new ConfidenceScoreService(mockContext.Object, mockLogger.Object, mockCorrelationIdService.Object);
    }
}
