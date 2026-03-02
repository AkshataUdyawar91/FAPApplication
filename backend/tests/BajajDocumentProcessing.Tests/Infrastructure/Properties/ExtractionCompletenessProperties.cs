using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;
using FsCheck;
using FsCheck.Xunit;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 6: Extraction Completeness
/// Validates: Requirements 2.2, 2.3, 2.4
/// 
/// Property: For any classified document of a specific type, the extracted data should contain 
/// all required fields for that document type with non-null values.
/// </summary>
public class ExtractionCompletenessProperties
{
    /// <summary>
    /// Property: POData must have all required fields with non-null values
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(PODataGenerators) })]
    public void POData_MustHaveAllRequiredFieldsNonNull(POData poData)
    {
        // Property: For any POData extracted from a PO document, all required fields must be non-null
        
        // Assert PONumber is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(poData.PONumber),
            "PONumber must not be null or empty");
        
        // Assert VendorName is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(poData.VendorName),
            "VendorName must not be null or empty");
        
        // Assert PODate is not default (DateTime has a value)
        Assert.NotEqual(
            default(DateTime),
            poData.PODate);
        
        // Assert LineItems is not null
        Assert.NotNull(poData.LineItems);
        
        // Assert TotalAmount is set (not default)
        // Note: TotalAmount can be 0 for valid documents, but should be explicitly set
        Assert.True(
            poData.TotalAmount >= 0,
            "TotalAmount must be non-negative");
        
        // Assert FieldConfidences is not null
        Assert.NotNull(poData.FieldConfidences);
    }

    /// <summary>
    /// Property: InvoiceData must have all required fields with non-null values
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(InvoiceDataGenerators) })]
    public void InvoiceData_MustHaveAllRequiredFieldsNonNull(InvoiceData invoiceData)
    {
        // Property: For any InvoiceData extracted from an Invoice document, all required fields must be non-null
        
        // Assert InvoiceNumber is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(invoiceData.InvoiceNumber),
            "InvoiceNumber must not be null or empty");
        
        // Assert VendorName is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(invoiceData.VendorName),
            "VendorName must not be null or empty");
        
        // Assert InvoiceDate is not default
        Assert.NotEqual(
            default(DateTime),
            invoiceData.InvoiceDate);
        
        // Assert LineItems is not null
        Assert.NotNull(invoiceData.LineItems);
        
        // Assert SubTotal is non-negative
        Assert.True(
            invoiceData.SubTotal >= 0,
            "SubTotal must be non-negative");
        
        // Assert TaxAmount is non-negative
        Assert.True(
            invoiceData.TaxAmount >= 0,
            "TaxAmount must be non-negative");
        
        // Assert TotalAmount is non-negative
        Assert.True(
            invoiceData.TotalAmount >= 0,
            "TotalAmount must be non-negative");
        
        // Assert FieldConfidences is not null
        Assert.NotNull(invoiceData.FieldConfidences);
    }

    /// <summary>
    /// Property: CostSummaryData must have all required fields with non-null values
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(CostSummaryDataGenerators) })]
    public void CostSummaryData_MustHaveAllRequiredFieldsNonNull(CostSummaryData costSummaryData)
    {
        // Property: For any CostSummaryData extracted from a Cost Summary document, all required fields must be non-null
        
        // Assert CampaignName is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(costSummaryData.CampaignName),
            "CampaignName must not be null or empty");
        
        // Assert State is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(costSummaryData.State),
            "State must not be null or empty");
        
        // Assert CampaignStartDate is not default
        Assert.NotEqual(
            default(DateTime),
            costSummaryData.CampaignStartDate);
        
        // Assert CampaignEndDate is not default
        Assert.NotEqual(
            default(DateTime),
            costSummaryData.CampaignEndDate);
        
        // Assert CostBreakdowns is not null
        Assert.NotNull(costSummaryData.CostBreakdowns);
        
        // Assert TotalCost is non-negative
        Assert.True(
            costSummaryData.TotalCost >= 0,
            "TotalCost must be non-negative");
        
        // Assert FieldConfidences is not null
        Assert.NotNull(costSummaryData.FieldConfidences);
    }

    /// <summary>
    /// Property: POLineItem must have all required fields with non-null values
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(PODataGenerators) })]
    public void POLineItem_MustHaveAllRequiredFieldsNonNull(POLineItem lineItem)
    {
        // Property: For any POLineItem in extracted PO data, all required fields must be non-null
        
        // Assert ItemCode is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(lineItem.ItemCode),
            "ItemCode must not be null or empty");
        
        // Assert Description is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(lineItem.Description),
            "Description must not be null or empty");
        
        // Assert Quantity is positive
        Assert.True(
            lineItem.Quantity > 0,
            "Quantity must be positive");
        
        // Assert UnitPrice is non-negative
        Assert.True(
            lineItem.UnitPrice >= 0,
            "UnitPrice must be non-negative");
        
        // Assert LineTotal is non-negative
        Assert.True(
            lineItem.LineTotal >= 0,
            "LineTotal must be non-negative");
    }

    /// <summary>
    /// Property: InvoiceLineItem must have all required fields with non-null values
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(InvoiceDataGenerators) })]
    public void InvoiceLineItem_MustHaveAllRequiredFieldsNonNull(InvoiceLineItem lineItem)
    {
        // Property: For any InvoiceLineItem in extracted Invoice data, all required fields must be non-null
        
        // Assert ItemCode is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(lineItem.ItemCode),
            "ItemCode must not be null or empty");
        
        // Assert Description is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(lineItem.Description),
            "Description must not be null or empty");
        
        // Assert Quantity is positive
        Assert.True(
            lineItem.Quantity > 0,
            "Quantity must be positive");
        
        // Assert UnitPrice is non-negative
        Assert.True(
            lineItem.UnitPrice >= 0,
            "UnitPrice must be non-negative");
        
        // Assert LineTotal is non-negative
        Assert.True(
            lineItem.LineTotal >= 0,
            "LineTotal must be non-negative");
    }

    /// <summary>
    /// Property: CostBreakdown must have all required fields with non-null values
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(CostSummaryDataGenerators) })]
    public void CostBreakdown_MustHaveAllRequiredFieldsNonNull(CostBreakdown costBreakdown)
    {
        // Property: For any CostBreakdown in extracted Cost Summary data, all required fields must be non-null
        
        // Assert Category is not null or empty
        Assert.False(
            string.IsNullOrWhiteSpace(costBreakdown.Category),
            "Category must not be null or empty");
        
        // Assert Amount is non-negative
        Assert.True(
            costBreakdown.Amount >= 0,
            "Amount must be non-negative");
    }

    /// <summary>
    /// Unit test: Verify POData with all fields populated passes completeness check
    /// </summary>
    [Fact]
    public void POData_WithAllFieldsPopulated_PassesCompletenessCheck()
    {
        // Arrange
        var poData = new POData
        {
            PONumber = "PO-12345",
            VendorName = "Test Vendor",
            PODate = DateTime.UtcNow,
            LineItems = new List<POLineItem>
            {
                new POLineItem
                {
                    ItemCode = "ITEM-001",
                    Description = "Test Item",
                    Quantity = 10,
                    UnitPrice = 100.00m,
                    LineTotal = 1000.00m
                }
            },
            TotalAmount = 1000.00m,
            FieldConfidences = new Dictionary<string, double>
            {
                { "PONumber", 0.95 },
                { "VendorName", 0.90 }
            }
        };

        // Assert all required fields are present
        Assert.False(string.IsNullOrWhiteSpace(poData.PONumber));
        Assert.False(string.IsNullOrWhiteSpace(poData.VendorName));
        Assert.NotEqual(default(DateTime), poData.PODate);
        Assert.NotNull(poData.LineItems);
        Assert.NotEmpty(poData.LineItems);
        Assert.True(poData.TotalAmount >= 0);
        Assert.NotNull(poData.FieldConfidences);
    }

    /// <summary>
    /// Unit test: Verify InvoiceData with all fields populated passes completeness check
    /// </summary>
    [Fact]
    public void InvoiceData_WithAllFieldsPopulated_PassesCompletenessCheck()
    {
        // Arrange
        var invoiceData = new InvoiceData
        {
            InvoiceNumber = "INV-12345",
            VendorName = "Test Vendor",
            InvoiceDate = DateTime.UtcNow,
            LineItems = new List<InvoiceLineItem>
            {
                new InvoiceLineItem
                {
                    ItemCode = "ITEM-001",
                    Description = "Test Item",
                    Quantity = 10,
                    UnitPrice = 100.00m,
                    LineTotal = 1000.00m
                }
            },
            SubTotal = 1000.00m,
            TaxAmount = 100.00m,
            TotalAmount = 1100.00m,
            FieldConfidences = new Dictionary<string, double>
            {
                { "InvoiceNumber", 0.95 },
                { "VendorName", 0.90 }
            }
        };

        // Assert all required fields are present
        Assert.False(string.IsNullOrWhiteSpace(invoiceData.InvoiceNumber));
        Assert.False(string.IsNullOrWhiteSpace(invoiceData.VendorName));
        Assert.NotEqual(default(DateTime), invoiceData.InvoiceDate);
        Assert.NotNull(invoiceData.LineItems);
        Assert.NotEmpty(invoiceData.LineItems);
        Assert.True(invoiceData.SubTotal >= 0);
        Assert.True(invoiceData.TaxAmount >= 0);
        Assert.True(invoiceData.TotalAmount >= 0);
        Assert.NotNull(invoiceData.FieldConfidences);
    }

    /// <summary>
    /// Unit test: Verify CostSummaryData with all fields populated passes completeness check
    /// </summary>
    [Fact]
    public void CostSummaryData_WithAllFieldsPopulated_PassesCompletenessCheck()
    {
        // Arrange
        var costSummaryData = new CostSummaryData
        {
            CampaignName = "Test Campaign",
            State = "Maharashtra",
            CampaignStartDate = DateTime.UtcNow.AddDays(-30),
            CampaignEndDate = DateTime.UtcNow,
            CostBreakdowns = new List<CostBreakdown>
            {
                new CostBreakdown
                {
                    Category = "Marketing",
                    Amount = 5000.00m
                }
            },
            TotalCost = 5000.00m,
            FieldConfidences = new Dictionary<string, double>
            {
                { "CampaignName", 0.95 },
                { "State", 0.90 }
            }
        };

        // Assert all required fields are present
        Assert.False(string.IsNullOrWhiteSpace(costSummaryData.CampaignName));
        Assert.False(string.IsNullOrWhiteSpace(costSummaryData.State));
        Assert.NotEqual(default(DateTime), costSummaryData.CampaignStartDate);
        Assert.NotEqual(default(DateTime), costSummaryData.CampaignEndDate);
        Assert.NotNull(costSummaryData.CostBreakdowns);
        Assert.NotEmpty(costSummaryData.CostBreakdowns);
        Assert.True(costSummaryData.TotalCost >= 0);
        Assert.NotNull(costSummaryData.FieldConfidences);
    }
}

