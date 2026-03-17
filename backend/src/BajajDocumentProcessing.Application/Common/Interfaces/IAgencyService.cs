using BajajDocumentProcessing.Application.DTOs.Agency;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for managing agency entities.
/// </summary>
public interface IAgencyService
{
    /// <summary>
    /// Creates a new agency with the given supplier code and name.
    /// </summary>
    /// <param name="request">Agency creation request.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The created agency DTO.</returns>
    Task<AgencyDto> CreateAgencyAsync(
        CreateAgencyRequest request,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves an agency by its unique identifier.
    /// </summary>
    /// <param name="agencyId">The agency ID.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The agency DTO, or null if not found.</returns>
    Task<AgencyDto?> GetAgencyByIdAsync(
        Guid agencyId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves an agency by its supplier code.
    /// </summary>
    /// <param name="supplierCode">The unique supplier code.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The agency DTO, or null if not found.</returns>
    Task<AgencyDto?> GetAgencyBySupplierCodeAsync(
        string supplierCode,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all agencies.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>List of agency DTOs.</returns>
    Task<List<AgencyDto>> GetAllAgenciesAsync(
        CancellationToken cancellationToken = default);
}
