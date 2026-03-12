using System.Net;
using Microsoft.Extensions.Logging;
using Polly;
using Polly.CircuitBreaker;
using Polly.Timeout;

namespace BajajDocumentProcessing.Infrastructure.Resilience;

/// <summary>
/// Resilience policies for push notification platform services (APNs and FCM).
/// Provides retry with exponential backoff, circuit breaker, and timeout policies.
/// </summary>
public static class PushNotificationResiliencePolicies
{
    private static readonly Random Jitter = new();

    /// <summary>
    /// HTTP status codes considered transient and eligible for retry
    /// </summary>
    private static readonly HashSet<HttpStatusCode> TransientStatusCodes = new()
    {
        HttpStatusCode.InternalServerError,       // 500
        HttpStatusCode.BadGateway,                // 502
        HttpStatusCode.ServiceUnavailable,        // 503
        HttpStatusCode.GatewayTimeout,            // 504
        HttpStatusCode.RequestTimeout,            // 408
        (HttpStatusCode)429                       // Too Many Requests
    };

    /// <summary>
    /// Returns a retry policy with exponential backoff (1s, 2s, 4s) and jitter (0-100ms).
    /// Only retries on transient HTTP errors (5xx, 408, 429) and HttpRequestExceptions.
    /// </summary>
    /// <param name="logger">Logger for recording retry attempts</param>
    /// <returns>An async retry policy for HttpResponseMessage</returns>
    public static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy(ILogger logger)
    {
        return Policy<HttpResponseMessage>
            .HandleResult(response => TransientStatusCodes.Contains(response.StatusCode))
            .Or<HttpRequestException>()
            .Or<TimeoutRejectedException>()
            .WaitAndRetryAsync(
                retryCount: 3,
                sleepDurationProvider: retryAttempt =>
                {
                    var baseDelay = TimeSpan.FromSeconds(Math.Pow(2, retryAttempt - 1)); // 1s, 2s, 4s
                    var jitter = TimeSpan.FromMilliseconds(Jitter.Next(0, 100));
                    return baseDelay + jitter;
                },
                onRetry: (outcome, timeSpan, retryCount, context) =>
                {
                    var serviceName = context.TryGetValue("ServiceName", out var name) ? name : "PushNotification";

                    if (outcome.Exception != null)
                    {
                        logger.LogWarning(
                            outcome.Exception,
                            "Push notification request to {ServiceName} failed with exception. " +
                            "Retry attempt {RetryCount} after {Delay}ms",
                            serviceName,
                            retryCount,
                            timeSpan.TotalMilliseconds);
                    }
                    else
                    {
                        logger.LogWarning(
                            "Push notification request to {ServiceName} returned {StatusCode}. " +
                            "Retry attempt {RetryCount} after {Delay}ms",
                            serviceName,
                            (int)outcome.Result.StatusCode,
                            retryCount,
                            timeSpan.TotalMilliseconds);
                    }
                });
    }

    /// <summary>
    /// Returns a circuit breaker policy that opens after 5 consecutive failures
    /// with a 60-second break duration. Logs state changes at WARNING level.
    /// </summary>
    /// <param name="logger">Logger for recording circuit breaker state changes</param>
    /// <returns>An async circuit breaker policy for HttpResponseMessage</returns>
    public static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy(ILogger logger)
    {
        return Policy<HttpResponseMessage>
            .HandleResult(response => TransientStatusCodes.Contains(response.StatusCode))
            .Or<HttpRequestException>()
            .Or<TimeoutRejectedException>()
            .CircuitBreakerAsync(
                handledEventsAllowedBeforeBreaking: 5,
                durationOfBreak: TimeSpan.FromSeconds(60),
                onBreak: (outcome, breakDuration) =>
                {
                    logger.LogWarning(
                        "Push notification circuit breaker OPENED. " +
                        "Breaking for {BreakDuration}s after repeated failures. " +
                        "Reason: {Reason}",
                        breakDuration.TotalSeconds,
                        outcome.Exception?.Message ?? $"HTTP {(int?)outcome.Result?.StatusCode}");
                },
                onReset: () =>
                {
                    logger.LogWarning(
                        "Push notification circuit breaker CLOSED. Service recovered.");
                },
                onHalfOpen: () =>
                {
                    logger.LogWarning(
                        "Push notification circuit breaker HALF-OPEN. Testing with next request.");
                });
    }

    /// <summary>
    /// Returns a timeout policy with a 30-second default timeout.
    /// </summary>
    /// <returns>An async timeout policy for HttpResponseMessage</returns>
    public static IAsyncPolicy<HttpResponseMessage> GetTimeoutPolicy()
    {
        return Policy.TimeoutAsync<HttpResponseMessage>(TimeSpan.FromSeconds(30));
    }

    /// <summary>
    /// Returns a combined policy wrapping retry, circuit breaker, and timeout.
    /// Execution order: Retry → Circuit Breaker → Timeout → HTTP call.
    /// The retry policy wraps the circuit breaker, which wraps the timeout.
    /// </summary>
    /// <param name="logger">Logger for recording policy events</param>
    /// <returns>A combined async policy for HttpResponseMessage</returns>
    public static IAsyncPolicy<HttpResponseMessage> GetCombinedPolicy(ILogger logger)
    {
        var retryPolicy = GetRetryPolicy(logger);
        var circuitBreakerPolicy = GetCircuitBreakerPolicy(logger);
        var timeoutPolicy = GetTimeoutPolicy();

        // Wrap order: retry wraps circuit breaker wraps timeout
        return Policy.WrapAsync(retryPolicy, circuitBreakerPolicy, timeoutPolicy);
    }
}
