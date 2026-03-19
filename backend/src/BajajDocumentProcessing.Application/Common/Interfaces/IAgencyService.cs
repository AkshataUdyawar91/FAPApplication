using BajajDocumentProcessing.Application.DTOs.Agency;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>Service for managing agency entities.</summary>
public interface IAgencyService
{
    Task<PagedAgenciesResponse> GetAgenciesAsync(int pageNumber, int pageSize, string? search, CancellationToken ct = default);
    Task<AgencyDto?> GetAgencyByIdAsync(Guid agencyId, CancellationToken ct = default);
    Task<AgencyDto?> GetAgencyBySupplierCodeAsync(string supplierCode, CancellationToken ct = default);
    Task<AgencyDto> CreateAgencyAsync(CreateAgencyRequest request, CancellationToken ct = default);
    Task<AgencyDto?> UpdateAgencyAsync(Guid id, UpdateAgencyRequest request, CancellationToken ct = default);
    Task<bool> DeleteAgencyAsync(Guid id, CancellationToken ct = default);
}
