using Polly;
using Polly.CircuitBreaker;
using Polly.Retry;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Resilience;

/// <summary>
/// Resilience policies for external services and database operations
/// </summary>
public static class ResiliencePolicies
{
    /// <summary>
    /// Retry policy for database operations (3 attempts with exponential backoff)
    /// </summary>
    public static AsyncRetryPolicy GetDatabaseRetryPolicy(ILogger logger)
    {
        return Policy
            .Handle<DbUpdateException>()
            .Or<TimeoutException>()
            .WaitAndRetryAsync(
                retryCount: 3,
                sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
                onRetry: (exception, timeSpan, retryCount, context) =>
                {
                    logger.LogWarning(
                        exception,
                        "Database operation failed. Retry attempt {RetryCount} after {Delay}s",
                        retryCount,
                        timeSpan.TotalSeconds);
                });
    }

    /// <summary>
    /// Circuit breaker policy for external services
    /// (5 failures, 60s open, 2 successes to close)
    /// </summary>
    public static AsyncCircuitBreakerPolicy GetCircuitBreakerPolicy(string serviceName, ILogger logger)
    {
        return Policy
            .Handle<HttpRequestException>()
            .Or<TimeoutException>()
            .CircuitBreakerAsync(
                exceptionsAllowedBeforeBreaking: 5,
                durationOfBreak: TimeSpan.FromSeconds(60),
                onBreak: (exception, duration) =>
                {
                    logger.LogError(
                        exception,
                        "Circuit breaker opened for {ServiceName}. Breaking for {Duration}s",
                        serviceName,
                        duration.TotalSeconds);
                },
                onReset: () =>
                {
                    logger.LogInformation("Circuit breaker reset for {ServiceName}", serviceName);
                },
                onHalfOpen: () =>
                {
                    logger.LogInformation("Circuit breaker half-open for {ServiceName}", serviceName);
                });
    }

    /// <summary>
    /// Combined retry and circuit breaker policy for external services
    /// </summary>
    public static IAsyncPolicy GetExternalServicePolicy(string serviceName, ILogger logger)
    {
        var retryPolicy = Policy
            .Handle<HttpRequestException>()
            .Or<TimeoutException>()
            .WaitAndRetryAsync(
                retryCount: 3,
                sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
                onRetry: (exception, timeSpan, retryCount, context) =>
                {
                    logger.LogWarning(
                        exception,
                        "{ServiceName} request failed. Retry attempt {RetryCount} after {Delay}s",
                        serviceName,
                        retryCount,
                        timeSpan.TotalSeconds);
                });

        var circuitBreakerPolicy = GetCircuitBreakerPolicy(serviceName, logger);

        return Policy.WrapAsync(retryPolicy, circuitBreakerPolicy);
    }
}
