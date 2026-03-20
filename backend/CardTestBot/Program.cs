using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Integration.AspNet.Core;
using Microsoft.Bot.Connector.Authentication;

var builder = WebApplication.CreateBuilder(args);

// Bot Framework setup — no app ID/password needed for Emulator
builder.Services.AddSingleton<BotFrameworkAuthentication, ConfigurationBotFrameworkAuthentication>();
builder.Services.AddSingleton<IBotFrameworkHttpAdapter, AdapterWithErrorHandler>();
builder.Services.AddTransient<IBot, CardHeaderBot>();

var app = builder.Build();

// Bot endpoint
app.MapPost("/api/messages", async (HttpContext context, IBotFrameworkHttpAdapter adapter, IBot bot) =>
{
    await adapter.ProcessAsync(context.Request, context.Response, bot);
});

app.MapGet("/", () => "CardTestBot is running. Connect Bot Framework Emulator to http://localhost:5200/api/messages");

app.Run();
