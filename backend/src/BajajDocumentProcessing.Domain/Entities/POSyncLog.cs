using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Audit log for inbound SAP PO file sync operations.
/// Records every file received from SAP with agency/PO resolution outcome
/// and the raw imported CSV data as JSON.
/// </summary>
public class POSyncLog : BaseEntity
{
    /// <summary>
    /// Source system that sent the file (default: 'SAP').
    /// </summary>
    public string SourceSystem { get; set; } = "SAP";

    /// <summary>
    /// Name of the file received from SAP.
    /// </summary>
    public string FileName { get; set; } = string.Empty;

    /// <summary>
    /// Resolved agency ID. NULL if agency was not found.
    /// </summary>
    public Guid? AgencyId { get; set; }

    /// <summary>
    /// Resolved PO ID. NULL if PO already existed or insert failed.
    /// </summary>
    public Guid? POId { get; set; }

    /// <summary>
    /// Sync outcome: 'AgencyNotFound' | 'POAlreadyExists' | 'Success' | 'Failed'
    /// </summary>
    public string Status { get; set; } = string.Empty;

    /// <summary>
    /// Error detail when Status is 'AgencyNotFound', 'POAlreadyExists', or 'Failed'.
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    /// Timestamp when the file was processed.
    /// </summary>
    public DateTime ProcessedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Raw JSON extracted from the incoming CSV file.
    /// </summary>
    public string? ImportedRecords { get; set; }

    // Navigation properties

    /// <summary>
    /// Navigation property to the resolved Agency (nullable).
    /// </summary>
    public Agency? Agency { get; set; }

    /// <summary>
    /// Navigation property to the resolved PO (nullable).
    /// </summary>
    public PO? PO { get; set; }
}
