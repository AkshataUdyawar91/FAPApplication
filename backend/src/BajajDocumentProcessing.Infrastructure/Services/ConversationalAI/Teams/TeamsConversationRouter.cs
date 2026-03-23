using Microsoft.Bot.Builder;
using Microsoft.Bot.Schema;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json.Linq;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Infrastructure.Persistence;
using BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams.Models;

namespace BajajDocumentProcessing.Infrastructure.Services.ConversationalAI.Teams;

/// <summary>
/// Main orchestrator for Teams text messages from Circle Heads, ASMs, and RAs.
/// Routes through: feature flag → input guardrail → identity resolution → intent classification → handler.
/// Sends responses via turnContext.SendActivityAsync() directly.
/// </summary>
public class TeamsConversationRouter
{
    private readonly ApproverResolver _approverResolver;
    private readonly ITeamsIntentClassifier _intentClassifier;
    private readonly ApproverScopedQueryService _queryService;
    private readonly IInputGuardrailService _guardrailService;
    private readonly ApplicationDbContext _dbContext;
    private readonly IConfiguration _configuration;
    private readonly ILogger<TeamsConversationRouter> _logger;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly BotAuthSessionStore _authSessionStore;
    private readonly string _portalBaseUrl;

    private const int MaxPendingDisplay = 5;

    public TeamsConversationRouter(
        ApproverResolver approverResolver,
        ITeamsIntentClassifier intentClassifier,
        ApproverScopedQueryService queryService,
        IInputGuardrailService guardrailService,
        ApplicationDbContext dbContext,
        IConfiguration configuration,
        ILogger<TeamsConversationRouter> logger,
        IServiceScopeFactory scopeFactory,
        BotAuthSessionStore authSessionStore)
    {
        _approverResolver = approverResolver;
        _intentClassifier = intentClassifier;
        _queryService = queryService;
        _guardrailService = guardrailService;
        _dbContext = dbContext;
        _configuration = configuration;
        _logger = logger;
        _scopeFactory = scopeFactory;
        _authSessionStore = authSessionStore;
        _portalBaseUrl = configuration["TeamsBot:PortalBaseUrl"] ?? "http://localhost:8080";
    }

