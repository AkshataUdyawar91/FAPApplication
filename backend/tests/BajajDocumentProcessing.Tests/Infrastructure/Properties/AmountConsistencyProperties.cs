using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 11: Amount Consistency Validation
/// Validates: Requirements 3.2
/// 
/// Property: For any Document Package, if the absolute difference between Invoice total 
/// and Cost Summary total is within 2% of the Invoice total, the amount consistency 
/// validation should pass; otherwise it should fail.
/// </summary>
public class AmountConsistencyProperties
{
    private readonly IValidationAgent _validationAgent;

    public AmountConsistencyProperties()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var mockCorrelationIdService = new Mock<ICorrelationIdService>();

        _validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object,
            mockCorrelationIdService.Object);
    }

    /// <summary>
    /// Property: When amounts differ by exactly 2%, validation should pass (boundary case)
    /// </summary>
    [Property(MaxTest = 100)]
    public void AmountConsistency_WhenDifferenceIsExactly2Percent_ShouldPass(PositiveInt invoiceAmount)
    {
        // Arrange
        var invoiceTotal = (decimal)invoiceAmount.Get;
        var costSummaryTotal = invoiceTotal * 0.98m; // Exactly 2% less

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result, $"Validation should pass when difference is exactly 2%. Invoice: {invoiceTotal}, CostSummary: {costSummaryTotal}");
    }

    /// <summary>
    /// Property: When amounts differ by less than 2%, validation should pass
    /// </summary>
    [Property(MaxTest = 100)]
    public void AmountConsistency_WhenDifferenceIsLessThan2Percent_ShouldPass(PositiveInt invoiceAmount)
    {
        // Arrange
        var invoiceTotal = (decimal)invoiceAmount.Get;
        var percentageDiff = 1.5m; // Less than 2%
        var costSummaryTotal = invoiceTotal * (1 - percentageDiff / 100);

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result, $"Validation should pass when difference is less than 2%. Invoice: {invoiceTotal}, CostSummary: {costSummaryTotal}");
    }

    /// <summary>
    /// Property: When amounts differ by more than 2%, validation should fail
    /// </summary>
    [Property(MaxTest = 100)]
    public void AmountConsistency_WhenDifferenceIsMoreThan2Percent_ShouldFail(PositiveInt invoiceAmount)
    {
        // Arrange
        var invoiceTotal = (decimal)invoiceAmount.Get;
        var percentageDiff = 3.0m; // More than 2%
        var costSummaryTotal = invoiceTotal * (1 - percentageDiff / 100);

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.False(result, $"Validation should fail when difference is more than 2%. Invoice: {invoiceTotal}, CostSummary: {costSummaryTotal}");
    }

    /// <summary>
    /// Property: When amounts are identical, validation should pass
    /// </summary>
    [Property(MaxTest = 100)]
    public void AmountConsistency_WhenAmountsAreIdentical_ShouldPass(PositiveInt amount)
    {
        // Arrange
        var invoiceTotal = (decimal)amount.Get;
        var costSummaryTotal = invoiceTotal;

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result, $"Validation should pass when amounts are identical. Amount: {invoiceTotal}");
    }

    /// <summary>
    /// Property: Validation is symmetric - order of amounts shouldn't matter
    /// </summary>
    [Property(MaxTest = 100)]
    public void AmountConsistency_IsSymmetric(PositiveInt amount1, PositiveInt amount2)
    {
        // Arrange
        var invoiceTotal = (decimal)amount1.Get;
        var costSummaryTotal = (decimal)amount2.Get;

        // Act
        var result1 = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);
        var result2 = _validationAgent.ValidateAmountConsistency(costSummaryTotal, invoiceTotal);

        // Assert
        Assert.Equal(result1, result2);
    }

    /// <summary>
    /// Unit test: Verify exact 2% boundary with specific values
    /// </summary>
    [Fact]
    public void AmountConsistency_ExactBoundaryTest_2Percent()
    {
        // Arrange
        var invoiceTotal = 1000.00m;
        var costSummaryTotal = 980.00m; // Exactly 2% difference

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result);
    }

    /// <summary>
    /// Unit test: Verify just over 2% boundary fails
    /// </summary>
    [Fact]
    public void AmountConsistency_JustOver2Percent_ShouldFail()
    {
        // Arrange
        var invoiceTotal = 1000.00m;
        var costSummaryTotal = 979.00m; // 2.1% difference

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.False(result);
    }

    /// <summary>
    /// Unit test: Verify just under 2% boundary passes
    /// </summary>
    [Fact]
    public void AmountConsistency_JustUnder2Percent_ShouldPass()
    {
        // Arrange
        var invoiceTotal = 1000.00m;
        var costSummaryTotal = 981.00m; // 1.9% difference

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result);
    }

    /// <summary>
    /// Unit test: Verify large amounts work correctly
    /// </summary>
    [Fact]
    public void AmountConsistency_LargeAmounts_WorksCorrectly()
    {
        // Arrange
        var invoiceTotal = 1000000.00m;
        var costSummaryTotal = 980000.00m; // Exactly 2% difference

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result);
    }

    /// <summary>
    /// Unit test: Verify small amounts work correctly
    /// </summary>
    [Fact]
    public void AmountConsistency_SmallAmounts_WorksCorrectly()
    {
        // Arrange
        var invoiceTotal = 10.00m;
        var costSummaryTotal = 9.80m; // Exactly 2% difference

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result);
    }

    /// <summary>
    /// Unit test: Verify cost summary higher than invoice
    /// </summary>
    [Fact]
    public void AmountConsistency_CostSummaryHigherThanInvoice_Within2Percent()
    {
        // Arrange
        var invoiceTotal = 1000.00m;
        var costSummaryTotal = 1020.00m; // 2% higher

        // Act
        var result = _validationAgent.ValidateAmountConsistency(invoiceTotal, costSummaryTotal);

        // Assert
        Assert.True(result);
    }
}