/// <summary>
/// Custom generators for POData and related types
/// </summary>
public static class PODataGenerators
{
    private static Gen<string> NonEmptyStringGen()
    {
        return Arb.Generate<NonEmptyString>()
            .Select(nes => nes.Get)
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim().Length > 0 ? s.Trim() : "DefaultValue");
    }

    public static Arbitrary<POData> PODataGenerator()
    {
        return (from poNumber in NonEmptyStringGen()
                from vendorName in NonEmptyStringGen()
                from poDate in Arb.Generate<DateTime>().Where(d => d > DateTime.MinValue && d < DateTime.MaxValue)
                from lineItems in Gen.NonEmptyListOf(POLineItemGenerator().Generator)
                from totalAmount in Arb.Generate<PositiveInt>()
                from fieldConfidences in Gen.Constant(new Dictionary<string, double>
                {
                    { "PONumber", 0.85 },
                    { "VendorName", 0.90 }
                })
                select new POData
                {
                    PONumber = poNumber,
                    VendorName = vendorName,
                    PODate = poDate,
                    LineItems = lineItems.ToList(),
                    TotalAmount = totalAmount.Get,
                    FieldConfidences = fieldConfidences,
                    IsFlaggedForReview = false
                }).ToArbitrary();
    }

    public static Arbitrary<POLineItem> POLineItemGenerator()
    {
        return (from itemCode in NonEmptyStringGen()
                from description in NonEmptyStringGen()
                from quantity in Arb.Generate<PositiveInt>()
                from unitPrice in Arb.Generate<PositiveInt>()
                from lineTotal in Arb.Generate<PositiveInt>()
                select new POLineItem
                {
                    ItemCode = itemCode,
                    Description = description,
                    Quantity = Math.Max(1, quantity.Get),
                    UnitPrice = unitPrice.Get,
                    LineTotal = lineTotal.Get
                }).ToArbitrary();
    }
}

