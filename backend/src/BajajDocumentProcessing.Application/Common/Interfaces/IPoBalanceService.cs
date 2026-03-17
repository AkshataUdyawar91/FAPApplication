using BajajDocumentProcessing.Application.DTOs.PO;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Provides PO balance calculation by calling the SAP PO_Data API.
/// </summary>
public interface IPoBalanceService
{
    /// <summary>
    /// Fetches PO data from SAP and returns the calculated balance.
    /// </summary>
    /// <param name="companyCode">SAP company code (e.g. "BAL").</param>
    /// <param name="poNum">SAP Purchase Order number (e.g. "5110014001").</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task<PoBalanceResponse> GetPoBalanceAsync(string companyCode, string poNum, CancellationToken cancellationToken = default);
}
