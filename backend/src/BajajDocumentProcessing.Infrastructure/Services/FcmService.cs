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
/// Sends push notifications to Android and Web devices via Firebase Cloud Messaging (FCM).
/// Uses Google service account JSON authentication with OAuth2 JWT flow against the FCM v1 API.
/// </summary>
public class FcmService : IFcmService
{
    private const string FcmBaseUrl = "https://fcm.googleapis.com/v1/projects";
    private const string GoogleTokenUrl = "https://oauth2.googleapis.com/token";
    private const string FcmScope = "https://www.googleapis.com/auth/firebase.messaging";
    private const int MaxPayloadSizeBytes = 4096;
    private const int MaxMulticastBatchSize = 500;
    private const int AccessTokenExpirationMinutes = 50;

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<FcmService> _logger;
    private readonly FcmSettings _settings;

    private string? _cachedAccessToken;
    private DateTime _accessTokenExpiresAt = DateTime.MinValue;
    private readonly object _tokenLock = new();

    /// <summary>
    /// Initializes a new instance of the <see cref="FcmService"/> class
    /// </summary>
    public FcmService(
        IHttpClientFactory httpClientFactory,
        ILogger<FcmService> logger,
        IOptions<FcmSettings> settings)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
        _settings = settings.Value;
    }

    /// <inheritdoc />
    public async Task<NotificationResult> SendAsync(
        string deviceToken,
        FcmPayload payload,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Sending FCM notification to device {DeviceToken}", MaskToken(deviceToken));

        if (string.IsNullOrWhiteSpace(deviceToken))
        {
            return NotificationResult.Failed("Device token is required", "InvalidToken", isInvalidToken: true);
        }

        var jsonPayload = FormatPayload(deviceToken, payload);
        var payloadBytes = Encoding.UTF8.GetBytes(jsonPayload);

        if (payloadBytes.Length > MaxPayloadSizeBytes)
        {
            _logger.LogWarning("FCM payload exceeds {MaxSize} bytes limit ({ActualSize} bytes)", MaxPayloadSizeBytes, payloadBytes.Length);
            return NotificationResult.Failed(
                $"Payload exceeds maximum size of {MaxPayloadSizeBytes} bytes",
                "PayloadTooLarge");
        }

        try
        {
            var accessToken = await GetOrCreateAccessTokenAsync(cancellationToken);
            var requestUrl = $"{FcmBaseUrl}/{_settings.ProjectId}/messages:send";

            var client = _httpClientFactory.CreateClient("FcmClient");
            using var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
            request.Content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

            var response = await client.SendAsync(request, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("FCM notification sent successfully to device {DeviceToken}", MaskToken(deviceToken));
                return NotificationResult.Succeeded();
            }

            return await HandleErrorResponseAsync(response, deviceToken, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "HTTP error sending FCM notification to device {DeviceToken}", MaskToken(deviceToken));
            return NotificationResult.Failed(
                $"HTTP error communicating with FCM: {ex.Message}",
                "HttpError",
                isTransient: true);
        }
        catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogError(ex, "Timeout sending FCM notification to device {DeviceToken}", MaskToken(deviceToken));
            return NotificationResult.Failed("FCM request timed out", "Timeout", isTransient: true);
        }
    }

    /// <inheritdoc />
    public async Task<IEnumerable<NotificationResult>> SendMulticastAsync(
        IEnumerable<string> deviceTokens,
        FcmPayload payload,
        CancellationToken cancellationToken)
    {
        var tokenList = deviceTokens.ToList();
        _logger.LogInformation("Sending FCM multicast notification to {Count} devices", tokenList.Count);

        if (tokenList.Count == 0)
        {
            return Enumerable.Empty<NotificationResult>();
        }

        var results = new List<NotificationResult>();

        // Batch tokens in groups of MaxMulticastBatchSize (500)
        var batches = tokenList
            .Select((token, index) => new { token, index })
            .GroupBy(x => x.index / MaxMulticastBatchSize)
            .Select(g => g.Select(x => x.token).ToList());

        foreach (var batch in batches)
        {
            foreach (var token in batch)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var result = await SendAsync(token, payload, cancellationToken);
                results.Add(result);
            }
        }

        var successCount = results.Count(r => r.Success);
        _logger.LogInformation(
            "FCM multicast complete: {SuccessCount}/{TotalCount} succeeded",
            successCount, tokenList.Count);

        return results;
    }

    /// <inheritdoc />
    public Task<NotificationResult> ValidateCredentialsAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Validating FCM credentials");

        if (string.IsNullOrWhiteSpace(_settings.ProjectId))
        {
            return Task.FromResult(NotificationResult.Failed("FCM ProjectId is not configured", "MissingProjectId"));
        }

        if (string.IsNullOrWhiteSpace(_settings.ServiceAccountJsonPath))
        {
            return Task.FromResult(NotificationResult.Failed("FCM ServiceAccountJsonPath is not configured", "MissingServiceAccountJsonPath"));
        }

        if (!File.Exists(_settings.ServiceAccountJsonPath))
        {
            return Task.FromResult(NotificationResult.Failed(
                $"FCM service account JSON file not found at '{_settings.ServiceAccountJsonPath}'",
                "ServiceAccountFileNotFound"));
        }

        try
        {
            var serviceAccount = ReadServiceAccountJson();
            if (serviceAccount == null)
            {
                return Task.FromResult(NotificationResult.Failed("Failed to parse service account JSON", "InvalidServiceAccount"));
            }

            if (string.IsNullOrWhiteSpace(serviceAccount.ClientEmail))
            {
                return Task.FromResult(NotificationResult.Failed("Service account JSON missing client_email", "MissingClientEmail"));
            }

            if (string.IsNullOrWhiteSpace(serviceAccount.PrivateKey))
            {
                return Task.FromResult(NotificationResult.Failed("Service account JSON missing private_key", "MissingPrivateKey"));
            }

            _logger.LogInformation("FCM credentials validated successfully");
            return Task.FromResult(NotificationResult.Succeeded());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "FCM credential validation failed");
            return Task.FromResult(NotificationResult.Failed(
                $"FCM credential validation failed: {ex.Message}",
                "InvalidCredentials"));
        }
    }

    /// <summary>
    /// Formats the FCM v1 API JSON payload with notification, data, android, and webpush sections
    /// </summary>
    internal static string FormatPayload(string deviceToken, FcmPayload payload)
    {
        var message = new Dictionary<string, object>
        {
            ["token"] = deviceToken,
            ["notification"] = new Dictionary<string, string>
            {
                ["title"] = payload.Title,
                ["body"] = payload.Body
            }
        };

        if (payload.Data is { Count: > 0 })
        {
            message["data"] = payload.Data;
        }

        if (payload.AndroidConfig != null)
        {
            var android = new Dictionary<string, object>
            {
                ["priority"] = payload.AndroidConfig.Priority
            };

            if (payload.AndroidConfig.Data is { Count: > 0 })
            {
                android["data"] = payload.AndroidConfig.Data;
            }

            message["android"] = android;
        }

        if (payload.WebpushConfig != null)
        {
            var webpush = new Dictionary<string, object>();

            if (payload.WebpushConfig.Headers is { Count: > 0 })
            {
                webpush["headers"] = payload.WebpushConfig.Headers;
            }

            if (payload.WebpushConfig.Data is { Count: > 0 })
            {
                webpush["data"] = payload.WebpushConfig.Data;
            }

            if (webpush.Count > 0)
            {
                message["webpush"] = webpush;
            }
        }

        var root = new Dictionary<string, object> { ["message"] = message };

        return JsonSerializer.Serialize(root, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = false
        });
    }

    /// <summary>
    /// Handles FCM error responses and maps them to NotificationResult
    /// </summary>
    private async Task<NotificationResult> HandleErrorResponseAsync(
        HttpResponseMessage response,
        string deviceToken,
        CancellationToken cancellationToken)
    {
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        var statusCode = (int)response.StatusCode;

        string? errorCode = null;
        string? errorMessage = null;

        try
        {
            using var doc = JsonDocument.Parse(responseBody);
            if (doc.RootElement.TryGetProperty("error", out var errorElement))
            {
                errorMessage = errorElement.TryGetProperty("message", out var msgProp)
                    ? msgProp.GetString()
                    : null;

                if (errorElement.TryGetProperty("details", out var details) && details.ValueKind == JsonValueKind.Array)
                {
                    foreach (var detail in details.EnumerateArray())
                    {
                        if (detail.TryGetProperty("errorCode", out var codeProp))
                        {
                            errorCode = codeProp.GetString();
                            break;
                        }
                    }
                }

                errorCode ??= errorElement.TryGetProperty("status", out var statusProp)
                    ? statusProp.GetString()
                    : null;
            }
        }
        catch (JsonException)
        {
            errorMessage = responseBody;
        }

        _logger.LogWarning(
            "FCM returned error {StatusCode} for device {DeviceToken}: {ErrorCode} - {ErrorMessage}",
            statusCode, MaskToken(deviceToken), errorCode, errorMessage);

        return MapFcmError(statusCode, errorCode, errorMessage);
    }

    /// <summary>
    /// Maps FCM error codes to NotificationResult with appropriate flags
    /// </summary>
    private static NotificationResult MapFcmError(int statusCode, string? errorCode, string? errorMessage)
    {
        // Invalid token errors — device token should be removed
        var invalidTokenCodes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "INVALID_ARGUMENT",
            "NOT_FOUND",
            "UNREGISTERED"
        };

        if (errorCode != null && invalidTokenCodes.Contains(errorCode))
        {
            return NotificationResult.Failed(
                $"FCM invalid token: {errorCode} - {errorMessage ?? "Unknown"}",
                errorCode,
                isInvalidToken: true);
        }

        // Transient errors — can be retried
        var transientCodes = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "UNAVAILABLE",
            "INTERNAL"
        };

        if (statusCode >= 500 || statusCode == 429 || (errorCode != null && transientCodes.Contains(errorCode)))
        {
            return NotificationResult.Failed(
                $"FCM transient error: {errorCode ?? statusCode.ToString()} - {errorMessage ?? "Unknown"}",
                errorCode ?? statusCode.ToString(),
                isTransient: true);
        }

        // Non-retryable client errors
        return NotificationResult.Failed(
            $"FCM error ({statusCode}): {errorCode ?? "Unknown"} - {errorMessage ?? "Unknown"}",
            errorCode ?? statusCode.ToString());
    }

    /// <summary>
    /// Gets a cached OAuth2 access token or creates a new one if expired.
    /// Google OAuth2 tokens are valid for 60 minutes; we refresh at 50 minutes.
    /// </summary>
    private async Task<string> GetOrCreateAccessTokenAsync(CancellationToken cancellationToken)
    {
        lock (_tokenLock)
        {
            if (_cachedAccessToken != null && DateTime.UtcNow < _accessTokenExpiresAt)
            {
                return _cachedAccessToken;
            }
        }

        var accessToken = await RequestAccessTokenAsync(cancellationToken);

        lock (_tokenLock)
        {
            _cachedAccessToken = accessToken;
            _accessTokenExpiresAt = DateTime.UtcNow.AddMinutes(AccessTokenExpirationMinutes);
        }

        return accessToken;
    }

    /// <summary>
    /// Requests a new OAuth2 access token from Google using the service account JWT flow
    /// </summary>
    private async Task<string> RequestAccessTokenAsync(CancellationToken cancellationToken)
    {
        var serviceAccount = ReadServiceAccountJson()
            ?? throw new InvalidOperationException("Failed to parse FCM service account JSON");

        var jwt = GenerateServiceAccountJwt(serviceAccount);

        var client = _httpClientFactory.CreateClient("FcmClient");
        var tokenRequest = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
            ["assertion"] = jwt
        });

        var response = await client.PostAsync(GoogleTokenUrl, tokenRequest, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("Failed to obtain FCM access token: {StatusCode} {Body}", (int)response.StatusCode, responseBody);
            throw new InvalidOperationException($"Failed to obtain FCM access token: HTTP {(int)response.StatusCode}");
        }

        using var doc = JsonDocument.Parse(responseBody);
        var accessToken = doc.RootElement.TryGetProperty("access_token", out var tokenProp)
            ? tokenProp.GetString()
            : null;

        if (string.IsNullOrEmpty(accessToken))
        {
            throw new InvalidOperationException("FCM access token response did not contain access_token");
        }

        return accessToken;
    }

    /// <summary>
    /// Generates a signed JWT for Google OAuth2 service account authentication
    /// </summary>
    private static string GenerateServiceAccountJwt(ServiceAccountInfo serviceAccount)
    {
        var now = DateTimeOffset.UtcNow;
        var expiry = now.AddMinutes(60);

        var header = JsonSerializer.Serialize(new { alg = "RS256", typ = "JWT" });
        var claims = JsonSerializer.Serialize(new
        {
            iss = serviceAccount.ClientEmail,
            scope = FcmScope,
            aud = GoogleTokenUrl,
            iat = now.ToUnixTimeSeconds(),
            exp = expiry.ToUnixTimeSeconds()
        });

        var headerBase64 = Base64UrlEncode(Encoding.UTF8.GetBytes(header));
        var claimsBase64 = Base64UrlEncode(Encoding.UTF8.GetBytes(claims));
        var unsignedToken = $"{headerBase64}.{claimsBase64}";

        using var rsa = RSA.Create();
        var privateKey = serviceAccount.PrivateKey
            .Replace("-----BEGIN PRIVATE KEY-----", "")
            .Replace("-----END PRIVATE KEY-----", "")
            .Replace("\n", "")
            .Replace("\r", "")
            .Trim();

        rsa.ImportPkcs8PrivateKey(Convert.FromBase64String(privateKey), out _);
        var signature = rsa.SignData(Encoding.UTF8.GetBytes(unsignedToken), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        var signatureBase64 = Base64UrlEncode(signature);

        return $"{unsignedToken}.{signatureBase64}";
    }

    /// <summary>
    /// Reads and parses the Google service account JSON file
    /// </summary>
    private ServiceAccountInfo? ReadServiceAccountJson()
    {
        var json = File.ReadAllText(_settings.ServiceAccountJsonPath);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var clientEmail = root.TryGetProperty("client_email", out var emailProp)
            ? emailProp.GetString()
            : null;

        var privateKey = root.TryGetProperty("private_key", out var keyProp)
            ? keyProp.GetString()
            : null;

        if (clientEmail == null || privateKey == null)
        {
            return null;
        }

        return new ServiceAccountInfo(clientEmail, privateKey);
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

    /// <summary>
    /// Internal representation of Google service account credentials
    /// </summary>
    private sealed record ServiceAccountInfo(string ClientEmail, string PrivateKey);
}
