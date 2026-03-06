using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Infrastructure.Services.Plugins;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;
using Microsoft.SemanticKernel.Connectors.OpenAI;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class ChatService : IChatService
{
    private readonly IApplicationDbContext _context;
    private readonly IInputGuardrailService _inputGuardrail;
    private readonly IAuthorizationGuardrailService _authorizationGuardrail;
    private readonly IOutputGuardrailService _outputGuardrail;
    private readonly IVectorSearchService _vectorSearchService;
    private readonly IEmbeddingService _embeddingService;
    private readonly ILogger<ChatService> _logger;
    private readonly Kernel _kernel;
    private const int MaxConversationMessages = 10;

    public ChatService(
        IApplicationDbContext context,
        IInputGuardrailService inputGuardrail,
        IAuthorizationGuardrailService authorizationGuardrail,
        IOutputGuardrailService outputGuardrail,
        IVectorSearchService vectorSearchService,
        IEmbeddingService embeddingService,
        IConfiguration configuration,
        ILogger<ChatService> logger)
    {
        _context = context;
        _inputGuardrail = inputGuardrail;
        _authorizationGuardrail = authorizationGuardrail;
        _outputGuardrail = outputGuardrail;
        _vectorSearchService = vectorSearchService;
        _embeddingService = embeddingService;
        _logger = logger;

        // Build Semantic Kernel
        var endpoint = configuration["AzureOpenAI:Endpoint"] ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        
        // Add analytics plugin
        builder.Plugins.AddFromObject(new AnalyticsPlugin(context, vectorSearchService, embeddingService));
        
        _kernel = builder.Build();
    }

    public async Task<ChatResponse> ProcessQueryAsync(
        Guid userId,
        string query,
        Guid? conversationId = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Processing chat query for user {UserId}", userId);

            // Step 1: Input Guardrails
            await _inputGuardrail.ValidateInputAsync(query, userId, cancellationToken);

            // Step 2: Authorization Check
            await _authorizationGuardrail.ValidateUserAccessAsync(userId, cancellationToken);
            var dataScope = await _authorizationGuardrail.GetUserDataScopeAsync(userId, cancellationToken);

            // Step 3: Vector Search (optional - skip if not configured)
            var relevantData = new List<VectorSearchResult>();
            var context = "";
            
            // Check if vector search is available (not the null implementation)
            if (_vectorSearchService.GetType().Name != "NullVectorSearchService")
            {
                try
                {
                    var queryEmbedding = await _embeddingService.GenerateEmbeddingAsync(query, cancellationToken);
                    var filter = new VectorSearchFilter
                    {
                        States = dataScope.States,
                        Campaigns = dataScope.Campaigns
                    };
                    relevantData = await _vectorSearchService.SearchAsync(queryEmbedding, topK: 5, filter: filter, cancellationToken);
                    
                    // Build context from vector search results
                    context = string.Join("\n\n", relevantData.Select(d => $"- {d.Content}"));
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Vector search failed, continuing without it");
                }
            }
            else
            {
                _logger.LogInformation("Vector search not configured, using database queries only");
            }

            // Step 4: Get or create conversation
            var conversation = conversationId.HasValue
                ? await _context.Conversations
                    .Include(c => c.Messages.OrderByDescending(m => m.CreatedAt).Take(MaxConversationMessages))
                    .FirstOrDefaultAsync(c => c.Id == conversationId.Value && c.UserId == userId, cancellationToken)
                : null;

            if (conversation == null)
            {
                conversation = new Conversation
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    LastMessageAt = DateTime.UtcNow
                };
                _context.Conversations.Add(conversation);
            }

            // Step 6: Build chat history
            var chatHistory = new ChatHistory();
            
            // Add system message with database query capabilities
            var systemMessage = @"You are an analytics assistant for the Bajaj Document Processing System.

You have access to database query functions to retrieve real-time submission data:
- GetPendingSubmissions: Show pending submissions (ASM/HQ/all)
- GetApprovedSubmissions: List approved requests
- GetRejectedSubmissions: Show rejected with reasons
- GetSubmissionsSummary: Overall status summary
- GetKPIs: Performance metrics

When users ask about submissions, approvals, rejections, or statistics, USE THESE FUNCTIONS to get accurate data.
Always cite specific data sources, time ranges, and metrics in your response.
Be concise and focus on the key insights.";

            if (!string.IsNullOrEmpty(context))
            {
                systemMessage += $@"

Additional context from analytics database:
{context}";
            }
            
            chatHistory.AddSystemMessage(systemMessage);

            // Add conversation history (last 10 messages)
            if (conversation.Messages.Any())
            {
                foreach (var msg in conversation.Messages.OrderBy(m => m.CreatedAt))
                {
                    if (msg.Role == "user")
                    {
                        chatHistory.AddUserMessage(msg.Content);
                    }
                    else
                    {
                        chatHistory.AddAssistantMessage(msg.Content);
                    }
                }
            }

            // Add current query
            chatHistory.AddUserMessage(query);

            // Step 7: Semantic Kernel Processing with function calling
            var chatCompletionService = _kernel.GetRequiredService<IChatCompletionService>();
            var executionSettings = new OpenAIPromptExecutionSettings
            {
                MaxTokens = 1000,
                Temperature = 0.7,
                TopP = 0.9,
                ToolCallBehavior = ToolCallBehavior.AutoInvokeKernelFunctions // Enable function calling
            };

            var result = await chatCompletionService.GetChatMessageContentAsync(
                chatHistory,
                executionSettings,
                _kernel,
                cancellationToken);

            var response = result.Content ?? "I apologize, but I couldn't generate a response.";

            // Step 8: Output Guardrails
            var sanitizedResponse = await _outputGuardrail.ValidateAndSanitizeOutputAsync(
                response,
                relevantData,
                cancellationToken);

            // Step 9: Store conversation
            var userMsg = new ConversationMessage
            {
                Id = Guid.NewGuid(),
                ConversationId = conversation.Id,
                Role = "user",
                Content = query
            };
            _context.ConversationMessages.Add(userMsg);

            var assistantMsg = new ConversationMessage
            {
                Id = Guid.NewGuid(),
                ConversationId = conversation.Id,
                Role = "assistant",
                Content = sanitizedResponse
            };
            _context.ConversationMessages.Add(assistantMsg);

            conversation.LastMessageAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            // Step 10: Build response with citations
            var citations = relevantData.Select(d => new DataCitation
            {
                Source = d.Id,
                TimeRange = d.Metadata.TimeRange ?? "Unknown",
                Metrics = new Dictionary<string, object>
                {
                    { "SubmissionCount", d.Metadata.SubmissionCount ?? 0 },
                    { "ApprovalRate", d.Metadata.ApprovalRate ?? 0 },
                    { "AvgConfidence", d.Metadata.AvgConfidence ?? 0 }
                }
            }).ToList();

            _logger.LogInformation("Chat query processed successfully for user {UserId}", userId);

            return new ChatResponse
            {
                Message = sanitizedResponse,
                Citations = citations,
                ConversationId = conversation.Id
            };
        }
        catch (InputValidationException ex)
        {
            _logger.LogWarning(ex, "Input validation failed for user {UserId}", userId);
            throw;
        }
        catch (Application.Common.Interfaces.UnauthorizedAccessException ex)
        {
            _logger.LogWarning(ex, "Authorization failed for user {UserId}", userId);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing chat query for user {UserId}", userId);
            throw;
        }
    }

    public async Task<List<ChatMessage>> GetConversationHistoryAsync(
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        var messages = await _context.ConversationMessages
            .Where(m => m.ConversationId == conversationId)
            .OrderBy(m => m.CreatedAt)
            .Select(m => new ChatMessage
            {
                Id = m.Id,
                ConversationId = m.ConversationId,
                Role = m.Role,
                Content = m.Content,
                CreatedAt = m.CreatedAt
            })
            .ToListAsync(cancellationToken);

        return messages;
    }

    public async Task ClearConversationAsync(Guid conversationId, CancellationToken cancellationToken = default)
    {
        var conversation = await _context.Conversations
            .Include(c => c.Messages)
            .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

        if (conversation != null)
        {
            foreach (var message in conversation.Messages)
            {
                message.IsDeleted = true;
            }
            conversation.IsDeleted = true;
            await _context.SaveChangesAsync(cancellationToken);
        }
    }
}
