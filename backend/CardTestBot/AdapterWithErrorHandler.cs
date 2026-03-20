using Microsoft.Bot.Builder.Integration.AspNet.Core;
using Microsoft.Bot.Builder.TraceExtensions;
using Microsoft.Bot.Connector.Authentication;

public class AdapterWithErrorHandler : CloudAdapter
{
    public AdapterWithErrorHandler(
        BotFrameworkAuthentication auth,
        ILogger<CloudAdapter> logger)
        : base(auth, logger)
    {
        OnTurnError = async (turnContext, exception) =>
        {
            logger.LogError(exception, "Unhandled error: {Message}", exception.Message);
            await turnContext.SendActivityAsync($"Sorry, something went wrong: {exception.Message}");
        };
    }
}
