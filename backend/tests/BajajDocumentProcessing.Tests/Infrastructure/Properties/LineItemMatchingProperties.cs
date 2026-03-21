using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 12: Line Item Matching
/// Validates: Requirements 3.3
/// 
/// Property: For any Document Package, the line item validation should pass if and only if 
/// every PO line item (by item code) appears in the Invoice line items.
/// </summary>
public class LineItemMatchingProperties
{
    private readonly IValidationAgent _validationAgent;

    public LineItemMatchingProperties()
    {
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var mockCorrelationIdService = new Mock<ICorrelationIdService>();
        var mockPerceptualHashService = new Mock<IPerceptualHashService>();

        _validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object,
            mockCorrelationIdService.Object,
            mockPerceptualHashService.Object,
            new Mock<IPoBalanceService>().Object);
    }

    /// <summary>
    /// Property: When all PO items exist in Invoice, validation should pass
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(LineItemGenerators) })]
    public void LineItemMatching_WhenAllPOItemsExistInInvoice_ShouldPass(NonEmptyArray<string> itemCodes)
    {
        // Arrange
        var poItems = itemCodes.Get.Select(code => new POLineItem
        {
            ItemCode = code,
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        var invoiceItems = itemCodes.Get.Select(code => new InvoiceLineItem
        {
            ItemCode = code,
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.True(result, "Validation should pass when all PO items exist in Invoice");
    }

    /// <summary>
    /// Property: When Invoice has more items than PO, validation should still pass
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(LineItemGenerators) })]
    public void LineItemMatching_WhenInvoiceHasExtraItems_ShouldPass(NonEmptyArray<string> poItemCodes, NonEmptyArray<string> extraItemCodes)
    {
        // Arrange
        var poItems = poItemCodes.Get.Select(code => new POLineItem
        {
            ItemCode = code,
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        var allInvoiceItemCodes = poItemCodes.Get.Concat(extraItemCodes.Get).Distinct();
        var invoiceItems = allInvoiceItemCodes.Select(code => new InvoiceLineItem
        {
            ItemCode = code,
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.True(result, "Validation should pass when Invoice has extra items beyond PO items");
    }

    /// <summary>
    /// Property: When any PO item is missing from Invoice, validation should fail
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(LineItemGenerators) })]
    public void LineItemMatching_WhenPOItemMissingFromInvoice_ShouldFail(NonEmptyArray<string> itemCodes)
    {
        // Arrange - Ensure we have at least 2 distinct items
        var allItemCodes = itemCodes.Get.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        if (allItemCodes.Count < 2)
        {
            allItemCodes.Add("EXTRA-ITEM-" + Guid.NewGuid().ToString().Substring(0, 8));
        }

        var poItems = allItemCodes.Select(code => new POLineItem
        {
            ItemCode = code,
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        // Invoice is missing the first item
        var invoiceItems = allItemCodes.Skip(1).Select(code => new InvoiceLineItem
        {
            ItemCode = code,
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.False(result, "Validation should fail when any PO item is missing from Invoice");
    }

    /// <summary>
    /// Property: Matching is case-insensitive
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(LineItemGenerators) })]
    public void LineItemMatching_IsCaseInsensitive(NonEmptyArray<string> itemCodes)
    {
        // Arrange
        var poItems = itemCodes.Get.Select(code => new POLineItem
        {
            ItemCode = code.ToUpperInvariant(),
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        var invoiceItems = itemCodes.Get.Select(code => new InvoiceLineItem
        {
            ItemCode = code.ToLowerInvariant(),
            Description = $"Item {code}",
            Quantity = 1,
            UnitPrice = 100m,
            LineTotal = 100m
        }).ToList();

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.True(result, "Validation should be case-insensitive for item codes");
    }

    /// <summary>
    /// Unit test: Empty PO items should pass (no items to validate)
    /// </summary>
    [Fact]
    public void LineItemMatching_EmptyPOItems_ShouldPass()
    {
        // Arrange
        var poItems = new List<POLineItem>();
        var invoiceItems = new List<InvoiceLineItem>
        {
            new InvoiceLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 1, UnitPrice = 100m, LineTotal = 100m }
        };

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.True(result);
    }

    /// <summary>
    /// Unit test: Specific example with all items matching
    /// </summary>
    [Fact]
    public void LineItemMatching_AllItemsMatch_ShouldPass()
    {
        // Arrange
        var poItems = new List<POLineItem>
        {
            new POLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m },
            new POLineItem { ItemCode = "ITEM-002", Description = "Item 2", Quantity = 5, UnitPrice = 200m, LineTotal = 1000m }
        };

        var invoiceItems = new List<InvoiceLineItem>
        {
            new InvoiceLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m },
            new InvoiceLineItem { ItemCode = "ITEM-002", Description = "Item 2", Quantity = 5, UnitPrice = 200m, LineTotal = 1000m }
        };

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.True(result);
    }

    /// <summary>
    /// Unit test: Missing one item should fail
    /// </summary>
    [Fact]
    public void LineItemMatching_MissingOneItem_ShouldFail()
    {
        // Arrange
        var poItems = new List<POLineItem>
        {
            new POLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m },
            new POLineItem { ItemCode = "ITEM-002", Description = "Item 2", Quantity = 5, UnitPrice = 200m, LineTotal = 1000m }
        };

        var invoiceItems = new List<InvoiceLineItem>
        {
            new InvoiceLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m }
            // ITEM-002 is missing
        };

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.False(result);
    }

    /// <summary>
    /// Unit test: Invoice with extra items should pass
    /// </summary>
    [Fact]
    public void LineItemMatching_InvoiceWithExtraItems_ShouldPass()
    {
        // Arrange
        var poItems = new List<POLineItem>
        {
            new POLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m }
        };

        var invoiceItems = new List<InvoiceLineItem>
        {
            new InvoiceLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m },
            new InvoiceLineItem { ItemCode = "ITEM-002", Description = "Item 2", Quantity = 5, UnitPrice = 200m, LineTotal = 1000m },
            new InvoiceLineItem { ItemCode = "ITEM-003", Description = "Item 3", Quantity = 3, UnitPrice = 150m, LineTotal = 450m }
        };

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.True(result);
    }

    /// <summary>
    /// Unit test: Case insensitive matching
    /// </summary>
    [Fact]
    public void LineItemMatching_CaseInsensitive_ShouldPass()
    {
        // Arrange
        var poItems = new List<POLineItem>
        {
            new POLineItem { ItemCode = "ITEM-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m },
            new POLineItem { ItemCode = "item-002", Description = "Item 2", Quantity = 5, UnitPrice = 200m, LineTotal = 1000m }
        };

        var invoiceItems = new List<InvoiceLineItem>
        {
            new InvoiceLineItem { ItemCode = "item-001", Description = "Item 1", Quantity = 10, UnitPrice = 100m, LineTotal = 1000m },
            new InvoiceLineItem { ItemCode = "ITEM-002", Description = "Item 2", Quantity = 5, UnitPrice = 200m, LineTotal = 1000m }
        };

        // Act
        var result = _validationAgent.ValidateLineItems(poItems, invoiceItems);

        // Assert
        Assert.True(result);
    }
}

/// <summary>
/// Custom generators for line item tests
/// </summary>
public static class LineItemGenerators
{
    public static Arbitrary<NonEmptyArray<string>> ItemCodeArrayGenerator()
    {
        return Arb.Generate<NonEmptyString>()
            .Select(nes =>
            {
                var cleaned = nes.Get.Replace(" ", "");
                return $"ITEM-{(cleaned.Length > 0 ? cleaned.Substring(0, Math.Min(10, cleaned.Length)) : Guid.NewGuid().ToString().Substring(0, 8))}";
            })
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ArrayOf()
            .Where(arr => arr.Length > 0)
            .Select(arr => NonEmptyArray<string>.NewNonEmptyArray(arr.Distinct().ToArray()))
            .ToArbitrary();
    }
}
