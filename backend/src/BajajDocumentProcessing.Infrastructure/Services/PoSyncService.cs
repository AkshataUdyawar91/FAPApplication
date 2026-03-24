using System.Globalization;
using System.IO.Compression;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Fetches PO_CREATE data from the SAP JEDDOX endpoint, decodes the Base64 payload
/// (handling both raw CSV and ZIP-compressed CSV), filters rows by agency codes
/// from Agency-role users, checks for duplicates, and upserts PO records.
/// Every row outcome is audit-logged to POSyncLogs.
/// </summary>
public class PoSyncService : IPoSyncService
{
    private readonly IApplicationDbContext _db;
    private readonly ILogger<PoSyncService> _logger;
    private readonly HttpClient _http;
    private readonly string _url;
    private readonly string _apiKey;
    private readonly string _basicAuth;
    private readonly string _cookie;

    public PoSyncService(
        IApplicationDbContext db,
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration,
        ILogger<PoSyncService> logger)
    {
        _db        = db;
        _logger    = logger;
        _http      = httpClientFactory.CreateClient("SapPoCreate");
        _url       = configuration["SAP:PoCreate:Url"]       ?? throw new InvalidOperationException("SAP:PoCreate:Url is not configured.");
        _apiKey    = configuration["SAP:PoCreate:ApiKey"]    ?? throw new InvalidOperationException("SAP:PoCreate:ApiKey is not configured.");
        _basicAuth = configuration["SAP:PoCreate:BasicAuth"] ?? throw new InvalidOperationException("SAP:PoCreate:BasicAuth is not configured.");
        _cookie    = configuration["SAP:PoCreate:Cookie"]    ?? string.Empty;
    }

    /// <inheritdoc />
    public async Task<PoSyncResult> SyncAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("PO_CREATE sync started");

        // Step 1 — call SAP and get Base64 payload
        string base64Payload;
        try
        {
            base64Payload = await FetchBase64PayloadAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SAP PO_CREATE call failed");
            return new PoSyncResult(0, 0, 0, ex.Message);
        }

        // Step 2 — decode Base64 → bytes, then extract CSV (handles ZIP or raw CSV)
        string csvText;
        try
        {
            var bytes = Convert.FromBase64String(base64Payload);
            csvText = ExtractCsv(bytes);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to decode/extract CSV from SAP payload");
            return new PoSyncResult(0, 0, 0, $"Payload decode failed: {ex.Message}");
        }

        // Step 3 — parse CSV rows
        var rows = ParseCsv(csvText);
        _logger.LogInformation("Parsed {Count} rows from SAP CSV", rows.Count);

        // Step 4 — build agency code → AgencyId map from Agency-role users
        var agencyMap = await BuildAgencyMapAsync(cancellationToken);
        _logger.LogInformation("Loaded {Count} agency codes for filtering", agencyMap.Count);

        int inserted = 0, skipped = 0, failed = 0;

        foreach (var row in rows)
        {
            // Step 5 — filter: skip rows whose AgencyCode has no matching agency
            if (!agencyMap.TryGetValue(row.AgencyCode, out var agencyId))
            {
                _logger.LogDebug("AgencyCode '{Code}' not found — skipping row {PONumber}", row.AgencyCode, row.PONumber);
                await WriteSyncLogAsync(null, null, "AgencyNotFound",
                    $"AgencyCode '{row.AgencyCode}' not found in system", row, cancellationToken);
                skipped++;
                continue;
            }

            try
            {
                // Step 6 — duplicate check: (PONumber, AgencyId)
                var exists = await _db.POs
                    .AnyAsync(p => p.PONumber == row.PONumber && p.AgencyId == agencyId, cancellationToken);

                if (exists)
                {
                    _logger.LogDebug("PO '{PONumber}' already exists for agency {AgencyId} — skipping", row.PONumber, agencyId);
                    await WriteSyncLogAsync(agencyId, null, "POAlreadyExists",
                        $"PO '{row.PONumber}' already exists for agency {agencyId}", row, cancellationToken);
                    skipped++;
                    continue;
                }

                // Step 7 — insert new PO
                var po = MapToPo(row, agencyId);
                _db.POs.Add(po);
                await _db.SaveChangesAsync(cancellationToken);

                await WriteSyncLogAsync(agencyId, po.Id, "Success", null, row, cancellationToken);
                inserted++;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to insert PO '{PONumber}' for agency {AgencyId}", row.PONumber, agencyId);
                await WriteSyncLogAsync(agencyId, null, "Failed", ex.Message, row, cancellationToken);
                failed++;
            }
        }

