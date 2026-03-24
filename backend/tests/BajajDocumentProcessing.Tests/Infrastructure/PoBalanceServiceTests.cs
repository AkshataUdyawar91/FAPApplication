using System.Reflection;
using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.PO;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Bug condition exploration tests for PoBalanceService.CalculateBalance.
/// These tests are EXPECTED TO FAIL on unfixed code — the failure confirms the bug exists.
/// Bug: CalculateBalance calls EnumerateArray() unconditionally on po_line_item and gr_data,
/// which throws InvalidOperationException when SAP returns those fields as JSON objects.
/// </summary>
public class PoBalanceServiceTests
{
    private readonly PoBalanceService _service;

    public PoBalanceServiceTests()
    {
        var mockDb = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<PoBalanceService>>();

        var mockConfig = new Mock<IConfiguration>();
        mockConfig.Setup(c => c["SAP:PoBalanceApi:Url"]).Returns("https://dummy-sap-url");
        mockConfig.Setup(c => c["SAP:PoBalanceApi:ApiKey"]).Returns("dummy-key");
        mockConfig.Setup(c => c["SAP:PoBalanceApi:BasicAuth"]).Returns("Basic dummy");
        mockConfig.Setup(c => c["SAP:PoBalanceApi:Cookie"]).Returns("");

        _service = new PoBalanceService(mockDb.Object, mockConfig.Object, mockLogger.Object);
    }