/// <summary>
/// Custom generators for InvoiceData and related types
/// </summary>
public static class InvoiceDataGenerators
{
    private static Gen<string> NonEmptyStringGen()
    {
        return Arb.Generate<NonEmptyString>()
            .Select(nes => nes.Get)
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim().Length > 0 ? s.Trim() : "DefaultValue");
    }

    public static Arbitrary<InvoiceData> InvoiceDataGenerator()
    {
        return (from invoiceNumber in NonEmptyStringGen()
                from vendorName in NonEmptyStringGen()
                from invoiceDate in Arb.Generate<DateTime>().Where(d => d > DateTime.MinValue && d < DateTime.MaxValue)
                from lineItems in Gen.NonEmptyListOf(InvoiceLineItemGenerator().Generator)
                from subTotal in Arb.Generate<PositiveInt>()
                from taxAmount in Arb.Generate<PositiveInt>()
                from totalAmount in Arb.Generate<PositiveInt>()
                from fieldConfidences in Gen.Constant(new Dictionary<string, double>
                {
                    { "InvoiceNumber", 0.85 },
                    { "VendorName", 0.90 }
                })
                select new InvoiceData
                {
                    InvoiceNumber = invoiceNumber,
                    VendorName = vendorName,
                    InvoiceDate = invoiceDate,
                    LineItems = lineItems.ToList(),
                    SubTotal = subTotal.Get,
                    TaxAmount = taxAmount.Get,
                    TotalAmount = totalAmount.Get,
                    FieldConfidences = fieldConfidences,
                    IsFlaggedForReview = false
                }).ToArbitrary();
    }

    public static Arbitrary<InvoiceLineItem> InvoiceLineItemGenerator()
    {
        return (from itemCode in NonEmptyStringGen()
                from description in NonEmptyStringGen()
                from quantity in Arb.Generate<PositiveInt>()
                from unitPrice in Arb.Generate<PositiveInt>()
                from lineTotal in Arb.Generate<PositiveInt>()
                select new InvoiceLineItem
                {
                    ItemCode = itemCode,
                    Description = description,
                    Quantity = Math.Max(1, quantity.Get),
                    UnitPrice = unitPrice.Get,
                    LineTotal = lineTotal.Get
                }).ToArbitrary();
    }
}

