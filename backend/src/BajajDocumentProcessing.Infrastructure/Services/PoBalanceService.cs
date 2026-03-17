using System.Text;
using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.PO;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Fetches PO data from the SAP PO_Data API and calculates:
/// Balance = Sum(po_line_item.price_without_tax) - Sum(gr_data.invoice_value)
/// Credentials are read from configuration (SAP:PoData section) — never hardcoded.
/// </summary>
public class PoBalanceService : IPoBalanceService
{
    private readonly ILogger<PoBalanceService> _logger;
    private readonly string _sapUrl;
    private readonly string _sapApiKey;
    private readonly string _sapBasicAuth;
    private readonly string _sapCookie;

    public PoBalanceService(IConfiguration configuration, ILogger<PoBalanceService> logger)
    {
        _logger = logger;
        _sapUrl      = configuration["SAP:PoData:Url"]       ?? throw new InvalidOperationException("SAP:PoData:Url is not configured.");
        _sapApiKey   = configuration["SAP:PoData:ApiKey"]    ?? throw new InvalidOperationException("SAP:PoData:ApiKey is not configured.");
        _sapBasicAuth = configuration["SAP:PoData:BasicAuth"] ?? throw new InvalidOperationException("SAP:PoData:BasicAuth is not configured.");
        _sapCookie   = configuration["SAP:PoData:Cookie"]    ?? string.Empty;
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
        // SAP host uses a self-signed certificate — bypass SSL validation for this client only
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

        // SAP endpoint uses GET with a body (mirrors the curl --request GET --data pattern)
        var request = new HttpRequestMessage(HttpMethod.Get, _sapUrl)
        {
            Content = new StringContent(requestBody, Encoding.UTF8, "application/json")
        };

        request.Headers.TryAddWithoutValidation("api-key", _sapApiKey);
        request.Headers.TryAddWithoutValidation("Authorization", _sapBasicAuth);

        if (!string.IsNullOrEmpty(_sapCookie))
            request.Headers.TryAddWithoutValidation("Cookie", _sapCookie);

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
