using Microsoft.Bot.Builder.Integration.AspNet.Core;
using Microsoft.Bot.Builder.TraceExtensions;
using Microsoft.Bot.Connector.Authentication;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services.Teams;

/// <summary>
/// Custom Bot Framework adapter with global error handling.
/// Logs errors with correlation context and sends a user-friendly error card.
/// </summary>
public class AdapterWithErrorHandler : CloudAdapter
{
    public AdapterWithErrorHandler(
        IConfiguration configuration,
        ILogger<AdapterWithErrorHandler> logger)
        : base(configuration, null, logger)
    {
        OnTurnError = async (turnContext, exception) =>
        {
            var correlationId = Guid.NewGuid().ToString("N")[..12];

            logger.LogError(
                exception,
                "Teams bot unhandled error. CorrelationId: {CorrelationId}, ActivityType: {ActivityType}, ConversationId: {ConversationId}",
                correlationId,
                turnContext.Activity?.Type,
                turnContext.Activity?.Conversation?.Id);

            // Send user-friendly error message
            await turnContext.SendActivityAsync(
                $"Something went wrong processing your request. " +
                $"Please try again or use the portal directly. (Ref: {correlationId})");

            // Send trace activity for Bot Framework Emulator debugging
            await turnContext.TraceActivityAsync(
                "OnTurnError Trace",
                exception.Message,
                "https://www.botframework.com/schemas/error",
                "TurnError");
        };
    }
}
