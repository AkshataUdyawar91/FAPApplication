namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Activity Summary (Enquiry & Docs) extracted data
/// </summary>
public class ActivityData
{
    public string? DealerName { get; set; }
    public string? DealerCode { get; set; }
    public string? DealerAddress { get; set; }
    public List<LocationActivity> LocationActivities { get; set; } = new();
    public int? TotalDays { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}

/// <summary>
/// Activity at a specific location
/// </summary>
public class LocationActivity
{
    public string LocationName { get; set; } = string.Empty;
    public string? LocationAddress { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public int NumberOfDays { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public string? ActivityType { get; set; }
    public string? Description { get; set; }
}
