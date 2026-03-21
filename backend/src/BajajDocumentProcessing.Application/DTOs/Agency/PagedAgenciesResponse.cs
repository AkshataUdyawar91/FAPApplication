namespace BajajDocumentProcessing.Application.DTOs.Agency;

/// <summary>Paginated list of agencies.</summary>
public class PagedAgenciesResponse
{
    public List<AgencyDto> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int PageNumber { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
}
