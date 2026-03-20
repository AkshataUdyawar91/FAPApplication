using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Admin;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>Admin user management — list, create, update, soft-delete.</summary>
[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = "Admin")]
public class UsersController : ControllerBase
{
    private readonly IUserManagementService _service;
    private readonly ILogger<UsersController> _logger;

    public UsersController(IUserManagementService service, ILogger<UsersController> logger)
    {
        _service = service;
        _logger  = logger;
    }

    /// <summary>Get paginated list of users.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedUsersResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetUsers(
        [FromQuery] int pageNumber  = 1,
        [FromQuery] int pageSize    = 20,
        [FromQuery] string? search  = null,
        [FromQuery] int? role       = null,
        CancellationToken ct = default)
    {
        var result = await _service.GetUsersAsync(pageNumber, pageSize, search, role, ct);
        return Ok(result);
    }

    /// <summary>Get a single user by ID.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetUser([FromRoute] Guid id, CancellationToken ct)
    {
        var user = await _service.GetUserByIdAsync(id, ct);
        return user == null ? NotFound() : Ok(user);
    }

    /// <summary>Create a new user.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> CreateUser([FromBody] CreateUserRequest request, CancellationToken ct)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var user = await _service.CreateUserAsync(request, ct);
        _logger.LogInformation("Admin created user {Email}", user.Email);
        return CreatedAtAction(nameof(GetUser), new { id = user.Id }, user);
    }

    /// <summary>Update an existing user.</summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateUser(
        [FromRoute] Guid id, [FromBody] UpdateUserRequest request, CancellationToken ct)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var user = await _service.UpdateUserAsync(id, request, ct);
        if (user == null) return NotFound();

        _logger.LogInformation("Admin updated user {Id}", id);
        return Ok(user);
    }

    /// <summary>Hard-delete a user.</summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteUser([FromRoute] Guid id, CancellationToken ct)
    {
        var deleted = await _service.DeleteUserAsync(id, ct);
        if (!deleted) return NotFound();

        _logger.LogInformation("Admin hard-deleted user {Id}", id);
        return NoContent();
    }
}