    /// <summary>
    /// Processes a text message from a Teams approver through the full pipeline:
    /// feature flag → guardrail → identity → classify → handle → audit log.
    /// </summary>
    /// <param name="userText">The raw text message from the user</param>
    /// <param name="aadObjectId">The Azure AD Object ID from Activity.From.AadObjectId</param>
    /// <param name="turnContext">The Bot Framework turn context for sending responses</param>
    /// <param name="ct">Cancellation token</param>
    public async Task HandleAsync(
        string userText, string aadObjectId, ITurnContext turnContext, CancellationToken ct)
    {
        string botResponse;
        string? intent = null;
        Guid? userId = null;
        string? userRole = null;

        // Step 1: Feature flag check
        var featureEnabled = _configuration.GetValue<bool>("Features:TeamsConversationalAI");
        if (!featureEnabled)
        {
            botResponse = "I can send you approval notifications. For other queries, please use the ClaimsIQ portal.";
            await turnContext.SendActivityAsync(MessageFactory.Text(botResponse), ct);
            return;
        }

        // Step 2: Input guardrail — block injection attempts before any processing
        try
        {
            await _guardrailService.ValidateInputAsync(userText, Guid.Empty, ct);
        }
        catch (InputValidationException ex)
        {
            _logger.LogWarning("Input injection detected from AAD {AadObjectId}: {Message}", aadObjectId, ex.Message);
            botResponse = "⚠️ Your message was blocked for security reasons. Please rephrase your question.";
            await turnContext.SendActivityAsync(MessageFactory.Text(botResponse), ct);
            LogAuditFireAndForget(null, null, userText, botResponse, "BLOCKED");
            return;
        }

        // Step 3: Resolve approver identity
        var conversationId = turnContext.Activity.Conversation?.Id ?? string.Empty;
        var approver = await ResolveApproverWithAuthAsync(userText, aadObjectId, conversationId, turnContext, ct);

        // null means the login flow is in progress — response already sent
        if (approver == null)
            return;

        userId = approver.UserId;
        userRole = approver.Role;

        // Handle "logout" command
        if (userText.Trim().Equals("logout", StringComparison.OrdinalIgnoreCase))
        {
            _authSessionStore.RemoveSession(conversationId);
            botResponse = "🔓 You've been logged out. Send any message to log in again.";
            await turnContext.SendActivityAsync(MessageFactory.Text(botResponse), ct);
            LogAuditFireAndForget(userId, userRole, userText, botResponse, "LOGOUT", approver.AssignedStates);
            return;
        }

        // Step 4: Classify intent
        var intentResult = await _intentClassifier.ClassifyAsync(userText, ct);
        intent = intentResult.Intent;

        _logger.LogInformation(
            "TeamsConversationRouter: User {UserId} ({Role}), Intent={Intent}, Confidence={Confidence}",
            approver.UserId, approver.Role, intent, intentResult.Confidence);

        // Step 5: Route to handler based on intent
        botResponse = intent switch
        {
            "PENDING_APPROVALS" => await HandlePendingApprovalsAsync(approver, turnContext, ct),
            "SUBMISSION_DETAIL" => await HandleSubmissionDetailAsync(approver, intentResult, turnContext, ct),
            "APPROVED_LIST" => await HandleApprovedListAsync(approver, intentResult, turnContext, ct),
            "REJECTED_LIST" => await HandleRejectedListAsync(approver, intentResult, turnContext, ct),
            "ACTIVITY_SUMMARY" => await HandleActivitySummaryAsync(approver, turnContext, ct),
            "HELP" => await HandleHelpAsync(turnContext, ct),
            "GREETING" => await HandleGreetingAsync(approver, turnContext, ct),
            _ => await HandleFallbackAsync(turnContext, ct)
        };

        // Step 12: Audit log (fire-and-forget)
        LogAuditFireAndForget(userId, userRole, userText, botResponse, intent, approver.AssignedStates);
    }

    /// <summary>
    /// Resolves the approver identity using a 3-tier cascade:
    ///   Tier 1: Teams SSO token (silent, zero-friction if configured)
    ///   Tier 2: AAD Object ID lookup (zero-friction if pre-populated)
    ///   Tier 3: Conversation FK / session store (zero-friction for returning users)
    ///   Fallback: Login card with email/password (one-time, auto-populates AAD Object ID)
    /// Returns null when the login flow is in progress (response already sent to user).
    /// </summary>
    private async Task<ApproverResolvedUser?> ResolveApproverWithAuthAsync(
        string userText, string aadObjectId, string conversationId,
        ITurnContext turnContext, CancellationToken ct)
    {
        // --- Tier 1: Teams SSO (silent token from bot manifest webApplicationInfo) ---
        _logger.LogDebug("Auth Tier 1 (SSO): Attempting for conversation {ConversationId}", conversationId);
        var ssoApprover = await _approverResolver.ResolveBySsoTokenAsync(turnContext, ct);
        if (ssoApprover != null)
        {
            _logger.LogInformation("Auth Tier 1 (SSO): ✓ Resolved {Email} ({Role})", ssoApprover.DisplayName, ssoApprover.Role);
            return ssoApprover;
        }
        _logger.LogDebug("Auth Tier 1 (SSO): ✗ No token or no match — falling to Tier 2");

        // --- Tier 2: AAD Object ID direct lookup ---
        _logger.LogDebug("Auth Tier 2 (AAD): Attempting for AadObjectId {AadObjectId}", aadObjectId);
        var aadApprover = await _approverResolver.ResolveAsync(aadObjectId, ct);
        if (aadApprover != null)
        {
            _logger.LogInformation("Auth Tier 2 (AAD): ✓ Resolved {Email} ({Role})", aadApprover.DisplayName, aadApprover.Role);
            return aadApprover;
        }
        _logger.LogDebug("Auth Tier 2 (AAD): ✗ No match — falling to Tier 3");

        // --- Tier 3: Existing session from prior login ---
        _logger.LogDebug("Auth Tier 3 (Session): Checking session for conversation {ConversationId}", conversationId);
        var session = _authSessionStore.GetSession(conversationId);
        if (session?.Step == AuthStep.Authenticated && session.ResolvedUser != null)
        {
            _logger.LogInformation("Auth Tier 3 (Session): ✓ Resolved {Email} ({Role})", session.ResolvedUser.DisplayName, session.ResolvedUser.Role);
            return session.ResolvedUser;
        }
        _logger.LogDebug("Auth Tier 3 (Session): ✗ No active session — showing login card");

        // --- Fallback: Login card (one-time, auto-populates AAD Object ID on success) ---
        await SendLoginCardAsync(turnContext, ct);
        return null;
    }

