using AdaptiveCards.Templating;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Schema;

/// <summary>
/// Minimal bot that sends the AC 2.1 header card when you message it.
/// Send any message to get the card. Send "raw" to see the expanded JSON.
/// </summary>
public class CardHeaderBot : ActivityHandler
{
    private static readonly string CardTemplate = LoadTemplate();

    protected override async Task OnMessageActivityAsync(
        ITurnContext<IMessageActivity> turnContext,
        CancellationToken cancellationToken)
    {
        var userText = turnContext.Activity.Text?.Trim().ToLower() ?? "";

        // Build card data (simulating SubmissionCardData)
        var dataContext = new
        {
            notificationTimestamp = DateTime.Now.ToString("dd-MMM-yyyy, hh:mm tt")
        };

        var template = new AdaptiveCardTemplate(CardTemplate);
        var cardJson = template.Expand(dataContext);

        if (userText == "raw")
        {
            // Send raw JSON for inspection
            await turnContext.SendActivityAsync(
                $"```json\n{cardJson}\n```",
                cancellationToken: cancellationToken);
            return;
        }

        // Send as Adaptive Card attachment
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = System.Text.Json.JsonSerializer.Deserialize<object>(cardJson)
        };

        var reply = MessageFactory.Attachment(attachment);
        await turnContext.SendActivityAsync(reply, cancellationToken);

        await turnContext.SendActivityAsync(
            "👆 That's the AC 2.1 header card. Send **raw** to see the JSON.",
            cancellationToken: cancellationToken);
    }

    protected override async Task OnMembersAddedAsync(
        IList<ChannelAccount> membersAdded,
        ITurnContext<IConversationUpdateActivity> turnContext,
        CancellationToken cancellationToken)
    {
        foreach (var member in membersAdded)
        {
            if (member.Id != turnContext.Activity.Recipient.Id)
            {
                await turnContext.SendActivityAsync(
                    "Welcome! Send any message to see the **New Claim Submitted** Adaptive Card header (AC 2.1).\n\n" +
                    "Send **raw** to see the expanded JSON.",
                    cancellationToken: cancellationToken);
            }
        }
    }

    private static string LoadTemplate()
    {
        // Try multiple paths to find the template
        var paths = new[]
        {
            Path.Combine("..", "templates", "teams-cards", "new-submission-card.json"),
            Path.Combine("..", "src", "BajajDocumentProcessing.Infrastructure", "Templates", "TeamsCards", "new-submission-card.json"),
            "new-submission-card.json"
        };

        foreach (var path in paths)
        {
            if (File.Exists(path))
                return File.ReadAllText(path);
        }

        throw new FileNotFoundException(
            $"Card template not found. Searched: {string.Join(", ", paths)}");
    }
}
