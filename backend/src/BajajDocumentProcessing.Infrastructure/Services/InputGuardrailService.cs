using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using System.Text.RegularExpressions;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class InputGuardrailService : IInputGuardrailService
{
    private readonly ILogger<InputGuardrailService> _logger;
    private readonly IMemoryCache _cache;
    private const int MaxQueryLength = 500;
    private const int MaxQueriesPerMinute = 10;

    // SQL injection patterns
    private static readonly string[] SqlInjectionPatterns = new[]
    {
        @"\b(DROP|DELETE|INSERT|UPDATE|ALTER|CREATE|TRUNCATE)\s+",
        @";\s*(DROP|DELETE|INSERT|UPDATE)",
        @"--",
        @"/\*.*\*/",
        @"xp_",
        @"sp_",
        @"exec\s*\(",
        @"execute\s*\("
    };

    // Prompt injection patterns
    private static readonly string[] PromptInjectionPatterns = new[]
    {
        @"ignore\s+.*instructions",
        @"ignore\s+.*rules",
        @"disregard\s+.*instructions",
        @"disregard\s+.*(previous|all|above)",
        @"forget\s+.*instructions",
        @"forget\s+.*(previous|all|above)",
        @"you\s+are\s+now\s+a\s+different",
        @"act\s+as\s+a\s+different",
        @"pretend\s+you\s+are",
        @"show\s+all\s+agencies",
        @"list\s+all\s+(agencies|users|data|records)",
        @"show\s+all\s+(users|data|records|submissions)",
        @"dump\s+(all|the)\s+(data|database|records)",
        @"reveal\s+(your|the)\s+(instructions|prompt|system)",
        @"what\s+are\s+your\s+instructions",
        @"show\s+me\s+your\s+(prompt|instructions|system)",
        @"system\s*:\s*",
        @"<\|im_start\|>",
        @"<\|im_end\|>",
        @"\[INST\]",
        @"\[/INST\]"
    };

    public InputGuardrailService(
        ILogger<InputGuardrailService> logger,
        IMemoryCache cache)
    {
        _logger = logger;
        _cache = cache;
    }

    public async Task ValidateInputAsync(string query, Guid userId, CancellationToken cancellationToken = default)
    {
        try
        {
            // 1. Length check
            if (string.IsNullOrWhiteSpace(query))
            {
                throw new InputValidationException("Query cannot be empty");
            }

            if (query.Length > MaxQueryLength)
            {
                throw new InputValidationException($"Query exceeds maximum length of {MaxQueryLength} characters");
            }

            // 2. Rate limiting
            await ValidateRateLimitAsync(userId);

            // 3. SQL injection detection
            foreach (var pattern in SqlInjectionPatterns)
            {
                if (Regex.IsMatch(query, pattern, RegexOptions.IgnoreCase))
                {
                    _logger.LogWarning("Potential SQL injection detected for user {UserId}: {Query}", userId, query);
                    throw new InputValidationException("Invalid query pattern detected");
                }
            }

            // 4. Prompt injection detection
            foreach (var pattern in PromptInjectionPatterns)
            {
                if (Regex.IsMatch(query, pattern, RegexOptions.IgnoreCase))
                {
                    _logger.LogWarning("Potential prompt injection detected for user {UserId}: {Query}", userId, query);
                    throw new InputValidationException("Invalid query pattern detected");
                }
            }

            _logger.LogDebug("Input validation passed for user {UserId}", userId);
        }
        catch (InputValidationException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating input for user {UserId}", userId);
            throw new InputValidationException("Failed to validate input");
        }

        await Task.CompletedTask;
    }

    private async Task ValidateRateLimitAsync(Guid userId)
    {
        var cacheKey = $"rate_limit_{userId}";
        var queryCount = _cache.GetOrCreate(cacheKey, entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(1);
            return 0;
        });

        if (queryCount >= MaxQueriesPerMinute)
        {
            _logger.LogWarning("Rate limit exceeded for user {UserId}", userId);
            throw new InputValidationException($"Rate limit exceeded. Maximum {MaxQueriesPerMinute} queries per minute allowed");
        }

        _cache.Set(cacheKey, queryCount + 1, TimeSpan.FromMinutes(1));
        await Task.CompletedTask;
    }
}
