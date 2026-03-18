using System.Reflection;
using System.Text;
using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.PO;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 2: Preservation — Array-shaped po_line_item behaviour is unchanged.
/// Validates: Requirements 3.1, 3.2, 3.3, 3.4
///
/// For any N-item array payload (N >= 0), CalculateBalance returns a PoBalanceResponse where:
/// - balance = sum(price_without_tax) - sum(invoice_value across all gr_data entries)
/// - No exception is thrown
/// - Currency is taken from the first non-empty currency field
/// </summary>
public class PoLineItemTypeHandlingProperties
{
    private readonly PoBalanceService _service;
    private readonly MethodInfo _calculateBalance;

    public PoLineItemTypeHandlingProperties()
    {
        var mockDb = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<PoBalanceService>>();
        var mockConfig = new Mock<IConfiguration>();
        mockConfig.Setup(c => c["SAP:PoBalanceApi:Url"]).Returns("https://dummy");
        mockConfig.Setup(c => c["SAP:PoBalanceApi:ApiKey"]).Returns("key");
        mockConfig.Setup(c => c["SAP:PoBalanceApi:BasicAuth"]).Returns("Basic x");
        mockConfig.Setup(c => c["SAP:PoBalanceApi:Cookie"]).Returns("");

        _service = new PoBalanceService(mockDb.Object, mockConfig.Object, mockLogger.Object);

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        _calculateBalance = method ?? throw new InvalidOperationException("CalculateBalance method not found via reflection.");
    }

    // -------------------------------------------------------------------------
    // Helper: invoke CalculateBalance and unwrap TargetInvocationException
    // -------------------------------------------------------------------------
    private PoBalanceResponse InvokeCalculateBalance(string poNum, JsonElement root)
    {
        try
        {
            return (PoBalanceResponse)_calculateBalance.Invoke(_service, new object[] { poNum, root })!;
        }
        catch (TargetInvocationException tie) when (tie.InnerException != null)
        {
            throw tie.InnerException;
        }
    }

