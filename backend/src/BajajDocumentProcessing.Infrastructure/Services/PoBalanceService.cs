using System.Diagnostics;
using System.Text;
using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.PO;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Fetches PO data from the SAP PO_Data API, calculates the balance, and
/// persists a full audit record to the POBalanceLogs table.
/// Balance = Sum(po_line_item.price_without_tax) - Sum(gr_data.invoice_value)
/// </summary>
public class PoBalanceService : IPoBalanceService
{
    private readonly IApplicationDbContext _db;
    private readonly ILogger<PoBalanceService> _logger;
    private readonly string _sapUrl;
    private readonly string _sapApiKey;
    private readonly string _sapBasicAuth;
    private readonly string _sapCookie;

    public PoBalanceService(
        IApplicationDbContext db,
        IConfiguration configuration,
        ILogger<PoBalanceService> logger)
    {
        _db = db;
        _logger = logger;
        _sapUrl       = configuration["SAP:PoBalanceApi:Url"]       ?? throw new InvalidOperationException("SAP:PoBalanceApi:Url is not configured.");
        _sapApiKey    = configuration["SAP:PoBalanceApi:ApiKey"]    ?? throw new InvalidOperationException("SAP:PoBalanceApi:ApiKey is not configured.");
        _sapBasicAuth = configuration["SAP:PoBalanceApi:BasicAuth"] ?? throw new InvalidOperationException("SAP:PoBalanceApi:BasicAuth is not configured.");
        _sapCookie    = configuration["SAP:PoBalanceApi:Cookie"]    ?? string.Empty;
    }

    /// <inheritdoc />
    public async Task<PoBalanceResponse> GetPoBalanceAsync(
        string companyCode,
        string poNum,
        string? requestedBy = null,
        string? correlationId = null,
        CancellationToken cancellationToken = default)
    {
        var log = new PoBalanceLog
        {
            Id            = Guid.NewGuid(),
            PoNum         = poNum,
            CompanyCode   = companyCode,
            RequestedBy   = requestedBy,
            RequestedAt   = DateTime.UtcNow,
            CorrelationId = correlationId
        };

        var sw = Stopwatch.StartNew();

        try
        {
            _logger.LogInformation("Fetching PO balance for company={CompanyCode} po={PoNum}", companyCode, poNum);

            var (responseJson, sapRequestBody, sapCalledAt, sapRespondedAt, sapHttpStatus, sapResponseBody)
                = await CallSapApiAsync(companyCode, poNum, cancellationToken);

            log.SapRequestBody  = sapRequestBody;
            log.SapCalledAt     = sapCalledAt;
            log.SapRespondedAt  = sapRespondedAt;
            log.SapHttpStatus   = sapHttpStatus;
            log.SapResponseBody = sapResponseBody?.Length > 4000 ? sapResponseBody[..4000] : sapResponseBody;

            var result = CalculateBalance(poNum, responseJson);

            log.Balance   = result.Balance;
            log.Currency  = result.Currency;
            log.IsSuccess = true;

            // Write RemainingBalance and RefreshedAt back to the POs table
            await UpdatePoRemainingBalanceAsync(poNum, result.Balance, result.CalculatedAt, cancellationToken);

            return result;
        }
        catch (Exception ex)
        {
            log.IsSuccess    = false;
            log.ErrorMessage = ex.Message;
            _logger.LogError(ex, "PO balance failed for PO {PoNum}", poNum);
            throw;
        }
        finally
        {
            sw.Stop();
            log.ElapsedMs = sw.ElapsedMilliseconds;

            try
            {
                _db.POBalanceLogs.Add(log);
                await _db.SaveChangesAsync(cancellationToken);
            }
            catch (Exception dbEx)
            {
                _logger.LogError(dbEx, "Failed to persist POBalanceLog for PO {PoNum}", poNum);
            }
        }
    }

