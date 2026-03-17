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

/// <summary>
/// Service for processing conversational AI chat queries with guardrails and semantic search
/// </summary>
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
    private readonly AnalyticsPlugin _analyticsPlugin;
    private readonly ICorrelationIdService _correlationIdService;
    private const int MaxConversationMessages = 10;

    public ChatService(
        IApplicationDbContext context,
        IInputGuardrailService inputGuardrail,
        IAuthorizationGuardrailService authorizationGuardrail,
        IOutputGuardrailService outputGuardrail,
        IVectorSearchService vectorSearchService,
        IEmbeddingService embeddingService,
        IConfiguration configuration,
        ILogger<ChatService> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _inputGuardrail = inputGuardrail;
        _authorizationGuardrail = authorizationGuardrail;
        _outputGuardrail = outputGuardrail;
        _vectorSearchService = vectorSearchService;
        _embeddingService = embeddingService;
        _logger = logger;
        _correlationIdService = correlationIdService;

        // Build Semantic Kernel
        var endpoint = configuration["AzureOpenAI:Endpoint"] ?? throw new InvalidOperationException("AzureOpenAI:Endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] ?? throw new InvalidOperationException("AzureOpenAI:ApiKey not configured");
        var deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        var builder = Kernel.CreateBuilder();
        builder.AddAzureOpenAIChatCompletion(deploymentName, endpoint, apiKey);
        
        // Add analytics plugin
        var analyticsPlugin = new AnalyticsPlugin(context, vectorSearchService, embeddingService);
        builder.Plugins.AddFromObject(analyticsPlugin);
        
        _kernel = builder.Build();
        _analyticsPlugin = analyticsPlugin;
    }

    /// <summary>
    /// Processes a chat query with input validation, authorization, vector search, and output guardrails
    /// </summary>
    /// <param name="userId">The ID of the user making the query</param>
    /// <param name="query">The user's chat query</param>
    /// <param name="conversationId">Optional ID of an existing conversation to continue</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A chat response with the AI-generated message, citations, and conversation ID</returns>
    /// <exception cref="InputValidationException">Thrown when input validation fails</exception>
    /// <exception cref="Application.Common.Interfaces.UnauthorizedAccessException">Thrown when authorization fails</exception>
    public async Task<ChatResponse> ProcessQueryAsync(
        Guid userId,
        string query,
        Guid? conversationId = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var correlationId = _correlationIdService.GetCorrelationId();
            _logger.LogInformation(
                "Processing chat query for user {UserId}. CorrelationId: {CorrelationId}",
                userId, correlationId);

            // Set current user context for analytics queries
            _analyticsPlugin.SetCurrentUser(userId);

            // Look up user role for role-based data scoping
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
            var userRole = user?.Role.ToString() ?? "Agency";

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
            
            // Query user's submission data — match dashboard behavior per role
            // Agency: only their own submissions. ASM/HQ: all submissions (they're reviewers).
            var packagesQuery = _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.ConfidenceScore)
                .AsQueryable();

            if (userRole == "Agency")
            {
                packagesQuery = packagesQuery.Where(p => p.SubmittedByUserId == userId);
            }

            var userPackages = packagesQuery
                .OrderByDescending(p => p.CreatedAt)
                .Take(20)
                .ToList();

            _logger.LogInformation("ChatService - UserId: {UserId}, Role: {Role}, Packages count: {Count}", userId, userRole, userPackages.Count);

            var userPendingASM = userPackages.Count(p => p.State == Domain.Enums.PackageState.PendingASM);
            var userPendingHQ = userPackages.Count(p => p.State == Domain.Enums.PackageState.PendingRA);
            var userApproved = userPackages.Count(p => p.State == Domain.Enums.PackageState.Approved);
            var userRejected = userPackages.Count(p => 
                p.State == Domain.Enums.PackageState.ASMRejected || 
                p.State == Domain.Enums.PackageState.RARejected);
            var userUploaded = userPackages.Count(p => p.State == Domain.Enums.PackageState.Uploaded);
            var userProcessing = userPackages.Count(p => 
                p.State == Domain.Enums.PackageState.Extracting ||
                p.State == Domain.Enums.PackageState.Validating);

            var userSubmissionsList = userPackages
                .OrderByDescending(p => p.CreatedAt)
                .Take(20)
                .Select(p => {
                    var fapId = $"FAP-{p.Id.ToString().Substring(0, 8).ToUpper()}";
                    var confidence = p.ConfidenceScore != null ? $"{(p.ConfidenceScore.OverallConfidence * 100):F0}%" : "N/A";
                    
                    // Extract invoice details and PO info from dedicated entities
                    string invoiceNumber = "N/A";
                    string invoiceAmount = "N/A";
                    string poNumber = "N/A";
                    string poDocId = "";
                    
                    // Read PO data from dedicated PO entity
                    if (p.PO != null)
                    {
                        poDocId = p.PO.Id.ToString();
                        poNumber = p.PO.PONumber ?? "N/A";
                        
                        // Fallback: try ExtractedDataJson if PONumber field is empty
                        if (poNumber == "N/A" && !string.IsNullOrEmpty(p.PO.ExtractedDataJson))
                        {
                            try
                            {
                                var data = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(p.PO.ExtractedDataJson);
                                if (data.TryGetProperty("PONumber", out var po))
                                    poNumber = po.GetString() ?? "N/A";
                                else if (data.TryGetProperty("poNumber", out var po2))
                                    poNumber = po2.GetString() ?? "N/A";
                                else if (data.TryGetProperty("PurchaseOrderNumber", out var po3))
                                    poNumber = po3.GetString() ?? "N/A";
                            }
                            catch { /* skip parsing errors */ }
                        }
                    }
                    
                    // Read Invoice data from dedicated Invoices collection
                    var firstInvoice = p.Invoices.FirstOrDefault();
                    if (firstInvoice != null)
                    {
                        invoiceNumber = firstInvoice.InvoiceNumber ?? "N/A";
                        if (firstInvoice.TotalAmount != null && firstInvoice.TotalAmount > 0)
                        {
                            invoiceAmount = $"₹{firstInvoice.TotalAmount}";
                        }
                        
                        // Fallback: try ExtractedDataJson if typed fields are empty
                        if ((invoiceNumber == "N/A" || invoiceAmount == "N/A") && !string.IsNullOrEmpty(firstInvoice.ExtractedDataJson))
                        {
                            try
                            {
                                var data = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(firstInvoice.ExtractedDataJson);
                                
                                if (invoiceNumber == "N/A")
                                {
                                    if (data.TryGetProperty("InvoiceNumber", out var invNum))
                                        invoiceNumber = invNum.GetString() ?? "N/A";
                                    else if (data.TryGetProperty("invoiceNumber", out var invNum2))
                                        invoiceNumber = invNum2.GetString() ?? "N/A";
                                }
                                
                                if (invoiceAmount == "N/A")
                                {
                                    if (data.TryGetProperty("TotalAmount", out var amt))
                                        invoiceAmount = amt.ValueKind == System.Text.Json.JsonValueKind.Number ? $"₹{amt.GetDecimal()}" : $"₹{amt.GetString()}";
                                    else if (data.TryGetProperty("totalAmount", out var amt2))
                                        invoiceAmount = amt2.ValueKind == System.Text.Json.JsonValueKind.Number ? $"₹{amt2.GetDecimal()}" : $"₹{amt2.GetString()}";
                                    else if (data.TryGetProperty("InvoiceAmount", out var amt3))
                                        invoiceAmount = amt3.ValueKind == System.Text.Json.JsonValueKind.Number ? $"₹{amt3.GetDecimal()}" : $"₹{amt3.GetString()}";
                                }
                            }
                            catch { /* skip parsing errors */ }
                        }
                    }
                    
                    var docCount = (p.PO != null ? 1 : 0) + p.Invoices.Count;
                    var poDocPart = !string.IsNullOrEmpty(poDocId) ? $", PODocId={poDocId}" : "";
                    return $"- {fapId} (FullId={p.Id}): Status={p.State}, Submitted={p.CreatedAt:yyyy-MM-dd}, PO={poNumber}, InvoiceNo={invoiceNumber}, InvoiceAmount={invoiceAmount}, Confidence={confidence}, Documents={docCount}{poDocPart}";
                })
                .ToList();

            var roleDescription = userRole switch
            {
                "Agency" => "You are helping an Agency user who submits FAP documents for approval.",
                "ASM" => "You are helping an ASM (Area Sales Manager) who reviews and approves/rejects FAP submissions from agencies.",
                "HQ" => "You are helping an HQ/RA (Regional Approver) who gives final approval on FAP submissions after ASM approval.",
                _ => "You are helping a user of the FAP system."
            };

            var userDataContext = $@"
CURRENT USER: Role={userRole}
{roleDescription}

SUBMISSION DATA (most recent 20):
Total: {userPackages.Count}
Uploaded (not yet processed): {userUploaded}
Pending with ASM: {userPendingASM}
Pending with HQ/RA: {userPendingHQ}
Approved: {userApproved}
Rejected: {userRejected}
Processing (extracting/validating/scoring): {userProcessing}

Submissions:
{string.Join("\n", userSubmissionsList)}";

            // Add system message with database query capabilities
            var systemMessage = @"You are a friendly analytics assistant for the Bajaj FAP (Field Activity Plan) Document Processing System.

IMPORTANT RULES:
1. ONLY use the CURRENT USER'S DATA section below to answer questions. This is the user's real, accurate data.
2. NEVER make up numbers or guess. If the data is not in the CURRENT USER'S DATA section, say you don't have that information.
3. NEVER expose internal details, error messages, or technical information to the user.
4. Always respond in a clean, conversational, user-friendly tone.
5. Keep responses SHORT and DIRECT — only answer what the user asked. Do NOT dump extra details they didn't ask for.
6. When user asks about status, just say the status in plain English (e.g. 'Pending with ASM' not 'PendingASMApproval'). Do NOT list submitted date, confidence, documents, PO, invoice etc unless specifically asked.
7. When user asks about invoice amount, just give the amount. When they ask about PO, just give the PO number. Only provide what was asked.
8. Use friendly status names: PendingASMApproval = 'Pending with ASM', PendingHQApproval = 'Pending with RA', Uploaded = 'Uploaded', Approved = 'Approved', RejectedByASM = 'Rejected by ASM', RejectedByRA = 'Rejected by RA'.
9. Do NOT show [PHONE_REDACTED] or any redacted labels — if a value looks redacted, just say the value is not available.
10. CRITICAL: When the user asks to 'show', 'view', 'open', or 'see' a PO, they want to VIEW THE ACTUAL PO DOCUMENT — NOT the PO number. You MUST respond with a clickable link using the PODocId: 'You can view your PO here: [View PO](doc://{PODocId})'. NEVER respond with just the PO number when the user asks to show/view/open a PO. The PO number is only shown when the user explicitly asks 'what is the PO number?'.
11. If a submission does not have a PODocId, say 'The PO document is not available for this submission.'
12. For ASM users: when the user asks to approve, reject, review, or see validations for a submission, provide a navigation link: 'You can review and take action here: [Review Submission](nav://asm-review/{FullId})'. Use the FullId (the full GUID) from the submission data, NOT the short FAP ID.
13. For HQ/RA users: same as above but use: [Review Submission](nav://hq-review/{FullId})
14. For Agency users: when they ask to view details of a submission, use: [View Submission](nav://agency-detail/{FullId})
15. NEVER show the FullId as text to the user — only use it inside nav:// links.";

            if (!string.IsNullOrEmpty(context))
            {
                systemMessage += $@"

Additional context from analytics database:
{context}";
            }

            // Always append user-specific data
            systemMessage += userDataContext;
            
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

            // Step 7: Semantic Kernel Processing — no function calling
            // User-specific data is already injected into the system prompt context.
            // Plugin functions query ALL users and cannot be scoped, so we disable them.
            var chatCompletionService = _kernel.GetRequiredService<IChatCompletionService>();
            var executionSettings = new OpenAIPromptExecutionSettings
            {
                ToolCallBehavior = null // Disable function calling — use system prompt data only
            };

            var result = await chatCompletionService.GetChatMessageContentAsync(
                chatHistory,
                executionSettings,
                kernel: null, // Don't pass kernel to prevent function discovery
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

    /// <summary>
    /// Retrieves the message history for a conversation
    /// </summary>
    /// <param name="conversationId">The ID of the conversation</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A list of chat messages ordered by creation date</returns>
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

    /// <summary>
    /// Retrieves a conversation by its ID
    /// </summary>
    /// <param name="conversationId">The ID of the conversation</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>The conversation if found, otherwise null</returns>
    public async Task<Conversation?> GetConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken = default)
    {
        var conversation = await _context.Conversations
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == conversationId, cancellationToken);

        return conversation;
    }

    /// <summary>
    /// Clears a conversation by soft-deleting it and all its messages
    /// </summary>
    /// <param name="conversationId">The ID of the conversation to clear</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A task representing the asynchronous operation</returns>
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