    /// <summary>
    /// Bug condition 1 (post-fix): po_line_item is a JSON object (single line item).
    /// After the fix, EnumerateArrayOrObject normalises it to a single-element sequence.
    /// No exception is thrown and the correct balance is returned.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenPoLineItemIsObject_ReturnsCorrectBalance_AfterFix()
    {
        // Arrange — SAP returns po_line_item as a JSON object (single item, not array)
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": {
                    "price_without_tax": "500.00",
                    "currency": "INR",
                    "po_num": "4500001234",
                    "po_line_item": "10",
                    "type_ind": "L",
                    "tax_code": "V0"
                  }
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        // Act — fixed code must not throw
        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        // Assert — correct balance returned
        Assert.Equal(500.00m, result.Balance);
        Assert.Equal("INR", result.Currency);
        Assert.Equal("4500001234", result.PoNum);
    }

    /// <summary>
    /// Bug condition 2 (post-fix): gr_data is a JSON object (single GR entry) inside an array line item.
    /// After the fix, EnumerateArrayOrObject normalises gr_data to a single-element sequence.
    /// Balance = 500 - 100 = 400. No exception is thrown.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenGrDataIsObject_ReturnsCorrectBalance_AfterFix()
    {
        // Arrange — po_line_item is an array but gr_data is a JSON object (single GR entry)
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": [{
                    "price_without_tax": "500.00",
                    "currency": "INR",
                    "po_num": "4500001234",
                    "po_line_item": "10",
                    "type_ind": "L",
                    "tax_code": "V0",
                    "gr_data": {
                      "invoice_value": "100.00"
                    }
                  }]
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        // Act — fixed code must not throw
        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        // Assert — balance = 500 - 100 = 400
        Assert.Equal(400.00m, result.Balance);
        Assert.Equal("INR", result.Currency);
    }

    // ─── Fix-checking & preservation unit tests (Task 3.2) ───────────────────────

    /// <summary>
    /// Fix check: po_line_item is a JSON object (single item), no gr_data.
    /// After the fix, EnumerateArrayOrObject normalises it to a single-element sequence.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenPoLineItemIsObject_ReturnsCorrectBalance()
    {
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": {
                    "price_without_tax": "750.00",
                    "currency": "INR",
                    "po_num": "4500001234",
                    "po_line_item": "10",
                    "type_ind": "L",
                    "tax_code": "V0"
                  }
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        Assert.Equal(750.00m, result.Balance);
        Assert.Equal("INR", result.Currency);
        Assert.Equal("4500001234", result.PoNum);
    }

    /// <summary>
    /// Fix check: po_line_item is a JSON object and gr_data is also a JSON object.
    /// Balance = price_without_tax - invoice_value = 1000 - 250 = 750.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenPoLineItemIsObject_WithGrData_ReturnsCorrectBalance()
    {
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": {
                    "price_without_tax": "1000.00",
                    "currency": "INR",
                    "po_num": "4500001234",
                    "po_line_item": "10",
                    "type_ind": "L",
                    "tax_code": "V0",
                    "gr_data": {
                      "invoice_value": "250.00"
                    }
                  }
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        Assert.Equal(750.00m, result.Balance);
    }

    /// <summary>
    /// Preservation: po_line_item is a multi-item array (3 items), no gr_data.
    /// Balance = 100 + 200 + 300 = 600.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenPoLineItemIsArray_RemainsUnchanged()
    {
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": [
                    { "price_without_tax": "100.00", "currency": "INR", "po_num": "4500001234", "po_line_item": "10", "type_ind": "L", "tax_code": "V0" },
                    { "price_without_tax": "200.00", "currency": "INR", "po_num": "4500001234", "po_line_item": "20", "type_ind": "L", "tax_code": "V0" },
                    { "price_without_tax": "300.00", "currency": "INR", "po_num": "4500001234", "po_line_item": "30", "type_ind": "L", "tax_code": "V0" }
                  ]
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        Assert.Equal(600.00m, result.Balance);
    }

    /// <summary>
    /// Preservation: po_line_item is a single-element array (not an object).
    /// Balance = 500.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenPoLineItemIsSingleElementArray_RemainsUnchanged()
    {
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": [
                    { "price_without_tax": "500.00", "currency": "INR", "po_num": "4500001234", "po_line_item": "10", "type_ind": "L", "tax_code": "V0" }
                  ]
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        Assert.Equal(500.00m, result.Balance);
    }

    /// <summary>
    /// Fix check: po_line_item is an array but gr_data is a JSON object (single GR entry).
    /// Balance = 800 - 150 = 650.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenGrDataIsObject_ReturnsCorrectBalance()
    {
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": [
                    {
                      "price_without_tax": "800.00",
                      "currency": "INR",
                      "po_num": "4500001234",
                      "po_line_item": "10",
                      "type_ind": "L",
                      "tax_code": "V0",
                      "gr_data": {
                        "invoice_value": "150.00"
                      }
                    }
                  ]
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        Assert.Equal(650.00m, result.Balance);
    }

    /// <summary>
    /// Edge case: po_line_item is an empty array. Balance = 0, no exception thrown.
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenPoLineItemIsEmptyArray_ReturnsZeroBalance()
    {
        const string json = """
            {
              "response": {
                "status": "S",
                "data": {
                  "po_line_item": []
                }
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        var result = (PoBalanceResponse)method!.Invoke(_service, new object[] { "4500001234", root })!;

        Assert.Equal(0m, result.Balance);
    }

    /// <summary>
    /// Preservation: SAP returns a non-"S" status. CalculateBalance must throw
    /// InvalidOperationException with a message containing "SAP error".
    /// </summary>
    [Fact]
    public void CalculateBalance_WhenSapStatusIsNotS_Throws()
    {
        const string json = """
            {
              "response": {
                "status": "E",
                "remarks": "PO not found",
                "data": {}
              }
            }
            """;

        var root = JsonDocument.Parse(json).RootElement.Clone();

        var method = typeof(PoBalanceService).GetMethod(
            "CalculateBalance",
            BindingFlags.NonPublic | BindingFlags.Instance);

        Assert.NotNull(method);

        var ex = Assert.Throws<TargetInvocationException>(
            () => method!.Invoke(_service, new object[] { "4500001234", root }));

        Assert.IsType<InvalidOperationException>(ex.InnerException);
        Assert.Contains("SAP error", ex.InnerException!.Message);
    }
}
