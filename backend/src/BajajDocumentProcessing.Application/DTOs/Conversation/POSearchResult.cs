using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Conversation;

/// <summary>
/// Purchase order search result for PO selection step
/// </summary>
public class POSearchResult
{
    /// <summary>
    /// PO entity identifier
    /// </summary>
    [JsonPropertyName("id")]
    public required Guid Id { get; init; }

    /// <summary>
    /// Purchase order number
    /// </summary>
    [JsonPropertyName("poNumber")]
    public required string PONumber { get; init; }

    /// <summary>
    /// Purchase order date
    /// </summary>
    [JsonPropertyName("poDate")]
    public required DateTime PODate { get; init; }

    /// <summary>
    /// Vendor / agency name
    /// </summary>
    [JsonPropertyName("vendorName")]
    public required string VendorName { get; init; }

    /// <summary>
    /// Total PO amount
    /// </summary>
    [JsonPropertyName("totalAmount")]
    public required decimal TotalAmount { get; init; }

    /// <summary>
    /// Remaining balance on the PO
    /// </summary>
    [JsonPropertyName("remainingBalance")]
    public decimal? RemainingBalance { get; init; }

    /// <summary>
    /// PO status: Open, PartiallyConsumed, Closed
    /// </summary>
    [JsonPropertyName("poStatus")]
    public string? POStatus { get; init; }
}
