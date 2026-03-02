namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Photo EXIF metadata
/// </summary>
public class PhotoMetadata
{
    public DateTime? Timestamp { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? DeviceMake { get; set; }
    public string? DeviceModel { get; set; }
    public int? ImageWidth { get; set; }
    public int? ImageHeight { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}
