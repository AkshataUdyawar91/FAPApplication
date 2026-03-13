using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Services.Teams;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Integration.AspNet.Core;
using Microsoft.Bot.Schema;
using Microsoft.EntityFrameworkCore;

namespace BajajDocumentProcessing.API.Controllers;

/// <summary>
/// Bot Framework webhook endpoint for Microsoft Teams bot messages.
/// Bot Framework handles its own authentication via App ID/Secret — no JWT required.
/// </summary>
[ApiController]
[Route("api/teams")]
[AllowAnonymous]
public class TeamsController : ControllerBase
{
    private readonly IBotFrameworkHttpAdapter _adapter;
    private readonly IBot _bot;
    private readonly ILogger<TeamsController> _logger;

    public TeamsController(
        IBotFrameworkHttpAdapter adapter,
        IBot bot,
        ILogger<TeamsController> logger)
    {
        _adapter = adapter;
        _bot = bot;
        _logger = logger;
    }

    /// <summary>
    /// Receives all incoming Teams activities (messages, card actions, install/uninstall events).
    /// Bot Framework SDK routes activities to the appropriate handler in TeamsBotService.
    /// </summary>
    [HttpPost("messages")]
    public async Task PostAsync()
    {
        _logger.LogInformation(
            "Received Teams bot activity. ContentType: {ContentType}, ContentLength: {ContentLength}",
            Request.ContentType, Request.ContentLength);

        try
        {
            await _adapter.ProcessAsync(Request, Response, _bot);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Teams bot activity");
            if (!Response.HasStarted)
            {
                Response.StatusCode = 500;
                await Response.WriteAsync($"Error: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// DEV-ONLY: Sends an approval adaptive card to the captured conversation reference.
    /// Gated by IsDevelopment() — not available in production.
    /// </summary>
    [HttpPost("test/send-card/{fapId}")]
    public async Task<IActionResult> SendTestCard(
        Guid fapId,
        [FromServices] IApplicationDbContext context,
        [FromServices] PilotTeamsConfig pilotConfig,
        [FromServices] IConfiguration configuration,
        CancellationToken cancellationToken)
    {
        var env = HttpContext.RequestServices.GetRequiredService<IWebHostEnvironment>();
        if (!env.IsDevelopment())
        {
            return NotFound();
        }

        var reference = pilotConfig.GetReference();
        if (reference == null)
        {
            return BadRequest(new { error = "No conversation reference captured. Install the bot in Teams first." });
        }

        var package = await context.DocumentPackages
            .Include(p => p.ConfidenceScore)
            .Include(p => p.Recommendation)
            .Include(p => p.SubmittedBy)
            .FirstOrDefaultAsync(p => p.Id == fapId, cancellationToken);

        if (package == null)
        {
            return NotFound(new { error = $"FAP {fapId} not found." });
        }

        var portalBaseUrl = configuration["TeamsBot:PortalBaseUrl"] ?? "https://localhost:7001";
        var fapNumber = package.Id.ToString()[..8].ToUpper();
        var agencyName = package.SubmittedBy?.FullName ?? "Unknown Agency";
        var poNumber = fapNumber; // Simplified for pilot
        var amount = 0m;
        var submittedDate = package.CreatedAt;
        var confidence = package.ConfidenceScore?.OverallConfidence ?? 0;
        var recType = package.Recommendation?.Type.ToString() ?? "REVIEW";
        var recSummary = package.Recommendation?.Evidence ?? "No AI recommendation available yet.";

        var card = ApprovalCardBuilder.BuildApprovalCard(
            fapId, fapNumber, agencyName, poNumber, amount,
            submittedDate, confidence, recType, recSummary, portalBaseUrl);

        var appId = configuration["TeamsBot:MicrosoftAppId"] ?? "";

        await ((BotAdapter)_adapter).ContinueConversationAsync(
            appId, reference,
            async (turnContext, ct) =>
            {
                await turnContext.SendActivityAsync(MessageFactory.Attachment(card), ct);
            },
            cancellationToken);

        _logger.LogInformation("Test card sent for FAP {FapId} to captured conversation", fapId);

        return Ok(new { message = $"Card sent to ASM for FAP {fapNumber}" });
    }
}
