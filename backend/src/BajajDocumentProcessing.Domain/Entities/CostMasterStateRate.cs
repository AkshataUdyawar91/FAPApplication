using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// State-wise cost rate for a cost element
/// </summary>
public class CostMasterStateRate : BaseEntity
{
    /// <summary>
    /// State identifier (e.g., "Delhi", "UP &amp; UTT")
    /// </summary>
    public string StateCode { get; set; } = string.Empty;

    /// <summary>
    /// Cost element name (e.g., "POS Standee", "Promoter")
    /// </summary>
    public string ElementName { get; set; } = string.Empty;

    /// <summary>
    /// Rate value (amount or percentage depending on RateType)
    /// </summary>
    public decimal RateValue { get; set; }

    /// <summary>
    /// "Amount" or "Percentage"
    /// </summary>
    public string RateType { get; set; } = "Amount";

    /// <summary>
    /// Whether this record is active
    /// </summary>
    public bool IsActive { get; set; } = true;
}
