namespace BajajDocumentProcessing.Application.DTOs.Analytics;

/// <summary>
/// Response DTO for quarterly FAP (Final Approved Payment) KPI data
/// </summary>
public class QuarterlyFapKpiResponse
{
    /// <summary>Quarter identifier: Q1, Q2, Q3, Q4, or All</summary>
    public string Quarter { get; set; } = string.Empty;

    /// <summary>Calendar year</summary>
    public int Year { get; set; }

    /// <summary>Sum of TotalAmount from Invoice ExtractedDataJson for approved packages</summary>
    public decimal FapAmount { get; set; }

    /// <summary>Count of distinct approved packages with at least one invoice</summary>
    public int FapCount { get; set; }
}
