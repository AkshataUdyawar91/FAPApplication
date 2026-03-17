namespace BajajDocumentProcessing.Application.DTOs.PO;

/// <summary>
/// Response DTO for the PO balance calculation endpoint.
/// </summary>
public class PoBalanceResponse
{
    /// <summary>Purchase Order number.</summary>
    // public string PoNum { get; set; } = string.Empty;

    /// <summary>Calculated balance: sum of line item prices minus sum of GRN invoice values.</summary>
    public decimal Balance { get; set; }

    /// <summary>Currency code resolved from the first non-empty currency field in the line items.</summary>
    // public string Currency { get; set; } = string.Empty;

    /// <summary>UTC timestamp when the balance was calculated.</summary>
    public DateTime CalculatedAt { get; set; }
}