    /// <summary>
    /// Updates RemainingBalance and RefreshedAt on the matching PO row.
    /// Failures are swallowed so they never break the primary balance response.
    /// </summary>
    private async Task UpdatePoRemainingBalanceAsync(
        string poNum,
        decimal balance,
        DateTime refreshedAt,
        CancellationToken cancellationToken)
    {
        try
        {
            var po = await _db.POs
                .FirstOrDefaultAsync(p => p.PONumber == poNum && !p.IsDeleted, cancellationToken);

            if (po == null)
            {
                _logger.LogWarning("PO {PoNum} not found in POs table — skipping balance write-back", poNum);
                return;
            }

            po.RemainingBalance = balance;
            po.RefreshedAt      = refreshedAt;

            await _db.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Updated POs table for PO {PoNum}: RemainingBalance={Balance}, RefreshedAt={RefreshedAt}",
                poNum, balance, refreshedAt);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to write balance back to POs table for PO {PoNum}", poNum);
        }
    }

    private async Task<(JsonElement root, string requestBody, DateTime calledAt, DateTime respondedAt, int httpStatus, string responseText)>
        CallSapApiAsync(string companyCode, string poNum, CancellationToken cancellationToken)
    {
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
                po_num       = poNum,
                po_line_item = "",
                request_type = "3"
            }
        });

        var calledAt = DateTime.UtcNow;
        HttpResponseMessage httpResponse;
        string responseText;

        try
        {
            // Try POST first — SAP ICM needs a body and POST is the correct semantic
            httpResponse = await client.SendAsync(BuildRequest(HttpMethod.Post, requestBody), cancellationToken);
            responseText = await httpResponse.Content.ReadAsStringAsync(cancellationToken);

            // Fall back to GET with body if POST is rejected (matches original curl --request GET --data)
            if (httpResponse.StatusCode == System.Net.HttpStatusCode.MethodNotAllowed
                || httpResponse.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                _logger.LogWarning("POST returned {Status} for SAP PO_Data, retrying as GET with body", httpResponse.StatusCode);
                httpResponse = await client.SendAsync(BuildRequest(HttpMethod.Get, requestBody), cancellationToken);
                responseText = await httpResponse.Content.ReadAsStringAsync(cancellationToken);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SAP API unreachable for PO {PoNum}", poNum);
            throw new InvalidOperationException($"Failed to reach SAP API: {ex.Message}", ex);
        }

        var respondedAt = DateTime.UtcNow;
        var httpStatus  = (int)httpResponse.StatusCode;

        _logger.LogDebug("SAP HTTP {Status} for PO {PoNum}: {Body}", httpStatus, poNum, responseText);

        if (!httpResponse.IsSuccessStatusCode)
        {
            _logger.LogError("SAP returned HTTP {Status} for PO {PoNum}", httpStatus, poNum);
            throw new InvalidOperationException($"SAP API error (HTTP {httpStatus}): {responseText}");
        }

        try
        {
            var root = JsonDocument.Parse(responseText).RootElement.Clone();
            return (root, requestBody, calledAt, respondedAt, httpStatus, responseText);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Invalid JSON from SAP for PO {PoNum}", poNum);
            throw new InvalidOperationException("SAP API returned an invalid JSON response.", ex);
        }
    }

    /// <summary>
    /// Normalises a JsonElement that may be either a JSON array or a JSON object
    /// into an enumerable of JsonElement values.
    /// </summary>
    private static IEnumerable<JsonElement> EnumerateArrayOrObject(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Array)
            return element.EnumerateArray();
        if (element.ValueKind == JsonValueKind.Object)
            return new[] { element };
        return Enumerable.Empty<JsonElement>();
    }

    private HttpRequestMessage BuildRequest(HttpMethod method, string body)
    {
        var req = new HttpRequestMessage(method, _sapUrl)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json")
        };
        req.Headers.TryAddWithoutValidation("api-key", _sapApiKey);
        req.Headers.TryAddWithoutValidation("Authorization", _sapBasicAuth);
        if (!string.IsNullOrEmpty(_sapCookie))
            req.Headers.TryAddWithoutValidation("Cookie", _sapCookie);
        return req;
    }

    private PoBalanceResponse CalculateBalance(string poNum, JsonElement root)
    {
        var response = root.GetProperty("response");
        var status   = response.GetProperty("status").GetString();

        if (!string.Equals(status, "S", StringComparison.Ordinal))
        {
            var remarks = response.GetProperty("remarks").GetString() ?? "Unknown SAP error";
            throw new InvalidOperationException($"SAP error: {remarks}");
        }

        var lineItems     = response.GetProperty("data").GetProperty("po_line_item");
        decimal totalPrice    = 0m;
        decimal totalInvoiced = 0m;
        string  currency      = "UNKNOWN";

        foreach (var item in EnumerateArrayOrObject(lineItems))
        {
            if (decimal.TryParse(item.GetProperty("price_without_tax").GetString()?.Trim(), out var price))
                totalPrice += price;

            if (string.Equals(currency, "UNKNOWN", StringComparison.Ordinal))
            {
                var cur = item.GetProperty("currency").GetString() ?? "";
                if (!string.IsNullOrWhiteSpace(cur)) currency = cur;
            }

            if (item.TryGetProperty("gr_data", out var grData))
                foreach (var gr in EnumerateArrayOrObject(grData))
                    if (decimal.TryParse(gr.GetProperty("invoice_value").GetString()?.Trim(), out var inv))
                        totalInvoiced += inv;
        }

        var balance = Math.Round(totalPrice - totalInvoiced, 2);

        _logger.LogInformation(
            "PO {PoNum} balance: {Currency} {Balance} (prices={TotalPrice}, invoiced={TotalInvoiced})",
            poNum, currency, balance, totalPrice, totalInvoiced);

        return new PoBalanceResponse
        {
            PoNum        = poNum,
            Balance      = balance,
            Currency     = currency,
            CalculatedAt = DateTime.UtcNow
        };
    }
}
