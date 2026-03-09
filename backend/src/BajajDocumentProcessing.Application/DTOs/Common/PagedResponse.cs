using System.Text.Json.Serialization;

namespace BajajDocumentProcessing.Application.DTOs.Common;

/// <summary>
/// Generic wrapper for paginated API responses
/// </summary>
/// <typeparam name="T">Type of items in the response</typeparam>
public class PagedResponse<T>
{
    /// <summary>
    /// Total number of items across all pages
    /// </summary>
    [JsonPropertyName("total")]
    public required int Total { get; init; }
    
    /// <summary>
    /// Current page number (1-based)
    /// </summary>
    [JsonPropertyName("page")]
    public required int Page { get; init; }
    
    /// <summary>
    /// Number of items per page
    /// </summary>
    [JsonPropertyName("pageSize")]
    public required int PageSize { get; init; }
    
    /// <summary>
    /// Items in the current page
    /// </summary>
    [JsonPropertyName("items")]
    public required List<T> Items { get; init; }
    
    /// <summary>
    /// Total number of pages
    /// </summary>
    [JsonPropertyName("totalPages")]
    public int TotalPages => (int)Math.Ceiling((double)Total / PageSize);
    
    /// <summary>
    /// Whether there is a next page
    /// </summary>
    [JsonPropertyName("hasNextPage")]
    public bool HasNextPage => Page < TotalPages;
    
    /// <summary>
    /// Whether there is a previous page
    /// </summary>
    [JsonPropertyName("hasPreviousPage")]
    public bool HasPreviousPage => Page > 1;
}