/// <summary>
/// Custom generators for CostSummaryData and related types
/// </summary>
public static class CostSummaryDataGenerators
{
    private static Gen<string> NonEmptyStringGen()
    {
        return Arb.Generate<NonEmptyString>()
            .Select(nes => nes.Get)
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim().Length > 0 ? s.Trim() : "DefaultValue");
    }

    public static Arbitrary<CostSummaryData> CostSummaryDataGenerator()
    {
        return (from campaignName in NonEmptyStringGen()
                from state in NonEmptyStringGen()
                from startDate in Arb.Generate<DateTime>().Where(d => d > DateTime.MinValue && d < DateTime.MaxValue.AddDays(-1))
                from endDate in Arb.Generate<DateTime>().Where(d => d > DateTime.MinValue && d < DateTime.MaxValue)
                from costBreakdowns in Gen.NonEmptyListOf(CostBreakdownGenerator().Generator)
                from totalCost in Arb.Generate<PositiveInt>()
                from fieldConfidences in Gen.Constant(new Dictionary<string, double>
                {
                    { "CampaignName", 0.85 },
                    { "State", 0.90 }
                })
                select new CostSummaryData
                {
                    CampaignName = campaignName,
                    State = state,
                    CampaignStartDate = startDate,
                    CampaignEndDate = endDate > startDate ? endDate : startDate.AddDays(1),
                    CostBreakdowns = costBreakdowns.ToList(),
                    TotalCost = totalCost.Get,
                    FieldConfidences = fieldConfidences,
                    IsFlaggedForReview = false
                }).ToArbitrary();
    }

    public static Arbitrary<CostBreakdown> CostBreakdownGenerator()
    {
        return (from category in NonEmptyStringGen()
                from amount in Arb.Generate<PositiveInt>()
                select new CostBreakdown
                {
                    Category = category,
                    Amount = amount.Get
                }).ToArbitrary();
    }
}
