using BajajDocumentProcessing.Domain.Common;

namespace BajajDocumentProcessing.Domain.Entities;

/// <summary>
/// Cost element definition with expense nature
/// </summary>
public class CostMaster : BaseEntity
{
    /// <summary>
    /// Name of the cost element (e.g., "POS - Standee", "Promoter")
    /// </summary>
    public string ElementName { get; set; } = string.Empty;

    /// <summary>
    /// Expense nature: "Fixed Cost" or "Cost per Day"
    /// </summary>
    public string ExpenseNature { get; set; } = string.Empty;

    /// <summary>
    /// Whether this record is active
    /// </summary>
    public bool IsActive { get; set; } = true;
}
