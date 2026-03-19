namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Fetches PO_CREATE data from SAP, decodes the Base64 payload (ZIP or raw CSV),
/// filters rows by agency codes derived from Agency-role users, and upserts PO records.
/// </summary>
public interface IPoSyncService
{
    /// <summary>
    /// Pulls the latest PO_CREATE data from SAP and upserts into the POs table.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Summary of inserted, skipped, and failed records</returns>
    Task<PoSyncResult> SyncAsync(CancellationToken cancellationToken = default);
}

/// <summary>
/// Summary result of a single PO sync run.
/// </summary>
/// <param name="Inserted">Number of new PO records inserted</param>
/// <param name="Skipped">Number of rows skipped (agency not found or duplicate)</param>
/// <param name="Failed">Number of rows that failed to insert</param>
/// <param name="ErrorMessage">Top-level error if the entire sync failed (e.g. SAP unreachable)</param>
public record PoSyncResult(int Inserted, int Skipped, int Failed, string? ErrorMessage = null);
