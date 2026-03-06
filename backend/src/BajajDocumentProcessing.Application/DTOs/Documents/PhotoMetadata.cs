namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Photo EXIF metadata and AI-detected content
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
    
    // CHANGE: Added new fields for photo analysis
    // Date extracted from GPS overlay text on the image
    public string? PhotoDateFromOverlay { get; set; }
    // Location text from GPS overlay (e.g., "Patna, Bihar, India")
    public string? LocationText { get; set; }
    
    // AI-detected content (from Azure OpenAI Vision)
    public bool HasBlueTshirtPerson { get; set; }
    // CHANGE: Added count of people with blue tshirt
    public int BlueTshirtPersonCount { get; set; }
    public bool HasBajajVehicle { get; set; }
    // CHANGE: Added specific 3-wheel vehicle detection
    public bool Has3WVehicle { get; set; }
    public double BlueTshirtConfidence { get; set; }
    public double VehicleConfidence { get; set; }
    
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    public bool IsFlaggedForReview { get; set; }
}
