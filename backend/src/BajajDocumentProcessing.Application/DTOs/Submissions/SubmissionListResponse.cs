using BajajDocumentProcessing.Application.DTOs.Common;

namespace BajajDocumentProcessing.Application.DTOs.Submissions;

/// <summary>
/// Paginated response containing a list of submissions
/// </summary>
public class SubmissionListResponse : PagedResponse<SubmissionListItemDto>
{
}