    /// <summary>
    /// Sends an Adaptive Card with email and masked password inputs for credential-based login.
    /// The card submits with action "bot_login" which is handled by TeamsBotService.HandleBotLoginAsync.
    /// </summary>
    private static async Task SendLoginCardAsync(ITurnContext turnContext, CancellationToken ct)
    {
        var card = new JObject
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3",
            ["body"] = new JArray
            {
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = "🔐 Please log in to continue",
                    ["weight"] = "Bolder",
                    ["size"] = "Medium"
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = "Email",
                    ["size"] = "Small",
                    ["weight"] = "Bolder"
                },
                new JObject
                {
                    ["type"] = "Input.Text",
                    ["id"] = "loginEmail",
                    ["placeholder"] = "Enter your email",
                    ["style"] = "Email"
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = "Password",
                    ["size"] = "Small",
                    ["weight"] = "Bolder"
                },
                new JObject
                {
                    ["type"] = "Input.Text",
                    ["id"] = "loginPassword",
                    ["placeholder"] = "Enter your password",
                    ["style"] = "Password"
                }
            },
            ["actions"] = new JArray
            {
                new JObject
                {
                    ["type"] = "Action.Submit",
                    ["title"] = "Sign In",
                    ["style"] = "positive",
                    ["data"] = new JObject
                    {
                        ["action"] = "bot_login",
                        ["cardVersion"] = "1.0"
                    }
                }
            }
        };

        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };

        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), ct);
    }

    /// <summary>
    /// Handles PENDING_APPROVALS intent — builds an Adaptive Card with pending items.
    /// Shows first 5 items ordered by SubmittedAt ascending. "View all" link if more than 5.
    /// "You're all caught up" message when no pending items exist.
    /// </summary>
    private async Task<string> HandlePendingApprovalsAsync(
        ApproverResolvedUser approver, ITurnContext turnContext, CancellationToken ct)
    {
        var pending = await _queryService.GetPendingApprovalsAsync(
            approver.UserId, approver.Role, approver.AssignedStates, ct);

        if (pending.Count == 0)
        {
            var msg = "✅ You're all caught up — no pending approvals right now.";
            await turnContext.SendActivityAsync(MessageFactory.Text(msg), ct);
            return msg;
        }

        var totalCount = pending.Count;
        var displayItems = pending.OrderBy(p => p.SubmittedAt).Take(MaxPendingDisplay).ToList();

        var card = BuildPendingApprovalsCard(displayItems, totalCount);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };

        var activity = MessageFactory.Attachment(attachment);
        await turnContext.SendActivityAsync(activity, ct);

        return $"Pending approvals card sent ({totalCount} items)";
    }

    /// <summary>
    /// Handles SUBMISSION_DETAIL intent — sends a detail card for a specific FAP ID.
    /// Reuses the existing card format with Key Facts, AI Recommendation, and action buttons.
    /// </summary>
    private async Task<string> HandleSubmissionDetailAsync(
        ApproverResolvedUser approver, TeamsIntentResult intentResult,
        ITurnContext turnContext, CancellationToken ct)
    {
        var fapId = intentResult.Entities.FapId;
        if (string.IsNullOrEmpty(fapId))
        {
            var msg = "Please include a FAP ID in your request (e.g., \"tell me about FAP-28C9823C\").";
            await turnContext.SendActivityAsync(MessageFactory.Text(msg), ct);
            return msg;
        }

        var package = await _queryService.GetSubmissionDetailAsync(
            approver.UserId, approver.Role, approver.AssignedStates, fapId, ct);

        if (package == null)
        {
            var msg = "I couldn't find that submission in your approval queue.";
            await turnContext.SendActivityAsync(MessageFactory.Text(msg), ct);
            return msg;
        }

        var card = BuildSubmissionDetailCard(package);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };

        var activity = MessageFactory.Attachment(attachment);
        await turnContext.SendActivityAsync(activity, ct);

        return $"Detail card sent for {fapId}";
    }

    /// <summary>
    /// Handles APPROVED_LIST intent — Adaptive Card with recently approved submissions.
    /// Each item shows Agency Name (bold), PO Number, Invoice Amount.
    /// Defaults to last 7 days if no time range specified.
    /// </summary>
    private async Task<string> HandleApprovedListAsync(
        ApproverResolvedUser approver, TeamsIntentResult intentResult,
        ITurnContext turnContext, CancellationToken ct)
    {
        var (from, to) = ResolveTimeRange(intentResult.Entities.TimeRange);

        var approved = await _queryService.GetApprovedByMeAsync(approver.UserId, from, to, ct);

        if (approved.Count == 0)
        {
            var msg = "No approvals found in the selected period.";
            await turnContext.SendActivityAsync(MessageFactory.Text(msg), ct);
            return msg;
        }

        var totalAmount = approved
            .Where(a => a.DocumentPackage?.Invoices != null)
            .SelectMany(a => a.DocumentPackage.Invoices)
            .Where(i => !i.IsDeleted && i.TotalAmount.HasValue)
            .Sum(i => i.TotalAmount!.Value);

        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"✅ Approved: {approved.Count} submissions (Total: {FormatIndianCurrency(totalAmount)})",
                ["weight"] = "Bolder",
                ["size"] = "Medium",
                ["wrap"] = true
            }
        };

        foreach (var item in approved.Take(10))
        {
            var agencyName = item.DocumentPackage?.Agency?.SupplierName ?? "Unknown Agency";
            var poNumber = item.DocumentPackage?.PO?.PONumber ?? "N/A";
            var amount = item.DocumentPackage?.Invoices?
                .Where(i => !i.IsDeleted && i.TotalAmount.HasValue)
                .Sum(i => i.TotalAmount!.Value) ?? 0;

            bodyItems.Add(new JObject
            {
                ["type"] = "Container",
                ["separator"] = true,
                ["spacing"] = "Medium",
                ["items"] = new JArray
                {
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = agencyName,
                        ["weight"] = "Bolder",
                        ["wrap"] = true
                    },
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = $"PO: {poNumber}",
                        ["spacing"] = "Small",
                        ["size"] = "Small",
                        ["wrap"] = true
                    },
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = $"Invoice: {FormatIndianCurrency(amount)}",
                        ["spacing"] = "Small",
                        ["size"] = "Small",
                        ["wrap"] = true
                    }
                }
            });
        }

        var card = WrapInWhiteCard(bodyItems);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), ct);

        return $"Approved list card sent ({approved.Count} items)";
    }

    /// <summary>
    /// Handles REJECTED_LIST intent — Adaptive Card with recently rejected submissions.
    /// Each item shows Agency Name (bold), PO Number, Invoice Amount, Rejection Reason.
    /// Defaults to last 7 days.
    /// </summary>
    private async Task<string> HandleRejectedListAsync(
        ApproverResolvedUser approver, TeamsIntentResult intentResult,
        ITurnContext turnContext, CancellationToken ct)
    {
        var (from, to) = ResolveTimeRange(intentResult.Entities.TimeRange);

        var rejected = await _queryService.GetRejectedByMeAsync(approver.UserId, from, to, ct);

        if (rejected.Count == 0)
        {
            var msg = "No rejections found in the selected period.";
            await turnContext.SendActivityAsync(MessageFactory.Text(msg), ct);
            return msg;
        }

        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"❌ Rejected: {rejected.Count} submissions",
                ["weight"] = "Bolder",
                ["size"] = "Medium",
                ["wrap"] = true
            }
        };

        foreach (var item in rejected.Take(10))
        {
            var agencyName = item.DocumentPackage?.Agency?.SupplierName ?? "Unknown Agency";
            var poNumber = item.DocumentPackage?.PO?.PONumber ?? "N/A";
            var amount = item.DocumentPackage?.Invoices?
                .Where(i => !i.IsDeleted && i.TotalAmount.HasValue)
                .Sum(i => i.TotalAmount!.Value) ?? 0;
            var reason = TruncateText(item.Comments ?? "No reason provided", 100);

            bodyItems.Add(new JObject
            {
                ["type"] = "Container",
                ["separator"] = true,
                ["spacing"] = "Medium",
                ["items"] = new JArray
                {
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = agencyName,
                        ["weight"] = "Bolder",
                        ["wrap"] = true
                    },
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = $"PO: {poNumber}",
                        ["spacing"] = "Small",
                        ["size"] = "Small",
                        ["wrap"] = true
                    },
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = $"Invoice: {FormatIndianCurrency(amount)}",
                        ["spacing"] = "Small",
                        ["size"] = "Small",
                        ["wrap"] = true
                    },
                    new JObject
                    {
                        ["type"] = "TextBlock",
                        ["text"] = $"Reason: {reason}",
                        ["spacing"] = "Small",
                        ["size"] = "Small",
                        ["wrap"] = true,
                        ["isSubtle"] = true
                    }
                }
            });
        }

        var card = WrapInWhiteCard(bodyItems);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), ct);

        return $"Rejected list card sent ({rejected.Count} items)";
    }

    /// <summary>
    /// Handles ACTIVITY_SUMMARY intent — Adaptive Card with aggregate numbers.
    /// </summary>
    private async Task<string> HandleActivitySummaryAsync(
        ApproverResolvedUser approver, ITurnContext turnContext, CancellationToken ct)
    {
        var summary = await _queryService.GetActivitySummaryAsync(
            approver.UserId, approver.Role, approver.AssignedStates, ct);

        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "📊 Activity Summary",
                ["weight"] = "Bolder",
                ["size"] = "Medium"
            },
            new JObject
            {
                ["type"] = "FactSet",
                ["facts"] = new JArray
                {
                    new JObject { ["title"] = "Pending approvals", ["value"] = summary.PendingCount.ToString() },
                    new JObject { ["title"] = "New today", ["value"] = summary.NewToday.ToString() },
                    new JObject { ["title"] = "Approved this week", ["value"] = $"{summary.ApprovedThisWeek} ({FormatIndianCurrency(summary.ApprovedAmountThisWeek)})" },
                    new JObject { ["title"] = "Rejected this week", ["value"] = summary.RejectedThisWeek.ToString() },
                    new JObject { ["title"] = "Avg processing time", ["value"] = $"{summary.AvgProcessingDays} days" }
                }
            }
        };

        var card = WrapInWhiteCard(bodyItems);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), ct);
        return "Activity summary card sent";
    }

    /// <summary>
    /// Handles HELP intent — Adaptive Card listing capabilities with examples.
    /// </summary>
    private async Task<string> HandleHelpAsync(ITurnContext turnContext, CancellationToken ct)
    {
        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "🤖 Here's what I can help you with",
                ["weight"] = "Bolder",
                ["size"] = "Medium",
                ["wrap"] = true
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "📋 **Pending approvals**\n\"Any open requests?\"",
                ["wrap"] = true,
                ["spacing"] = "Medium"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "📄 **Submission details**\n\"Tell me about FAP-28C9823C\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "✅ **Approved list**\n\"What did I approve this week?\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "❌ **Rejected list**\n\"Which claims did I reject?\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "📊 **Activity summary**\n\"Summary of today\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "Just type your question and I'll get you the answer.",
                ["wrap"] = true,
                ["spacing"] = "Medium",
                ["isSubtle"] = true
            }
        };

        var card = WrapInWhiteCard(bodyItems);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), ct);
        return "Help card sent";
    }

    /// <summary>
    /// Handles GREETING intent — welcome card with pending count.
    /// </summary>
    private async Task<string> HandleGreetingAsync(
        ApproverResolvedUser approver, ITurnContext turnContext, CancellationToken ct)
    {
        var pending = await _queryService.GetPendingApprovalsAsync(
            approver.UserId, approver.Role, approver.AssignedStates, ct);

        var pendingText = pending.Count > 0
            ? $"You have {pending.Count} pending approval(s). Type \"pending\" to see them."
            : "You're all caught up — no pending approvals right now.";

        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"👋 Hi {approver.DisplayName}!",
                ["weight"] = "Bolder",
                ["size"] = "Medium"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "I'm the ClaimsIQ Review Bot. I can help you check pending approvals, review submissions, and track your activity.",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = pendingText,
                ["wrap"] = true,
                ["spacing"] = "Medium"
            }
        };

        var card = WrapInWhiteCard(bodyItems);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), ct);
        return "Greeting card sent";
    }

    /// <summary>
    /// Handles FALLBACK intent — friendly "didn't understand" card with suggestions.
    /// </summary>
    private async Task<string> HandleFallbackAsync(ITurnContext turnContext, CancellationToken ct)
    {
        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "I'm not sure how to help with that, but here are some things you can ask me:",
                ["wrap"] = true,
                ["weight"] = "Bolder"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "• \"Any open requests?\"",
                ["wrap"] = true,
                ["spacing"] = "Medium"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "• \"Tell me about FAP-28C9823C\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "• \"What did I approve this week?\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "• \"Summary of today\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = "• \"Help\"",
                ["wrap"] = true,
                ["spacing"] = "Small"
            }
        };

        var card = WrapInWhiteCard(bodyItems);
        var attachment = new Attachment
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = card
        };
        await turnContext.SendActivityAsync(MessageFactory.Attachment(attachment), ct);
        return "Fallback card sent";
    }

    /// <summary>
    /// Builds an Adaptive Card for pending approvals with action buttons matching existing card data structure.
    /// Each item has "Quick Approve" and "Review Details" buttons that trigger existing OnAdaptiveCardInvokeAsync handlers.
    /// </summary>
    private JObject BuildPendingApprovalsCard(List<PendingApprovalSummary> items, int totalCount)
    {
        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"📋 Pending Approvals ({totalCount})",
                ["weight"] = "Bolder",
                ["size"] = "Medium"
            }
        };

        foreach (var item in items)
        {
            bodyItems.Add(BuildPendingItemContainer(item));
        }

        // "View all in portal" link if more than MaxPendingDisplay
        if (totalCount > MaxPendingDisplay)
        {
            bodyItems.Add(new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"[View all {totalCount} pending in portal]({_portalBaseUrl})",
                ["wrap"] = true,
                ["horizontalAlignment"] = "Center",
                ["size"] = "Small",
                ["color"] = "Accent"
            });
        }

        return WrapInWhiteCard(bodyItems);
    }

    /// <summary>
    /// Builds a single pending item container with facts and action buttons.
    /// Action.Submit data matches existing notification card structure for handler reuse.
    /// </summary>
    private static JObject BuildPendingItemContainer(PendingApprovalSummary item)
    {
        var submissionId = item.SubmissionId.ToString();

        return new JObject
        {
            ["type"] = "Container",
            ["separator"] = true,
            ["items"] = new JArray
            {
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = item.FapId,
                    ["weight"] = "Bolder"
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = $"{item.AgencyName} | {FormatIndianCurrency(item.Amount)}",
                    ["wrap"] = true,
                    ["size"] = "Small"
                },
                new JObject
                {
                    ["type"] = "TextBlock",
                    ["text"] = $"Submitted {item.SubmittedAt:dd-MMM-yyyy} | {item.DaysPending} day(s) ago",
                    ["size"] = "Small",
                    ["isSubtle"] = true
                },
                new JObject
                {
                    ["type"] = "ActionSet",
                    ["actions"] = new JArray
                    {
                        new JObject
                        {
                            ["type"] = "Action.Submit",
                            ["title"] = "Quick Approve",
                            ["style"] = "positive",
                            ["data"] = new JObject
                            {
                                ["action"] = "quick_approve",
                                ["submissionId"] = submissionId,
                                ["fapId"] = submissionId,
                                ["cardVersion"] = "1.0"
                            }
                        },
                        new JObject
                        {
                            ["type"] = "Action.Submit",
                            ["title"] = "Review Details",
                            ["data"] = new JObject
                            {
                                ["action"] = "review_details",
                                ["submissionId"] = submissionId,
                                ["fapId"] = submissionId,
                                ["cardVersion"] = "1.0"
                            }
                        }
                    }
                }
            }
        };
    }

    /// <summary>
    /// Builds a detail Adaptive Card for a specific submission, reusing the existing notification card format.
    /// Includes: Header, Key Facts, AI Recommendation, and Action Buttons.
    /// </summary>
    private JObject BuildSubmissionDetailCard(DocumentPackage package)
    {
        var shortId = package.SubmissionNumber ?? ("FAP-" + package.Id.ToString()[..8].ToUpper());
        var agencyName = package.Agency?.SupplierName ?? "Unknown Agency";
        var amount = package.Invoices?
            .Where(i => !i.IsDeleted && i.TotalAmount.HasValue)
            .Sum(i => i.TotalAmount!.Value) ?? 0;
        var poNumber = package.PO?.PONumber ?? "N/A";
        var confidence = package.ConfidenceScore?.OverallConfidence ?? 0;
        var recType = package.Recommendation?.Type.ToString() ?? "N/A";
        var recEvidence = package.Recommendation?.Evidence ?? "No recommendation available.";
        var submissionId = package.Id.ToString();

        var confidenceEmoji = confidence > 85 ? "🟢" : confidence >= 70 ? "🟡" : "🔴";
        var recEmoji = recType == "Approve" ? "✅" : recType == "Review" ? "⚠️" : "❌";

        var bodyItems = new JArray
        {
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"📄 {shortId} — Submission Details",
                ["weight"] = "Bolder",
                ["size"] = "Medium"
            },
            new JObject
            {
                ["type"] = "FactSet",
                ["facts"] = new JArray
                {
                    new JObject { ["title"] = "FAP #", ["value"] = shortId },
                    new JObject { ["title"] = "Agency", ["value"] = agencyName },
                    new JObject { ["title"] = "PO #", ["value"] = poNumber },
                    new JObject { ["title"] = "Amount", ["value"] = FormatIndianCurrency(amount) },
                    new JObject { ["title"] = "Submitted", ["value"] = package.CreatedAt.ToString("dd-MMM-yyyy") },
                    new JObject { ["title"] = "State", ["value"] = package.ActivityState ?? "N/A" },
                    new JObject { ["title"] = "Status", ["value"] = package.State.ToString() }
                }
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"{confidenceEmoji} AI Confidence: {confidence:F0}%",
                ["weight"] = "Bolder"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = $"{recEmoji} Recommendation: {recType}",
                ["weight"] = "Bolder"
            },
            new JObject
            {
                ["type"] = "TextBlock",
                ["text"] = TruncateText(recEvidence, 300),
                ["wrap"] = true,
                ["size"] = "Small"
            }
        };

        var actions = new JArray
        {
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Quick Approve",
                ["style"] = "positive",
                ["data"] = new JObject
                {
                    ["action"] = "quick_approve",
                    ["submissionId"] = submissionId,
                    ["fapId"] = submissionId,
                    ["cardVersion"] = "1.0"
                }
            },
            new JObject
            {
                ["type"] = "Action.Submit",
                ["title"] = "Review Details",
                ["data"] = new JObject
                {
                    ["action"] = "review_details",
                    ["submissionId"] = submissionId,
                    ["fapId"] = submissionId,
                    ["cardVersion"] = "1.0"
                }
            },
            new JObject
            {
                ["type"] = "Action.OpenUrl",
                ["title"] = "Open in Portal",
                ["url"] = $"{_portalBaseUrl}/fap/{package.Id}/review"
            }
        };

        return WrapInWhiteCard(bodyItems, actions);
    }

    /// <summary>
    /// Wraps body items in a full-bleed default Container for white background,
    /// matching the existing card pattern used by ApprovalCardBuilder.
    /// </summary>
    private static JObject WrapInWhiteCard(JArray bodyItems, JArray? actions = null)
    {
        var card = new JObject
        {
            ["type"] = "AdaptiveCard",
            ["$schema"] = "http://adaptivecards.io/schemas/adaptive-card.json",
            ["version"] = "1.3",
            ["body"] = new JArray
            {
                new JObject
                {
                    ["type"] = "Container",
                    ["style"] = "default",
                    ["bleed"] = true,
                    ["items"] = bodyItems
                }
            }
        };

        if (actions != null)
        {
            card["actions"] = actions;
        }

        return card;
    }

    /// <summary>
    /// Resolves a time range keyword to a (from, to) date range.
    /// Defaults to last 7 days when no time range is specified.
    /// </summary>
    private static (DateTime from, DateTime to) ResolveTimeRange(string? timeRange)
    {
        var now = DateTime.UtcNow;
        var today = now.Date;

        return timeRange switch
        {
            "today" => (today, now),
            "this week" => (today.AddDays(-(int)today.DayOfWeek), now),
            "last week" => (today.AddDays(-(int)today.DayOfWeek - 7), today.AddDays(-(int)today.DayOfWeek)),
            "this month" => (new DateTime(today.Year, today.Month, 1), now),
            _ => (today.AddDays(-7), now) // Default: last 7 days
        };
    }

    /// <summary>
    /// Formats a decimal amount in ₹ Indian comma notation (e.g., ₹2,86,740).
    /// Indian notation: last 3 digits grouped, then groups of 2.
    /// </summary>
    internal static string FormatIndianCurrency(decimal amount)
    {
        var isNegative = amount < 0;
        amount = Math.Abs(amount);

        var wholePart = (long)amount;
        var decimalPart = amount - wholePart;

        string formatted;
        if (wholePart < 1000)
        {
            formatted = wholePart.ToString();
        }
        else
        {
            var lastThree = (wholePart % 1000).ToString();
            var remaining = wholePart / 1000;

            var groups = new List<string> { lastThree.PadLeft(3, '0') };
            while (remaining > 0)
            {
                groups.Insert(0, (remaining % 100).ToString(remaining >= 100 ? "D2" : "D0"));
                remaining /= 100;
            }

            formatted = string.Join(",", groups);
        }

        // Add decimal portion if non-zero
        if (decimalPart > 0)
        {
            formatted += $".{(int)(decimalPart * 100):D2}";
        }

        var prefix = isNegative ? "-₹" : "₹";
        return $"{prefix}{formatted}";
    }

    /// <summary>
    /// Truncates text to the specified max length, appending "..." if truncated.
    /// </summary>
    private static string TruncateText(string text, int maxLength)
    {
        if (string.IsNullOrEmpty(text) || text.Length <= maxLength)
            return text;

        return text[..(maxLength - 3)] + "...";
    }

    /// <summary>
    /// Logs a conversation audit entry as fire-and-forget.
    /// Failures are caught and logged but never block the response per Req 11.1, 11.2.
    /// </summary>
    private void LogAuditFireAndForget(
        Guid? userId, string? userRole, string userMessage, string botResponse, string? intent, string[]? assignedStates = null)
    {
        _ = Task.Run(async () =>
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

                var auditEntry = new ConversationAuditLog
                {
                    Id = Guid.NewGuid(),
                    UserId = userId ?? Guid.Empty,
                    UserRole = userRole ?? "Unknown",
                    Channel = "TeamsBot",
                    UserMessage = userMessage,
                    BotResponse = TruncateText(botResponse, 4000),
                    Intent = intent,
                    ResolvedScope = assignedStates != null ? string.Join(", ", assignedStates) : null,
                    Timestamp = DateTime.UtcNow,
                    CreatedAt = DateTime.UtcNow
                };

                dbContext.ConversationAuditLogs.Add(auditEntry);
                await dbContext.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to write conversation audit log — non-blocking");
            }
        });
    }
}
