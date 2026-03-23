namespace BajajDocumentProcessing.Application.DTOs.Admin;

/// <summary>Paginated list of users.</summary>
public class PagedUsersResponse
{
    public List<UserDto> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int PageNumber { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
}
