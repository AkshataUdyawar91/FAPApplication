namespace BajajDocumentProcessing.Application.DTOs.Documents;

/// <summary>
/// Photo EXIF metadata and AI-detected content
/// </summary>
public class PhotoMetadata
{
    /// <summary>
    /// Timestamp when the photo was taken (from EXIF data)
    /// </summary>
    public DateTime? Timestamp { get; set; }
    
    /// <summary>
    /// GPS latitude coordinate (from EXIF data)
    /// </summary>
    public double? Latitude { get; set; }
    
    /// <summary>
    /// GPS longitude coordinate (from EXIF data)
    /// </summary>
    public double? Longitude { get; set; }
    
    /// <summary>
    /// Camera/device manufacturer (from EXIF data)
    /// </summary>
    public string? DeviceMake { get; set; }
    
    /// <summary>
    /// Camera/device model (from EXIF data)
    /// </summary>
    public string? DeviceModel { get; set; }
    
    /// <summary>
    /// Image width in pixels
    /// </summary>
    public int? ImageWidth { get; set; }
    
    /// <summary>
    /// Image height in pixels
    /// </summary>
    public int? ImageHeight { get; set; }
    
    /// <summary>
    /// Date extracted from GPS overlay text on the image
    /// </summary>
    public string? PhotoDateFromOverlay { get; set; }
    
    /// <summary>
    /// Location text from GPS overlay (e.g., "Patna, Bihar, India")
    /// </summary>
    public string? LocationText { get; set; }
    
    /// <summary>
    /// Whether AI detected a person wearing a blue t-shirt
    /// </summary>
    public bool HasBlueTshirtPerson { get; set; }
    
    /// <summary>
    /// Number of people wearing blue t-shirts detected by AI
    /// </summary>
    public int BlueTshirtPersonCount { get; set; }
    
    /// <summary>
    /// Whether AI detected a Bajaj vehicle
    /// </summary>
    public bool HasBajajVehicle { get; set; }
    
    /// <summary>
    /// Whether AI detected a 3-wheel vehicle
    /// </summary>
    public bool Has3WVehicle { get; set; }
    
    /// <summary>
    /// AI confidence score for blue t-shirt detection (0-100)
    /// </summary>
    public double BlueTshirtConfidence { get; set; }
    
    /// <summary>
    /// AI confidence score for vehicle detection (0-100)
    /// </summary>
    public double VehicleConfidence { get; set; }
    
    /// <summary>
    /// AI confidence scores for each extracted field (0-100)
    /// </summary>
    public Dictionary<string, double> FieldConfidences { get; set; } = new();
    
    /// <summary>
    /// Whether this photo has been flagged for manual review
    /// </summary>
    public bool IsFlaggedForReview { get; set; }

    /// <summary>
    /// Whether AI detected a human face in the photo
    /// </summary>
    public bool HasHumanFace { get; set; }

    /// <summary>
    /// Number of human faces detected by AI
    /// </summary>
    public int FaceCount { get; set; }

    /// <summary>
    /// AI confidence score for face detection (0-100)
    /// </summary>
    public double FaceDetectionConfidence { get; set; }

    /// <summary>
    /// Perceptual hash of the image for duplicate detection
    /// </summary>
    public string? PerceptualHash { get; set; }
}
