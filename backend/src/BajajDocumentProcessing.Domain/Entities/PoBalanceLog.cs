namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Audit log for every /api/po-balance call.
/// Tracks the inbound request, the outbound SAP call, and the final response.
/// </summary>
public class PoBalanceLog
{
    public Guid Id { get; set; }

    // ── Request ──────────────────────────────────────────────
    /// <summary>PO number supplied by the caller.</summary>
    public string PoNum { get; set; } = string.Empty;

    /// <summary>Company code supplied by the caller.</summary>
    public string CompanyCode { get; set; } = string.Empty;

    /// <summary>JWT subject (userId) of the caller, if available.</summary>
    public string? RequestedBy { get; set; }

    /// <summary>UTC timestamp when the request was received.</summary>
    public DateTime RequestedAt { get; set; }

    // ── SAP call ─────────────────────────────────────────────
    /// <summary>Raw JSON body sent to the SAP API.</summary>
    public string? SapRequestBody { get; set; }

    /// <summary>UTC timestamp when the SAP call was initiated.</summary>
    public DateTime? SapCalledAt { get; set; }

    /// <summary>UTC timestamp when the SAP response was received.</summary>
    public DateTime? SapRespondedAt { get; set; }

    /// <summary>HTTP status code returned by SAP (null if network error).</summary>
    public int? SapHttpStatus { get; set; }

    /// <summary>Raw JSON body returned by SAP (truncated to 4000 chars).</summary>
    public string? SapResponseBody { get; set; }

    // ── Outcome ───────────────────────────────────────────────
    /// <summary>Calculated balance returned to the caller. Null on error.</summary>
    public decimal? Balance { get; set; }

    /// <summary>Currency code returned to the caller.</summary>
    public string? Currency { get; set; }

    /// <summary>True if the full flow completed successfully.</summary>
    public bool IsSuccess { get; set; }

    /// <summary>Error message if IsSuccess is false.</summary>
    public string? ErrorMessage { get; set; }

    /// <summary>Total elapsed milliseconds for the full request.</summary>
    public long ElapsedMs { get; set; }

    /// <summary>ASP.NET Core correlation / trace identifier.</summary>
    public string? CorrelationId { get; set; }
}
