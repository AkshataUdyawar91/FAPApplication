using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Infrastructure.Configuration;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Sends push notifications to iOS devices via Apple Push Notification service (APNs).
/// Uses P8 key-based JWT authentication against the APNs HTTP/2 API.
/// </summary>
public class ApnsService : IApnsService
{
    private const string ProductionHost = "https://api.push.apple.com";
    private const string SandboxHost = "https://api.sandbox.push.apple.com";
    private const int MaxPayloadSizeBytes = 4096;
    private const int JwtExpirationMinutes = 50;

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<ApnsService> _logger;
    private readonly ApnsSettings _settings;

    private string? _cachedJwt;
    private DateTime _jwtExpiresAt = DateTime.MinValue;
    private readonly object _jwtLock = new();

    /// <summary>
    /// Initializes a new instance of the <see cref="ApnsService"/> class
    /// </summary>
    public ApnsService(
        IHttpClientFactory httpClientFactory,
        ILogger<ApnsService> logger,
        IOptions<ApnsSettings> settings)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
        _settings = settings.Value;
    }

    /// <inheritdoc />
    public async Task<NotificationResult> SendAsync(
        string deviceToken,
        ApnsPayload payload,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Sending APNs notification to device {DeviceToken}", MaskToken(deviceToken));

        if (string.IsNullOrWhiteSpace(deviceToken))
        {
            return NotificationResult.Failed("Device token is required", "InvalidToken", isInvalidToken: true);
        }

        var jsonPayload = FormatPayload(payload);
        var payloadBytes = Encoding.UTF8.GetBytes(jsonPayload);

        if (payloadBytes.Length > MaxPayloadSizeBytes)
        {
            _logger.LogWarning("APNs payload exceeds {MaxSize} bytes limit ({ActualSize} bytes)", MaxPayloadSizeBytes, payloadBytes.Length);
            return NotificationResult.Failed(
                $"Payload exceeds maximum size of {MaxPayloadSizeBytes} bytes",
                "PayloadTooLarge");
        }

        try
        {
            var jwt = GetOrCreateJwt();
            var host = _settings.IsProduction ? ProductionHost : SandboxHost;
            var requestUrl = $"{host}/3/device/{deviceToken}";

            var client = _httpClientFactory.CreateClient("ApnsClient");
            using var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
            request.Headers.Authorization = new AuthenticationHeaderValue("bearer", jwt);
            request.Headers.TryAddWithoutValidation("apns-topic", _settings.BundleId);
            request.Headers.TryAddWithoutValidation("apns-push-type", "alert");
            request.Headers.TryAddWithoutValidation("apns-priority", "10");
            request.Content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

            var response = await client.SendAsync(request, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("APNs notification sent successfully to device {DeviceToken}", MaskToken(deviceToken));
                return NotificationResult.Succeeded();
            }

            return await HandleErrorResponseAsync(response, deviceToken, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "HTTP error sending APNs notification to device {DeviceToken}", MaskToken(deviceToken));
            return NotificationResult.Failed(
                $"HTTP error communicating with APNs: {ex.Message}",
                "HttpError",
                isTransient: true);
        }
        catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogError(ex, "Timeout sending APNs notification to device {DeviceToken}", MaskToken(deviceToken));
            return NotificationResult.Failed("APNs request timed out", "Timeout", isTransient: true);
        }
    }

    /// <inheritdoc />
    public Task<NotificationResult> ValidateCredentialsAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Validating APNs credentials");

        if (string.IsNullOrWhiteSpace(_settings.KeyId))
        {
            return Task.FromResult(NotificationResult.Failed("APNs KeyId is not configured", "MissingKeyId"));
        }

        if (string.IsNullOrWhiteSpace(_settings.TeamId))
        {
            return Task.FromResult(NotificationResult.Failed("APNs TeamId is not configured", "MissingTeamId"));
        }

        if (string.IsNullOrWhiteSpace(_settings.BundleId))
        {
            return Task.FromResult(NotificationResult.Failed("APNs BundleId is not configured", "MissingBundleId"));
        }

        if (string.IsNullOrWhiteSpace(_settings.KeyFilePath))
        {
            return Task.FromResult(NotificationResult.Failed("APNs KeyFilePath is not configured", "MissingKeyFilePath"));
        }

        if (!File.Exists(_settings.KeyFilePath))
        {
            return Task.FromResult(NotificationResult.Failed(
                $"APNs P8 key file not found at '{_settings.KeyFilePath}'",
                "KeyFileNotFound"));
        }

        try
        {
            // Attempt to generate a JWT to verify the key is valid
            var jwt = GetOrCreateJwt();
            if (string.IsNullOrEmpty(jwt))
            {
                return Task.FromResult(NotificationResult.Failed("Failed to generate JWT from P8 key", "InvalidKey"));
            }

            _logger.LogInformation("APNs credentials validated successfully");
            return Task.FromResult(NotificationResult.Succeeded());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "APNs credential validation failed");
            return Task.FromResult(NotificationResult.Failed(
                $"APNs credential validation failed: {ex.Message}",
                "InvalidCredentials"));
        }
    }

    /// <summary>
    /// Formats the APNs JSON payload per Apple's specification
    /// </summary>
    internal static string FormatPayload(ApnsPayload payload)
    {
        var aps = new Dictionary<string, object>
        {
            ["alert"] = new Dictionary<string, string>
            {
                ["title"] = payload.Title,
                ["body"] = payload.Body
            },
            ["sound"] = string.IsNullOrWhiteSpace(payload.Sound) ? "default" : payload.Sound,
            ["badge"] = payload.Badge,
            ["mutable-content"] = 1
        };

        var root = new Dictionary<string, object> { ["aps"] = aps };

        foreach (var kvp in payload.CustomData ?? new Dictionary<string, string>())
        {
            root[kvp.Key] = kvp.Value;
        }

        return JsonSerializer.Serialize(root, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = false
        });
    }

    /// <summary>
    /// Handles APNs error responses and maps them to NotificationResult
    /// </summary>
    private async Task<NotificationResult> HandleErrorResponseAsync(
        HttpResponseMessage response,
        string deviceToken,
        CancellationToken cancellationToken)
    {
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        var statusCode = (int)response.StatusCode;

        string? reason = null;
        try
        {
            using var doc = JsonDocument.Parse(responseBody);
            reason = doc.RootElement.TryGetProperty("reason", out var reasonProp)
                ? reasonProp.GetString()
                : null;
        }
        catch (JsonException)
        {
            reason = responseBody;
        }

        _logger.LogWarning(
            "APNs returned error {StatusCode} for device {DeviceToken}: {Reason}",
            statusCode, MaskToken(deviceToken), reason);

        return MapApnsError(statusCode, reason);
    }

    /// <summary>
    /// Maps APNs error codes to NotificationResult with appropriate flags
    /// </summary>
    private static NotificationResult MapApnsError(int statusCode, string? reason)
    {
        // Invalid token errors — device token should be removed
        var invalidTokenReasons = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "BadDeviceToken",
            "Unregistered",
            "DeviceTokenNotForTopic",
            "ExpiredToken"
        };

        if (reason != null && invalidTokenReasons.Contains(reason))
        {
            return NotificationResult.Failed(
                $"APNs invalid token: {reason}",
                reason,
                isInvalidToken: true);
        }

        // Transient errors — can be retried
        var transientReasons = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "ServiceUnavailable",
            "InternalServerError",
            "Shutdown",
            "TooManyRequests"
        };

        if (statusCode >= 500 || (reason != null && transientReasons.Contains(reason)))
        {
            return NotificationResult.Failed(
                $"APNs transient error: {reason ?? statusCode.ToString()}",
                reason ?? statusCode.ToString(),
                isTransient: true);
        }

        // Non-retryable client errors
        return NotificationResult.Failed(
            $"APNs error ({statusCode}): {reason ?? "Unknown"}",
            reason ?? statusCode.ToString());
    }

    /// <summary>
    /// Gets a cached JWT or creates a new one if expired.
    /// APNs JWTs are valid for up to 60 minutes; we refresh at 50 minutes.
    /// </summary>
    private string GetOrCreateJwt()
    {
        lock (_jwtLock)
        {
            if (_cachedJwt != null && DateTime.UtcNow < _jwtExpiresAt)
            {
                return _cachedJwt;
            }

            _cachedJwt = GenerateJwt();
            _jwtExpiresAt = DateTime.UtcNow.AddMinutes(JwtExpirationMinutes);
            return _cachedJwt;
        }
    }

    /// <summary>
    /// Generates a JWT for APNs authentication using the P8 key file
    /// </summary>
    private string GenerateJwt()
    {
        var keyContent = File.ReadAllText(_settings.KeyFilePath)
            .Replace("-----BEGIN PRIVATE KEY-----", "")
            .Replace("-----END PRIVATE KEY-----", "")
            .Replace("\n", "")
            .Replace("\r", "")
            .Trim();

        var keyBytes = Convert.FromBase64String(keyContent);
        using var ecdsa = ECDsa.Create();
        ecdsa.ImportPkcs8PrivateKey(keyBytes, out _);

        var now = DateTimeOffset.UtcNow;
        var header = JsonSerializer.Serialize(new { alg = "ES256", kid = _settings.KeyId });
        var claims = JsonSerializer.Serialize(new { iss = _settings.TeamId, iat = now.ToUnixTimeSeconds() });

        var headerBase64 = Base64UrlEncode(Encoding.UTF8.GetBytes(header));
        var claimsBase64 = Base64UrlEncode(Encoding.UTF8.GetBytes(claims));
        var unsignedToken = $"{headerBase64}.{claimsBase64}";

        var signature = ecdsa.SignData(Encoding.UTF8.GetBytes(unsignedToken), HashAlgorithmName.SHA256);
        var signatureBase64 = Base64UrlEncode(signature);

        return $"{unsignedToken}.{signatureBase64}";
    }

    /// <summary>
    /// Base64url encodes data per RFC 7515
    /// </summary>
    private static string Base64UrlEncode(byte[] data)
    {
        return Convert.ToBase64String(data)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    /// <summary>
    /// Masks a device token for safe logging (shows first 8 and last 4 characters)
    /// </summary>
    private static string MaskToken(string token)
    {
        if (string.IsNullOrEmpty(token) || token.Length <= 12)
        {
            return "***";
        }

        return $"{token[..8]}...{token[^4..]}";
    }
}
