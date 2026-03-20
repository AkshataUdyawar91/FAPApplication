using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Agency;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin — Supplier/Agency master CRUD.</summary>
[ApiController]
[Route("api/admin/agencies")]
[Authorize(Roles = "Admin")]
public class AgenciesController : ControllerBase
{
    private readonly IAgencyService _service;
    private readonly ILogger<AgenciesController> _logger;

    public AgenciesController(IAgencyService service, ILogger<AgenciesController> logger)
    {
        _service = service;
        _logger  = logger;
    }

    /// <summary>Get paginated list of agencies.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedAgenciesResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAgencies(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize   = 20,
        [FromQuery] string? search = null,
        CancellationToken ct = default)
    {
        var result = await _service.GetAgenciesAsync(pageNumber, pageSize, search, ct);
        return Ok(result);
    }

    /// <summary>Get a single agency by ID.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(AgencyDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetAgency([FromRoute] Guid id, CancellationToken ct)
    {
        var agency = await _service.GetAgencyByIdAsync(id, ct);
        return agency == null ? NotFound() : Ok(agency);
    }

    /// <summary>Create a new agency.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(AgencyDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateAgency([FromBody] CreateAgencyRequest request, CancellationToken ct)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var agency = await _service.CreateAgencyAsync(request, ct);
        _logger.LogInformation("Admin created agency {Code}", agency.SupplierCode);
        return CreatedAtAction(nameof(GetAgency), new { id = agency.Id }, agency);
    }

    /// <summary>Update an existing agency.</summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(AgencyDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateAgency(
        [FromRoute] Guid id, [FromBody] UpdateAgencyRequest request, CancellationToken ct)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);
        var agency = await _service.UpdateAgencyAsync(id, request, ct);
        if (agency == null) return NotFound();
        _logger.LogInformation("Admin updated agency {Id}", id);
        return Ok(agency);
    }

    /// <summary>Hard-delete an agency.</summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteAgency([FromRoute] Guid id, CancellationToken ct)
    {
        var deleted = await _service.DeleteAgencyAsync(id, ct);
        if (!deleted) return NotFound();
        _logger.LogInformation("Admin hard-deleted agency {Id}", id);
        return NoContent();
    }
}
