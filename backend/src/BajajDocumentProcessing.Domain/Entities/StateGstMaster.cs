using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// GST state code to state name mapping reference data
/// </summary>
public class StateGstMaster : BaseEntity
{
    /// <summary>
    /// 2-digit GST state code (e.g., "01", "07")
    /// </summary>
    public string GstCode { get; set; } = string.Empty;

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
