using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Integration.AspNet.Core;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.Infrastructure.Services;
using BajajDocumentProcessing.Infrastructure.Services.Teams;

namespace BajajDocumentProcessing.Infrastructure;

/// <summary>
/// Infrastructure layer dependency injection configuration
/// </summary>
public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Database configuration
        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseSqlServer(
                configuration.GetConnectionString("DefaultConnection"),
                b => b.MigrationsAssembly(typeof(ApplicationDbContext).Assembly.FullName)));

        services.AddScoped<IApplicationDbContext>(provider => 
            provider.GetRequiredService<ApplicationDbContext>());

        // Add Memory Cache
        services.AddMemoryCache();

        // Authentication service
        services.AddScoped<IAuthService, AuthService>();

        // File storage and document services
        services.AddScoped<IFileStorageService, FileStorageService>();
        services.AddScoped<IMalwareScanService, MalwareScanService>();
        services.AddScoped<IDocumentService, DocumentService>();
        
        // Azure Document Intelligence
        services.AddScoped<AzureDocumentIntelligenceService>();

        // AI Agents
        services.AddHttpClient<IDocumentAgent, DocumentAgent>();
        services.AddScoped<IDocumentAgent, DocumentAgent>();

        // Validation Agent with SAP HTTP client
        services.AddHttpClient("SAP", client =>
        {
            var sapBaseUrl = configuration["SAP:BaseUrl"] ?? "https://sap-api.example.com";
            var sapApiKey = configuration["SAP:ApiKey"] ?? "";
            
            client.BaseAddress = new Uri(sapBaseUrl);
            client.DefaultRequestHeaders.Add("APIKey", sapApiKey);
            client.Timeout = TimeSpan.FromSeconds(30);
        });
        services.AddScoped<IReferenceDataService, ReferenceDataService>();
        services.AddScoped<IValidationAgent, ValidationAgent>();

        // Proactive Validator (on-upload field presence checks)
        services.AddScoped<IProactiveValidator, ProactiveValidator>();

        // Perceptual Hash Service (duplicate image detection)
        services.AddSingleton<IPerceptualHashService, PerceptualHashService>();

        // Confidence Score Service
        services.AddScoped<IConfidenceScoreService, ConfidenceScoreService>();

        // Recommendation Agent
        services.AddScoped<IRecommendationAgent, RecommendationAgent>();

        // Enhanced Validation Report Service
        services.AddScoped<IEnhancedValidationReportService, EnhancedValidationReportService>();

        // Email Agent
        services.AddScoped<IEmailAgent, EmailAgent>();

        // Notification Agent
        services.AddScoped<INotificationAgent, NotificationAgent>();

        // Guardrail Services (for Chat)
        services.AddScoped<IInputGuardrailService, InputGuardrailService>();
        services.AddScoped<IAuthorizationGuardrailService, AuthorizationGuardrailService>();
        services.AddScoped<IOutputGuardrailService, OutputGuardrailService>();

        // Vector Search and Embedding Services (Optional - for Chat/Analytics features)
        var azureSearchEndpoint = configuration["AzureAISearch:Endpoint"];
        var azureSearchApiKey = configuration["AzureAISearch:ApiKey"];
        
        if (!string.IsNullOrEmpty(azureSearchEndpoint) && !string.IsNullOrEmpty(azureSearchApiKey))
        {
            services.AddSingleton<IVectorSearchService, AzureAISearchService>();
            services.AddScoped<IEmbeddingService, EmbeddingService>();
            services.AddScoped<IAnalyticsEmbeddingPipeline, AnalyticsEmbeddingPipeline>();
        }
        else
        {
            // Register null/stub implementations when Azure AI Search is not configured
            services.AddSingleton<IVectorSearchService, NullVectorSearchService>();
            services.AddScoped<IEmbeddingService, NullEmbeddingService>();
            services.AddScoped<IAnalyticsEmbeddingPipeline, NullAnalyticsEmbeddingPipeline>();
        }
        
        // Chat and Analytics services - always register if Azure OpenAI is configured
        var azureOpenAIEndpoint = configuration["AzureOpenAI:Endpoint"];
        var azureOpenAIApiKey = configuration["AzureOpenAI:ApiKey"];
        
        if (!string.IsNullOrEmpty(azureOpenAIEndpoint) && !string.IsNullOrEmpty(azureOpenAIApiKey))
        {
            services.AddScoped<IChatService, ChatService>();
            services.AddScoped<IAnalyticsAgent, AnalyticsAgent>();
        }
        else
        {
            services.AddScoped<IChatService, NullChatService>();
            services.AddScoped<IAnalyticsAgent, NullAnalyticsAgent>();
        }

        // Workflow Orchestrator
        services.AddScoped<IWorkflowOrchestrator, WorkflowOrchestrator>();

        // Audit Logging
        services.AddScoped<IAuditLogService, AuditLogService>();

        // Request Queue Service
        services.AddScoped<IRequestQueueService, RequestQueueService>();

        // Correlation ID Service
        services.AddScoped<ICorrelationIdService, CorrelationIdService>();

        // Azure services configuration will be added in subsequent tasks
        
        // Background workflow processor
        services.AddSingleton<BackgroundWorkflowProcessor>();
        services.AddHostedService(provider => provider.GetRequiredService<BackgroundWorkflowProcessor>());
        services.AddSingleton<IBackgroundWorkflowQueue, BackgroundWorkflowQueue>();

        // Teams Bot Framework (Singleton — required by Bot Framework SDK)
        services.AddSingleton<IBotFrameworkHttpAdapter, AdapterWithErrorHandler>();
        services.AddSingleton<PilotTeamsConfig>(sp =>
        {
            var config = new PilotTeamsConfig
            {
                IsPilotMode = configuration.GetValue<bool>("TeamsBot:IsPilotMode", true)
            };
            return config;
        });
        services.AddSingleton<IBot, TeamsBotService>();

        // Teams proactive notification service (Singleton — depends on Singleton adapter + PilotConfig)
        services.AddSingleton<ITeamsNotificationService, TeamsNotificationService>();
        
        return services;
    }
}
