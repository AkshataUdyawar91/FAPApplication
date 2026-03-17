using System.Net;
using System.Text;
using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.PO;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Fetches PO data from the SAP PO_Data API and calculates:
/// Balance = Sum(po_line_item.price_without_tax) - Sum(gr_data.invoice_value)
/// </summary>
public class PoBalanceService : IPoBalanceService
{
    private readonly ILogger<PoBalanceService> _logger;

    private const string SapApiUrl = "https://agni.bajajauto.co.in:7782/RESTAdapter/QAS/Datamatics/PO_Data";
    private const string SapApiKey = "HhqsAGywilqBONDhzOZTsGmrYNHFCwrTwLgnPTSFwfEGyjyOGaTDMeiomfVUeVEn";
    private const string SapBasicAuth = "Basic cGljb25uOmJhamFqQDEyMw==";
    private const string SapCookie = "saplb_*=(J2EE3965820)3965850";

    public PoBalanceService(ILogger<PoBalanceService> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<PoBalanceResponse> GetPoBalanceAsync(
        string companyCode,
        string poNum,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Fetching PO data from SAP for company={CompanyCode} po={PoNum}", companyCode, poNum);

        var responseJson = await CallSapApiAsync(companyCode, poNum, cancellationToken);
        return CalculateBalance(poNum, responseJson);
    }

    private async Task<JsonElement> CallSapApiAsync(string companyCode, string poNum, CancellationToken cancellationToken)
    {
        // Use a handler that bypasses SSL validation for the SAP host (self-signed cert)
        using var handler = new HttpClientHandler
        {
            ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator
        };
        using var client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(30) };

        var requestBody = JsonSerializer.Serialize(new
        {
            request = new
            {
                company_code = companyCode,
                po_num = poNum,
                po_line_item = "",
                request_type = "3"
            }
        });

        // The curl uses --request GET with --data, which sends a GET with a body.
        // .NET HttpClient requires HttpMethod with content explicitly set.
        var request = new HttpRequestMessage(HttpMethod.Get, SapApiUrl)
        {
            Content = new StringContent(requestBody, Encoding.UTF8, "application/json")
        };

        request.Headers.TryAddWithoutValidation("api-key", SapApiKey);
        request.Headers.TryAddWithoutValidation("Authorization", SapBasicAuth);
        request.Headers.TryAddWithoutValidation("Cookie", SapCookie);

        HttpResponseMessage httpResponse;
        string responseText;

        try
        {
            httpResponse = await client.SendAsync(request, cancellationToken);
            responseText = await httpResponse.Content.ReadAsStringAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SAP API call failed for PO {PoNum}", poNum);
            throw new InvalidOperationException($"Failed to reach SAP API: {ex.Message}", ex);
        }

        _logger.LogDebug("SAP response HTTP {Status} for PO {PoNum}: {Body}", httpResponse.StatusCode, poNum, responseText);

        if (!httpResponse.IsSuccessStatusCode)
        {
            _logger.LogError("SAP API returned HTTP {Status} for PO {PoNum}: {Body}", httpResponse.StatusCode, poNum, responseText);
            throw new InvalidOperationException($"SAP API error (HTTP {(int)httpResponse.StatusCode}): {responseText}");
        }

        try
        {
            return JsonDocument.Parse(responseText).RootElement.Clone();
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse SAP response for PO {PoNum}: {Body}", poNum, responseText);
            throw new InvalidOperationException("SAP API returned an invalid JSON response.", ex);
        }
    }

    private PoBalanceResponse CalculateBalance(string poNum, JsonElement root)
    {
        var response = root.GetProperty("response");

        var status = response.GetProperty("status").GetString();
        if (!string.Equals(status, "S", StringComparison.Ordinal))
        {
            var remarks = response.GetProperty("remarks").GetString() ?? "Unknown SAP error";
            _logger.LogWarning("SAP returned non-success status for PO {PoNum}: {Remarks}", poNum, remarks);
            throw new InvalidOperationException($"SAP error: {remarks}");
        }

        var lineItems = response.GetProperty("data").GetProperty("po_line_item");

        decimal totalPrice = 0m;
        decimal totalInvoiced = 0m;
        string currency = "UNKNOWN";

        foreach (var item in lineItems.EnumerateArray())
        {
            if (decimal.TryParse(item.GetProperty("price_without_tax").GetString()?.Trim(), out var price))
                totalPrice += price;

            if (string.Equals(currency, "UNKNOWN", StringComparison.Ordinal))
            {
                var cur = item.GetProperty("currency").GetString() ?? "";
                if (!string.IsNullOrWhiteSpace(cur))
                    currency = cur;
            }

            if (item.TryGetProperty("gr_data", out var grData))
            {
                foreach (var gr in grData.EnumerateArray())
                {
                    if (decimal.TryParse(gr.GetProperty("invoice_value").GetString()?.Trim(), out var inv))
                        totalInvoiced += inv;
                }
            }
        }

        totalInvoiced = totalInvoiced / 1.18m;

        var balance = Math.Round(totalPrice - totalInvoiced, 2);

        _logger.LogInformation(
            "PO {PoNum} balance: {Currency} {Balance} (prices={TotalPrice}, invoiced={TotalInvoiced})",
            poNum, currency, balance, totalPrice, totalInvoiced);

        return new PoBalanceResponse
        {
            // PoNum = poNum,
            Balance = balance,
            // Currency = currency,
            CalculatedAt = DateTime.UtcNow
        };
    }
}
