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

        // Vector Search and Embedding Services
        services.AddSingleton<IVectorSearchService, AzureAISearchService>();
        services.AddScoped<IEmbeddingService, EmbeddingService>();
        services.AddScoped<IAnalyticsEmbeddingPipeline, AnalyticsEmbeddingPipeline>();

        // Guardrail Services
        services.AddMemoryCache();
        services.AddScoped<IInputGuardrailService, InputGuardrailService>();
        services.AddScoped<IAuthorizationGuardrailService, AuthorizationGuardrailService>();
        services.AddScoped<IOutputGuardrailService, OutputGuardrailService>();

        // Chat Service
        services.AddScoped<IChatService, ChatService>();

        // Analytics Agent
        services.AddScoped<IAnalyticsAgent, AnalyticsAgent>();

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
