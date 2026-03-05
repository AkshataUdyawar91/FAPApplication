using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.Infrastructure.Services;

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
        services.AddScoped<IValidationAgent, ValidationAgent>();

        // Confidence Score Service
        services.AddScoped<IConfidenceScoreService, ConfidenceScoreService>();

        // Recommendation Agent
        services.AddScoped<IRecommendationAgent, RecommendationAgent>();

        // Email Agent
        services.AddScoped<IEmailAgent, EmailAgent>();

        // Notification Agent
        services.AddScoped<INotificationAgent, NotificationAgent>();

        // Vector Search and Embedding Services (Optional - for Chat/Analytics features)
        var azureSearchEndpoint = configuration["AzureAISearch:Endpoint"];
        var azureSearchApiKey = configuration["AzureAISearch:ApiKey"];
        
        if (!string.IsNullOrEmpty(azureSearchEndpoint) && !string.IsNullOrEmpty(azureSearchApiKey))
        {
            services.AddSingleton<IVectorSearchService, AzureAISearchService>();
            services.AddScoped<IEmbeddingService, EmbeddingService>();
            services.AddScoped<IAnalyticsEmbeddingPipeline, AnalyticsEmbeddingPipeline>();
            services.AddScoped<IChatService, ChatService>();
            services.AddScoped<IAnalyticsAgent, AnalyticsAgent>();
        }
        else
        {
            // Register null/stub implementations when Azure AI Search is not configured
            services.AddSingleton<IVectorSearchService, NullVectorSearchService>();
            services.AddScoped<IEmbeddingService, NullEmbeddingService>();
            services.AddScoped<IAnalyticsEmbeddingPipeline, NullAnalyticsEmbeddingPipeline>();
            services.AddScoped<IChatService, NullChatService>();
            services.AddScoped<IAnalyticsAgent, NullAnalyticsAgent>();
        }

        // Workflow Orchestrator
        services.AddScoped<IWorkflowOrchestrator, WorkflowOrchestrator>();

        // Audit Logging
        services.AddScoped<IAuditLogService, AuditLogService>();

        // Request Queue Service
        services.AddScoped<IRequestQueueService, RequestQueueService>();

        // Azure services configuration will be added in subsequent tasks
        
        return services;
    }
}
