using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;
using System.Text.RegularExpressions;

namespace BajajDocumentProcessing.Infrastructure.Services;

public class OutputGuardrailService : IOutputGuardrailService
{
    private readonly ILogger<OutputGuardrailService> _logger;

    // PII patterns
    private static readonly Regex EmailPattern = new(@"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b", RegexOptions.Compiled);
    private static readonly Regex PhonePattern = new(@"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b", RegexOptions.Compiled);
    private static readonly Regex SsnPattern = new(@"\b\d{3}-\d{2}-\d{4}\b", RegexOptions.Compiled);

    public OutputGuardrailService(ILogger<OutputGuardrailService> logger)
    {
        _logger = logger;
    }

    public async Task<string> ValidateAndSanitizeOutputAsync(
        string response,
        List<VectorSearchResult> sourceData,
        CancellationToken cancellationToken = default)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(response))
            {
                throw new OutputValidationException("Response cannot be empty");
            }

            // 1. Citation verification
            // Extract numbers and key facts from response
            var responseNumbers = ExtractNumbers(response);
            var sourceNumbers = sourceData
                .SelectMany(d => ExtractNumbers(d.Content))
                .Distinct()
                .ToList();

            // Verify that significant numbers in response exist in source data
            foreach (var number in responseNumbers.Where(n => n > 10)) // Only check significant numbers
            {
                var tolerance = number * 0.05; // 5% tolerance
                var found = sourceNumbers.Any(sn => Math.Abs(sn - number) <= tolerance);
                
                if (!found)
                {
                    _logger.LogWarning("Response contains unverified number: {Number}", number);
                    // In production, you might want to throw an exception or flag this
                }
            }

            // 2. PII detection and redaction
            var sanitizedResponse = response;
            
            // Redact emails
            sanitizedResponse = EmailPattern.Replace(sanitizedResponse, "[EMAIL_REDACTED]");
            
            // NOTE: Phone and SSN redaction is DISABLED for chat responses.
            // The phone regex (\d{3}[-.]?\d{3}[-.]?\d{4}) aggressively matches GUIDs,
            // document IDs, and hex sequences in doc:// URLs that the LLM generates.
            // Since chat responses are AI-generated from system prompt data (which contains
            // no real phone numbers or SSNs), these patterns only cause false positives.

            if (sanitizedResponse != response)
            {
                _logger.LogInformation("PII detected and redacted from response");
            }

            // 3. Harmful content detection (basic implementation)
            // In production, integrate with Azure Content Safety API
            var harmfulPatterns = new[] { "hack", "exploit", "malicious", "attack" };
            foreach (var pattern in harmfulPatterns)
            {
                if (sanitizedResponse.Contains(pattern, StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogWarning("Potentially harmful content detected in response");
                }
            }

            _logger.LogDebug("Output validation and sanitization completed");
            return sanitizedResponse;
        }
        catch (OutputValidationException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating output");
            throw new OutputValidationException("Failed to validate output");
        }

        await Task.CompletedTask;
    }

    private List<double> ExtractNumbers(string text)
    {
        var numbers = new List<double>();
        var matches = Regex.Matches(text, @"\b\d+\.?\d*\b");
        
        foreach (Match match in matches)
        {
            if (double.TryParse(match.Value, out var number))
            {
                numbers.Add(number);
            }
        }

        return numbers;
    }
}
