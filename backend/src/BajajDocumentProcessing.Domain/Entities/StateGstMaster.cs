using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// GST state code to state name mapping reference data
/// </summary>
public class StateGstMaster : BaseEntity
{
    /// <summary>
    /// GST rate percentage applicable for this state (e.g., 18.00)
    /// </summary>
    public decimal GstPercentage { get; set; } = 18.00m;

    /// <summary>
    /// Short state code (e.g., "JK", "DL")
    /// </summary>
    public string StateCode { get; set; } = string.Empty;

    /// <summary>
    /// Full state name (e.g., "Jammu and Kashmir", "Delhi")
    /// </summary>
    public string StateName { get; set; } = string.Empty;

    /// <summary>
    /// Whether this record is active
    /// </summary>
    public bool IsActive { get; set; } = true;
}
