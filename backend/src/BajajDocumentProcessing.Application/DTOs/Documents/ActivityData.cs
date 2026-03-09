namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Activity Summary extracted data
/// </summary>
public class ActivityData
{
    // CHANGE: Simplified to match actual Activity Summary table columns: Dealer, Location, To, From, Day, Working Day
    public List<ActivityRow> Rows { get; set; } = new();
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}

/// <summary>
/// Single row from Activity Summary table
/// </summary>
public class ActivityRow
{
    public string DealerName { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;
    public DateTime? ToDate { get; set; }
    public DateTime? FromDate { get; set; }
    public int Day { get; set; }
    public int WorkingDay { get; set; }
}