        _logger.LogInformation(
            "PO_CREATE sync complete — inserted={Inserted} skipped={Skipped} failed={Failed}",
            inserted, skipped, failed);

        return new PoSyncResult(inserted, skipped, failed);
    }

    // ── SAP call ─────────────────────────────────────────────────────────────

    /// <summary>
    /// POSTs to the SAP JEDDOX endpoint and returns the raw Base64 string from the response.
    /// </summary>
    private async Task<string> FetchBase64PayloadAsync(CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, _url);
        request.Headers.Add("api-key", _apiKey);
        request.Headers.Add("Authorization", _basicAuth);
        if (!string.IsNullOrEmpty(_cookie))
            request.Headers.Add("Cookie", _cookie);
        request.Content = JsonContent.Create(new { request = new { data_type = "PO_CREATE" } });

        _logger.LogInformation("Calling SAP PO_CREATE endpoint: {Url}", _url);

        using var response = await _http.SendAsync(request, ct);
        response.EnsureSuccessStatusCode();

        var json = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken: ct);

        // SAP response shape: { "data": { "status": "S", "data_file": "<base64>", ... } }
        if (!json.TryGetProperty("data", out var dataNode) ||
            !dataNode.TryGetProperty("data_file", out var dataFileNode))
        {
            throw new InvalidOperationException(
                "SAP response does not contain expected 'data.data_file' field. " +
                $"Actual response: {json}");
        }

        // Guard: check SAP status is success
        if (dataNode.TryGetProperty("status", out var statusNode) &&
            statusNode.GetString() != "S")
        {
            var remarks = dataNode.TryGetProperty("remarks", out var r) ? r.GetString() : "unknown";
            throw new InvalidOperationException($"SAP returned non-success status. Remarks: {remarks}");
        }

        return dataFileNode.GetString()
               ?? throw new InvalidOperationException("SAP 'data.data_file' field is null.");
    }

    // ── Payload extraction ────────────────────────────────────────────────────

    /// <summary>
    /// Detects whether the decoded bytes are a ZIP archive or raw CSV text.
    /// If ZIP: extracts the first .csv entry. If raw: decodes as UTF-8.
    /// </summary>
    private string ExtractCsv(byte[] bytes)
    {
        if (IsZip(bytes))
        {
            _logger.LogInformation("Payload is a ZIP archive — extracting CSV entry");
            return ExtractCsvFromZip(bytes);
        }

        _logger.LogInformation("Payload is raw CSV text");
        return Encoding.UTF8.GetString(bytes);
    }

    /// <summary>ZIP magic bytes: PK (0x50 0x4B)</summary>
    private static bool IsZip(byte[] bytes) =>
        bytes.Length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

    /// <summary>
    /// Opens the ZIP and returns the content of the first .csv entry found.
    /// </summary>
    private static string ExtractCsvFromZip(byte[] bytes)
    {
        using var ms      = new MemoryStream(bytes);
        using var archive = new ZipArchive(ms, ZipArchiveMode.Read);

        var csvEntry = archive.Entries
            .FirstOrDefault(e => e.Name.EndsWith(".csv", StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException("ZIP archive contains no .csv file.");

        using var reader = new StreamReader(csvEntry.Open(), Encoding.UTF8);
        return reader.ReadToEnd();
    }

    // ── CSV parsing ───────────────────────────────────────────────────────────

    /// <summary>
    /// Parses a CSV string into a list of <see cref="SapPoRecord"/>.
    /// First row is treated as the header. Column names are matched case-insensitively.
    /// </summary>
    private List<SapPoRecord> ParseCsv(string csv)
    {
        var records = new List<SapPoRecord>();
        var lines   = csv.Split('\n', StringSplitOptions.RemoveEmptyEntries);

        if (lines.Length < 2)
        {
            _logger.LogWarning("CSV has fewer than 2 lines — nothing to parse");
            return records;
        }

        var headers = lines[0].Split(',');

        // Helper: find column index by name (case-insensitive)
        int Idx(string name) => Array.FindIndex(
            headers, h => h.Trim().Equals(name, StringComparison.OrdinalIgnoreCase));

        int iPoNum      = Idx("PONumber");
        int iAgencyCode = Idx("AgencyCode");
        int iVendorName = Idx("VendorName");
        int iVendorCode = Idx("VendorCode");
        int iPoDate     = Idx("PODate");
        int iTotalAmt   = Idx("TotalAmount");
        int iStatus     = Idx("POStatus");

        for (int i = 1; i < lines.Length; i++)
        {
            var cols = lines[i].Split(',');
            if (cols.Length < 2) continue;

            string Get(int idx) =>
                idx >= 0 && idx < cols.Length ? cols[idx].Trim().Trim('"') : string.Empty;

            records.Add(new SapPoRecord
            {
                PONumber    = Get(iPoNum),
                AgencyCode  = Get(iAgencyCode),
                VendorName  = Get(iVendorName),
                VendorCode  = Get(iVendorCode),
                PODate      = DateTime.TryParse(Get(iPoDate), CultureInfo.InvariantCulture,
                                  DateTimeStyles.None, out var d) ? d : null,
                TotalAmount = decimal.TryParse(Get(iTotalAmt), NumberStyles.Any,
                                  CultureInfo.InvariantCulture, out var amt) ? amt : null,
                POStatus    = Get(iStatus),
            });
        }

        return records;
    }

    // ── Agency map ────────────────────────────────────────────────────────────

    /// <summary>
    /// Builds a dictionary of SupplierCode → AgencyId from users with Role = Agency.
    /// </summary>
    private async Task<Dictionary<string, Guid>> BuildAgencyMapAsync(CancellationToken ct)
    {
        return await _db.Users
            .AsNoTracking()
            .Where(u => u.Role == UserRole.Agency && u.AgencyId != null && !u.IsDeleted)
            .Include(u => u.Agency)
            .Where(u => u.Agency != null && !u.Agency.IsDeleted)
            .Select(u => new { SupplierCode = u.Agency!.SupplierCode, AgencyId = u.AgencyId!.Value })
            .Distinct()
            .ToDictionaryAsync(x => x.SupplierCode, x => x.AgencyId, ct);
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private static PO MapToPo(SapPoRecord row, Guid agencyId) => new()
    {
        Id            = Guid.NewGuid(),
        AgencyId      = agencyId,
        PackageId     = null,              // SAP master data — not yet linked to a submission
        PONumber      = row.PONumber,
        PODate        = row.PODate,
        VendorName    = row.VendorName,
        VendorCode    = row.VendorCode,
        TotalAmount   = row.TotalAmount,
        POStatus      = string.IsNullOrWhiteSpace(row.POStatus) ? "Open" : row.POStatus,
        FileName      = "SAP_IMPORT",
        BlobUrl       = string.Empty,
        ContentType   = "text/csv",
        FileSizeBytes = 0,
    };

    // ── Audit logging ─────────────────────────────────────────────────────────

    private async Task WriteSyncLogAsync(
        Guid? agencyId,
        Guid? poId,
        string status,
        string? errorMessage,
        SapPoRecord row,
        CancellationToken ct)
    {
        _db.POSyncLogs.Add(new POSyncLog
        {
            Id              = Guid.NewGuid(),
            SourceSystem    = "SAP",
            FileName        = "PO_CREATE",
            AgencyId        = agencyId,
            POId            = poId,
            Status          = status,
            ErrorMessage    = errorMessage,
            ProcessedAt     = DateTime.UtcNow,
            ImportedRecords = JsonSerializer.Serialize(row),
        });

        await _db.SaveChangesAsync(ct);
    }

    // ── Internal record ───────────────────────────────────────────────────────

    private sealed record SapPoRecord
    {
        public string    PONumber    { get; init; } = string.Empty;
        public string    AgencyCode  { get; init; } = string.Empty;
        public string?   VendorName  { get; init; }
        public string?   VendorCode  { get; init; }
        public DateTime? PODate      { get; init; }
        public decimal?  TotalAmount { get; init; }
        public string?   POStatus    { get; init; }
    }
}