    // -------------------------------------------------------------------------
    // Helper: build a SAP-shaped JSON payload with an array po_line_item
    // -------------------------------------------------------------------------
    private static string BuildArrayPayload(LineItemData[] items)
    {
        var sb = new StringBuilder();
        sb.Append("""{"response":{"status":"S","data":{"po_line_item":[""");

        for (int i = 0; i < items.Length; i++)
        {
            if (i > 0) sb.Append(',');
            var item = items[i];
            sb.Append('{');
            sb.Append($@"""price_without_tax"":""{item.Price:F2}"",");
            sb.Append($@"""currency"":""{item.Currency}"",");
            sb.Append($@"""po_num"":""4500001234"",");
            sb.Append($@"""po_line_item"":""{i + 1:D2}"",");
            sb.Append($@"""type_ind"":""L"",");
            sb.Append($@"""tax_code"":""V0""");

            if (item.GrEntries != null && item.GrEntries.Length > 0)
            {
                sb.Append(@",""gr_data"":[");
                for (int g = 0; g < item.GrEntries.Length; g++)
                {
                    if (g > 0) sb.Append(',');
                    sb.Append($@"{{""invoice_value"":""{item.GrEntries[g]:F2}""}}");
                }
                sb.Append(']');
            }

            sb.Append('}');
        }

        sb.Append("""]}}}""");
        return sb.ToString();
    }

    // -------------------------------------------------------------------------
    // Helper: compute expected balance from the same data
    // -------------------------------------------------------------------------
    private static decimal ExpectedBalance(LineItemData[] items)
    {
        decimal totalPrice = items.Sum(i => i.Price);
        decimal totalInvoiced = items
            .Where(i => i.GrEntries != null)
            .SelectMany(i => i.GrEntries!)
            .Sum();
        return Math.Round(totalPrice - totalInvoiced, 2);
    }

    private static string ExpectedCurrency(LineItemData[] items)
    {
        foreach (var item in items)
            if (!string.IsNullOrWhiteSpace(item.Currency))
                return item.Currency;
        return "UNKNOWN";
    }

    // -------------------------------------------------------------------------
    // Property 2: Preservation
    // Validates: Requirements 3.1, 3.2, 3.3, 3.4
    // -------------------------------------------------------------------------

    /// <summary>
    /// Property 2: Preservation — Array-shaped po_line_item behaviour is unchanged.
    /// For any N-item array payload (N >= 0), CalculateBalance returns the correct balance
    /// without throwing, confirming the existing array path is the baseline to preserve.
    /// </summary>
    [Property(MaxTest = 100)]
    public Property ArrayShapedPoLineItem_BalanceEqualsExpected(
        NonNegativeInt itemCount,
        NonNegativeInt[] rawPrices,
        NonNegativeInt[] rawInvoices)
    {
        // Constrain item count to 0–10
        int n = itemCount.Get % 11;

        // Build line items — each item gets one price; distribute invoices across items
        var items = new LineItemData[n];
        for (int i = 0; i < n; i++)
        {
            decimal price = rawPrices.Length > 0
                ? (rawPrices[i % rawPrices.Length].Get % 10000) / 100m
                : 0m;

            // Give each item 0–2 gr_data entries
            decimal[]? grEntries = null;
            if (rawInvoices.Length > 0)
            {
                int grCount = (i < rawInvoices.Length ? rawInvoices[i].Get % 3 : 0);
                if (grCount > 0)
                {
                    grEntries = new decimal[grCount];
                    for (int g = 0; g < grCount; g++)
                    {
                        int idx = (i * 3 + g) % rawInvoices.Length;
                        grEntries[g] = (rawInvoices[idx].Get % 10000) / 100m;
                    }
                }
            }

            items[i] = new LineItemData(price, "INR", grEntries);
        }

        var json = BuildArrayPayload(items);
        var root = JsonDocument.Parse(json).RootElement.Clone();

        PoBalanceResponse result;
        try
        {
            result = InvokeCalculateBalance("4500001234", root);
        }
        catch (Exception ex)
        {
            return false.ToProperty()
                .Label($"CalculateBalance threw unexpectedly: {ex.GetType().Name}: {ex.Message}");
        }

        var expectedBalance = ExpectedBalance(items);
        var balanceMatches = result.Balance == expectedBalance;
        var currencyMatches = n == 0
            ? result.Currency == "UNKNOWN"
            : result.Currency == ExpectedCurrency(items);

        return (balanceMatches && currencyMatches).ToProperty()
            .Label($"Items={n}, ExpectedBalance={expectedBalance}, ActualBalance={result.Balance}, " +
                   $"ExpectedCurrency={ExpectedCurrency(items)}, ActualCurrency={result.Currency}");
    }

    // -------------------------------------------------------------------------
    // Concrete [Fact] tests
    // -------------------------------------------------------------------------

    /// <summary>
    /// Multi-item array: 3 items, each with a price, no gr_data → balance = sum of prices.
    /// </summary>
    [Fact]
    public void CalculateBalance_MultiItemArray_NoGrData_BalanceEqualsSumOfPrices()
    {
        var items = new[]
        {
            new LineItemData(100.00m, "INR", null),
            new LineItemData(200.50m, "INR", null),
            new LineItemData(300.75m, "INR", null),
        };

        var json = BuildArrayPayload(items);
        var root = JsonDocument.Parse(json).RootElement.Clone();

        var result = InvokeCalculateBalance("4500001234", root);

        Assert.Equal(601.25m, result.Balance);
        Assert.Equal("INR", result.Currency);
    }

    /// <summary>
    /// Single-element array: 1 item, price = 500.00, no gr_data → balance = 500.00.
    /// </summary>
    [Fact]
    public void CalculateBalance_SingleElementArray_NoGrData_BalanceEqualsPrice()
    {
        var items = new[]
        {
            new LineItemData(500.00m, "INR", null),
        };

        var json = BuildArrayPayload(items);
        var root = JsonDocument.Parse(json).RootElement.Clone();

        var result = InvokeCalculateBalance("4500001234", root);

        Assert.Equal(500.00m, result.Balance);
        Assert.Equal("INR", result.Currency);
    }

    /// <summary>
    /// Empty array: 0 items → balance = 0, no exception.
    /// </summary>
    [Fact]
    public void CalculateBalance_EmptyArray_BalanceIsZero()
    {
        var items = Array.Empty<LineItemData>();

        var json = BuildArrayPayload(items);
        var root = JsonDocument.Parse(json).RootElement.Clone();

        var result = InvokeCalculateBalance("4500001234", root);

        Assert.Equal(0m, result.Balance);
    }

    /// <summary>
    /// Array with gr_data arrays: 2 items each with 1 gr_data entry
    /// → balance = sum(prices) - sum(invoices).
    /// </summary>
    [Fact]
    public void CalculateBalance_ArrayWithGrDataArrays_BalanceEqualsPricesMinusInvoices()
    {
        var items = new[]
        {
            new LineItemData(1000.00m, "INR", new[] { 200.00m }),
            new LineItemData(500.00m,  "INR", new[] { 100.00m }),
        };

        var json = BuildArrayPayload(items);
        var root = JsonDocument.Parse(json).RootElement.Clone();

        var result = InvokeCalculateBalance("4500001234", root);

        // balance = (1000 + 500) - (200 + 100) = 1200
        Assert.Equal(1200.00m, result.Balance);
        Assert.Equal("INR", result.Currency);
    }

    // -------------------------------------------------------------------------
    // Internal data carrier
    // -------------------------------------------------------------------------
    private sealed record LineItemData(decimal Price, string Currency, decimal[]? GrEntries);
}
