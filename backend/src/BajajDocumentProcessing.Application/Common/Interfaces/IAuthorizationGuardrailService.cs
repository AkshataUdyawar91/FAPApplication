namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for managing user authorization and data access scope
/// </summary>
public interface IAuthorizationGuardrailService
{
    /// <summary>
    /// Retrieves the data access scope for a user based on their role and permissions
    /// </summary>
    /// <param name="userId">User's unique identifier</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Data scope defining which states, campaigns, and date ranges the user can access</returns>
    Task<DataScope> GetUserDataScopeAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Validates that a user has access to the system and is not blocked
    /// </summary>
    /// <param name="userId">User's unique identifier</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Task representing the async validation operation</returns>
    /// <exception cref="UnauthorizedAccessException">Thrown when user access is denied</exception>
    Task ValidateUserAccessAsync(Guid userId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Defines the data access scope for a user
/// </summary>
public class DataScope
{
    /// <summary>
    /// List of states the user can access (null means all states)
    /// </summary>
    public List<string>? States { get; set; }

    /// <summary>
    /// List of campaigns the user can access (null means all campaigns)
    /// </summary>
    public List<string>? Campaigns { get; set; }

    /// <summary>
    /// Date range the user can access (null means no date restrictions)
    /// </summary>
    public DateRange? DateRange { get; set; }
}

/// <summary>
/// Date range for data access restrictions
/// </summary>
public class DateRange
{
    /// <summary>
    /// Start date of accessible data (null means no start restriction)
    /// </summary>
    public DateTime? StartDate { get; set; }

    /// <summary>
    /// End date of accessible data (null means no end restriction)
    /// </summary>
    public DateTime? EndDate { get; set; }
}

/// <summary>
/// Exception thrown when a user attempts unauthorized access
/// </summary>
public class UnauthorizedAccessException : Exception
{
    /// <summary>
    /// Initializes a new instance of the UnauthorizedAccessException class
    /// </summary>
    /// <param name="message">Error message describing the unauthorized access attempt</param>
    public UnauthorizedAccessException(string message) : base(message) { }
}
