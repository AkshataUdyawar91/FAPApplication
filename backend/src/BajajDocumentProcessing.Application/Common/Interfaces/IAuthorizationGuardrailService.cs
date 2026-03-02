namespace BajajDocumentProcessing.Application.Common.Interfaces;

public interface IAuthorizationGuardrailService
{
    Task<DataScope> GetUserDataScopeAsync(Guid userId, CancellationToken cancellationToken = default);
    Task ValidateUserAccessAsync(Guid userId, CancellationToken cancellationToken = default);
}

public class DataScope
{
    public List<string>? States { get; set; }
    public List<string>? Campaigns { get; set; }
    public DateRange? DateRange { get; set; }
}

public class DateRange
{
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
}

public class UnauthorizedAccessException : Exception
{
    public UnauthorizedAccessException(string message) : base(message) { }
}
