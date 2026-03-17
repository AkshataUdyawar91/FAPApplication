using BajajDocumentProcessing.Application.DTOs.PO;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Fetches PO balance from SAP and persists an audit log to POBalanceLogs.
/// </summary>
public interface IPoBalanceService
{
    /// <summary>
    /// Calls the SAP PO_Data API, calculates the balance, and writes an audit record.
    /// </summary>
    /// <param name="companyCode">SAP company code (e.g. "BAL").</param>
    /// <param name="poNum">SAP Purchase Order number.</param>
    /// <param name="requestedBy">JWT userId of the caller (for audit).</param>
    /// <param name="correlationId">Request correlation ID (for audit).</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task<PoBalanceResponse> GetPoBalanceAsync(
        string companyCode,
        string poNum,
        string? requestedBy = null,
        string? correlationId = null,
        CancellationToken cancellationToken = default);
}
