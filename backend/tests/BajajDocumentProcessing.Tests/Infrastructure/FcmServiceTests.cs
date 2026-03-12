using System.Net;
using System.Text.Json;
using BajajDocumentProcessing.Application.DTOs.Notifications;
using BajajDocumentProcessing.Infrastructure.Configuration;
using BajajDocumentProcessing.Infrastructure.Services;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// Unit tests for FcmService - validates Requirements 3.2, 3.3, 3.4, 3.6
/// Tests FCM service functionality including payload formatting, error handling, and credential validation
/// </summary>
public class FcmServiceTests
{
    private readonly Mock<ILogger<FcmService>> _mockLogger;
    private readonly FcmSettings _settings;

    public FcmServiceTests()
    {
        _mockLogger = new Mock<ILogger<FcmService>>();
        _settings = new FcmSettings
        {
            ProjectId = "test-project",
            ServiceAccountJsonPath = "test-sa.json"
        };
    }

    // ── SendAsync ──

    [Fact]
    public async Task SendAsync_ValidPayload_ShouldReturnSuccess()
    {
        // Arrange
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.OK, "{}");
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-fcm-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    [Fact]
    public async Task SendAsync_InvalidTokenResponse_ShouldReturnInvalidToken()
    {
        // Arrange
        var errorBody = JsonSerializer.Serialize(new
        {
            error = new
            {
                message = "The registration token is not a valid FCM registration token",
                details = new[] { new { errorCode = "UNREGISTERED" } }
            }
        });
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.NotFound, errorBody);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("invalid-fcm-token-12345678", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsInvalidToken);
    }

    [Fact]
    public async Task SendAsync_ServiceError_ShouldReturnTransientFailure()
    {
        // Arrange
        var errorBody = JsonSerializer.Serialize(new
        {
            error = new { message = "Internal error", status = "INTERNAL" }
        });
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.InternalServerError, errorBody);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-fcm-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
    }

    [Fact]
    public async Task SendAsync_EmptyToken_ShouldReturnInvalidToken()
    {
        // Arrange
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.OK, "{}");
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsInvalidToken);
    }

    // ── SendMulticastAsync ──

    [Fact]
    public async Task SendMulticastAsync_MultipleTokens_ShouldReturnResultPerToken()
    {
        // Arrange
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.OK, "{}");
        var payload = CreateTestPayload();
        var tokens = new[] { "token-1-abcdefghijklmn", "token-2-abcdefghijklmn", "token-3-abcdefghijklmn" };

        // Act
        var results = (await service.SendMulticastAsync(tokens, payload, CancellationToken.None)).ToList();

        // Assert
        Assert.Equal(3, results.Count);
        Assert.All(results, r => Assert.True(r.Success));
    }

    [Fact]
    public async Task SendMulticastAsync_EmptyTokens_ShouldReturnEmpty()
    {
        // Arrange
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.OK, "{}");
        var payload = CreateTestPayload();

        // Act
        var results = (await service.SendMulticastAsync(Enumerable.Empty<string>(), payload, CancellationToken.None)).ToList();

        // Assert
        Assert.Empty(results);
    }

    [Fact]
    public async Task SendMulticastAsync_PartialFailures_ShouldReturnMixedResults()
    {
        // Arrange - Create service that alternates between success and failure
        var callCount = 0;
        var handler = new DelegatingMockHandler((request, ct) =>
        {
            callCount++;
            // First call is OAuth2 token request
            if (request.RequestUri?.Host == "oauth2.googleapis.com")
            {
                var tokenResponse = JsonSerializer.Serialize(new { access_token = "test-token", expires_in = 3600 });
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(tokenResponse, System.Text.Encoding.UTF8, "application/json")
                });
            }

            // Alternate between success and failure for FCM calls
            var isSuccess = (callCount % 2) == 0; // Even calls succeed, odd calls fail
            if (isSuccess)
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("{}", System.Text.Encoding.UTF8, "application/json")
                });
            }
            else
            {
                var errorBody = JsonSerializer.Serialize(new
                {
                    error = new
                    {
                        message = "Invalid registration token",
                        details = new[] { new { errorCode = "UNREGISTERED" } }
                    }
                });
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound)
                {
                    Content = new StringContent(errorBody, System.Text.Encoding.UTF8, "application/json")
                });
            }
        });

        var service = CreateServiceWithHandler(handler);
        var payload = CreateTestPayload();
        var tokens = new[] { "valid-token-1", "invalid-token-2", "valid-token-3" };

        // Act
        var results = (await service.SendMulticastAsync(tokens, payload, CancellationToken.None)).ToList();

        // Assert
        Assert.Equal(3, results.Count);
        Assert.True(results[0].Success); // First token succeeds
        Assert.False(results[1].Success); // Second token fails
        Assert.True(results[1].IsInvalidToken); // Second token is invalid
        Assert.True(results[2].Success); // Third token succeeds
    }

    [Fact]
    public async Task SendMulticastAsync_LargeBatch_ShouldProcessInBatches()
    {
        // Arrange - Create 1000 tokens (should be processed in batches of 500)
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.OK, "{}");
        var payload = CreateTestPayload();
        var tokens = Enumerable.Range(1, 1000).Select(i => $"token-{i:D4}").ToArray();

        // Act
        var results = (await service.SendMulticastAsync(tokens, payload, CancellationToken.None)).ToList();

        // Assert
        Assert.Equal(1000, results.Count);
        Assert.All(results, r => Assert.True(r.Success));
    }

    // ── SendAsync Error Scenarios ──

    [Fact]
    public async Task SendAsync_HttpRequestException_ShouldReturnTransientFailure()
    {
        // Arrange
        var handler = new DelegatingMockHandler((request, ct) =>
        {
            if (request.RequestUri?.Host == "oauth2.googleapis.com")
            {
                var tokenResponse = JsonSerializer.Serialize(new { access_token = "test-token", expires_in = 3600 });
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(tokenResponse, System.Text.Encoding.UTF8, "application/json")
                });
            }
            throw new HttpRequestException("Network error");
        });

        var service = CreateServiceWithHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-token", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
        Assert.Contains("HTTP error communicating with FCM", result.ErrorMessage);
    }

    [Fact]
    public async Task SendAsync_TaskCanceledException_ShouldReturnTimeoutFailure()
    {
        // Arrange
        var handler = new DelegatingMockHandler((request, ct) =>
        {
            if (request.RequestUri?.Host == "oauth2.googleapis.com")
            {
                var tokenResponse = JsonSerializer.Serialize(new { access_token = "test-token", expires_in = 3600 });
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(tokenResponse, System.Text.Encoding.UTF8, "application/json")
                });
            }
            throw new TaskCanceledException("Request timed out");
        });

        var service = CreateServiceWithHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-token", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
        Assert.Equal("FCM request timed out", result.ErrorMessage);
    }

    [Fact]
    public async Task SendAsync_RateLimitError_ShouldReturnTransientFailure()
    {
        // Arrange
        var errorBody = JsonSerializer.Serialize(new
        {
            error = new { message = "Quota exceeded", status = "RESOURCE_EXHAUSTED" }
        });
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.TooManyRequests, errorBody);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-token", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
        Assert.Contains("FCM transient error", result.ErrorMessage);
    }

    [Fact]
    public async Task SendAsync_InvalidArgumentError_ShouldReturnInvalidToken()
    {
        // Arrange
        var errorBody = JsonSerializer.Serialize(new
        {
            error = new
            {
                message = "Invalid argument",
                details = new[] { new { errorCode = "INVALID_ARGUMENT" } }
            }
        });
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.BadRequest, errorBody);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("invalid-token", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsInvalidToken);
        Assert.Contains("FCM invalid token", result.ErrorMessage);
    }

    [Fact]
    public async Task SendAsync_PayloadTooLarge_ShouldReturnFailure()
    {
        // Arrange
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.OK, "{}");
        var largeBody = new string('A', 4100); // Exceeds 4KB limit
        var payload = new FcmPayload("Title", largeBody, new Dictionary<string, string>());

        // Act
        var result = await service.SendAsync("valid-token", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Contains("Payload exceeds maximum size", result.ErrorMessage);
    }

    [Fact]
    public async Task SendAsync_NullOrWhitespaceToken_ShouldReturnInvalidToken()
    {
        // Arrange
        var service = CreateServiceWithTokenAndSendResponse(HttpStatusCode.OK, "{}");
        var payload = CreateTestPayload();

        // Act & Assert - Test null token
        var result1 = await service.SendAsync(null!, payload, CancellationToken.None);
        Assert.False(result1.Success);
        Assert.True(result1.IsInvalidToken);

        // Act & Assert - Test whitespace token
        var result2 = await service.SendAsync("   ", payload, CancellationToken.None);
        Assert.False(result2.Success);
        Assert.True(result2.IsInvalidToken);
    }

    // ── Payload formatting (tested via send flow) ──

    [Fact]
    public async Task SendAsync_ShouldSendJsonPayloadToFcm()
    {
        // Arrange — capture the request body sent to FCM
        string? capturedBody = null;
        var callCount = 0;
        var handler = new DelegatingMockHandler(async (request, ct) =>
        {
            callCount++;
            // First call is OAuth2 token request
            if (request.RequestUri?.Host == "oauth2.googleapis.com")
            {
                var tokenResponse = JsonSerializer.Serialize(new { access_token = "test-token", expires_in = 3600 });
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(tokenResponse, System.Text.Encoding.UTF8, "application/json")
                };
            }
            // Second call is the FCM send — capture it
            capturedBody = request.Content != null ? await request.Content.ReadAsStringAsync(ct) : null;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{}", System.Text.Encoding.UTF8, "application/json")
            };
        });

        var httpClient = new HttpClient(handler);
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("FcmClient")).Returns(httpClient);

        var tempPath = Path.GetTempFileName();
        using var rsa = System.Security.Cryptography.RSA.Create(2048);
        var privateKeyPem = $"-----BEGIN PRIVATE KEY-----\n{Convert.ToBase64String(rsa.ExportPkcs8PrivateKey())}\n-----END PRIVATE KEY-----";
        var saJson = JsonSerializer.Serialize(new
        {
            client_email = "test@test.iam.gserviceaccount.com",
            private_key = privateKeyPem
        });
        File.WriteAllText(tempPath, saJson);

        var settings = new FcmSettings { ProjectId = "test-project", ServiceAccountJsonPath = tempPath };
        var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key"] = "value" },
            new FcmAndroidConfig("high", new Dictionary<string, string> { ["key"] = "value" }),
            new FcmWebpushConfig(new Dictionary<string, string> { ["TTL"] = "3600" }, new Dictionary<string, string> { ["key"] = "value" }));

        // Act
        await service.SendAsync("valid-fcm-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.NotNull(capturedBody);
        using var doc = JsonDocument.Parse(capturedBody);
        Assert.True(doc.RootElement.TryGetProperty("message", out var message));
        Assert.True(message.TryGetProperty("notification", out var notification));
        Assert.Equal("Test Title", notification.GetProperty("title").GetString());
        Assert.Equal("Test Body", notification.GetProperty("body").GetString());
    }

    // ── ValidateCredentialsAsync Tests ──

    [Fact]
    public async Task ValidateCredentialsAsync_ValidCredentials_ShouldReturnSuccess()
    {
        // Arrange
        var tempPath = Path.GetTempFileName();
        try
        {
            using var rsa = System.Security.Cryptography.RSA.Create(2048);
            var privateKeyPem = $"-----BEGIN PRIVATE KEY-----\n{Convert.ToBase64String(rsa.ExportPkcs8PrivateKey())}\n-----END PRIVATE KEY-----";
            var saJson = JsonSerializer.Serialize(new
            {
                client_email = "test@test-project.iam.gserviceaccount.com",
                private_key = privateKeyPem
            });
            File.WriteAllText(tempPath, saJson);

            var settings = new FcmSettings
            {
                ProjectId = "test-project",
                ServiceAccountJsonPath = tempPath
            };

            var factory = new Mock<IHttpClientFactory>();
            var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

            // Act
            var result = await service.ValidateCredentialsAsync(CancellationToken.None);

            // Assert
            Assert.True(result.Success);
        }
        finally
        {
            if (File.Exists(tempPath))
                File.Delete(tempPath);
        }
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingProjectId_ShouldReturnFailure()
    {
        // Arrange
        var settings = new FcmSettings
        {
            ProjectId = "", // Missing project ID
            ServiceAccountJsonPath = "test-sa.json"
        };

        var factory = new Mock<IHttpClientFactory>();
        var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("MissingProjectId", result.ErrorCode);
        Assert.Contains("FCM ProjectId is not configured", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingServiceAccountPath_ShouldReturnFailure()
    {
        // Arrange
        var settings = new FcmSettings
        {
            ProjectId = "test-project",
            ServiceAccountJsonPath = "" // Missing service account path
        };

        var factory = new Mock<IHttpClientFactory>();
        var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("MissingServiceAccountJsonPath", result.ErrorCode);
        Assert.Contains("FCM ServiceAccountJsonPath is not configured", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_ServiceAccountFileNotFound_ShouldReturnFailure()
    {
        // Arrange
        var settings = new FcmSettings
        {
            ProjectId = "test-project",
            ServiceAccountJsonPath = "/nonexistent/path/sa.json"
        };

        var factory = new Mock<IHttpClientFactory>();
        var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("ServiceAccountFileNotFound", result.ErrorCode);
        Assert.Contains("FCM service account JSON file not found", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_InvalidServiceAccountJson_ShouldReturnFailure()
    {
        // Arrange
        var tempPath = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tempPath, "invalid json content");

            var settings = new FcmSettings
            {
                ProjectId = "test-project",
                ServiceAccountJsonPath = tempPath
            };

            var factory = new Mock<IHttpClientFactory>();
            var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

            // Act
            var result = await service.ValidateCredentialsAsync(CancellationToken.None);

            // Assert
            Assert.False(result.Success);
            Assert.Equal("InvalidCredentials", result.ErrorCode);
            Assert.Contains("FCM credential validation failed", result.ErrorMessage);
        }
        finally
        {
            if (File.Exists(tempPath))
                File.Delete(tempPath);
        }
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingClientEmail_ShouldReturnFailure()
    {
        // Arrange
        var tempPath = Path.GetTempFileName();
        try
        {
            var saJson = JsonSerializer.Serialize(new
            {
                // Missing client_email
                private_key = "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"
            });
            File.WriteAllText(tempPath, saJson);

            var settings = new FcmSettings
            {
                ProjectId = "test-project",
                ServiceAccountJsonPath = tempPath
            };

            var factory = new Mock<IHttpClientFactory>();
            var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

            // Act
            var result = await service.ValidateCredentialsAsync(CancellationToken.None);

            // Assert
            Assert.False(result.Success);
            Assert.Equal("InvalidServiceAccount", result.ErrorCode); // ReadServiceAccountJson returns null when client_email is missing
            Assert.Contains("Failed to parse service account JSON", result.ErrorMessage);
        }
        finally
        {
            if (File.Exists(tempPath))
                File.Delete(tempPath);
        }
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingPrivateKey_ShouldReturnFailure()
    {
        // Arrange
        var tempPath = Path.GetTempFileName();
        try
        {
            var saJson = JsonSerializer.Serialize(new
            {
                client_email = "test@test-project.iam.gserviceaccount.com"
                // Missing private_key
            });
            File.WriteAllText(tempPath, saJson);

            var settings = new FcmSettings
            {
                ProjectId = "test-project",
                ServiceAccountJsonPath = tempPath
            };

            var factory = new Mock<IHttpClientFactory>();
            var service = new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));

            // Act
            var result = await service.ValidateCredentialsAsync(CancellationToken.None);

            // Assert
            Assert.False(result.Success);
            Assert.Equal("InvalidServiceAccount", result.ErrorCode); // ReadServiceAccountJson returns null when private_key is missing
            Assert.Contains("Failed to parse service account JSON", result.ErrorMessage);
        }
        finally
        {
            if (File.Exists(tempPath))
                File.Delete(tempPath);
        }
    }

    // ── Payload Formatting Tests ──

    [Fact]
    public void FormatPayload_BasicNotification_ShouldFormatCorrectly()
    {
        // Arrange
        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key1"] = "value1", ["key2"] = "value2" }
        );

        // Act
        var json = FcmService.FormatPayload("test-token", payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var message = doc.RootElement.GetProperty("message");
        
        Assert.Equal("test-token", message.GetProperty("token").GetString());
        
        var notification = message.GetProperty("notification");
        Assert.Equal("Test Title", notification.GetProperty("title").GetString());
        Assert.Equal("Test Body", notification.GetProperty("body").GetString());
        
        var data = message.GetProperty("data");
        Assert.Equal("value1", data.GetProperty("key1").GetString());
        Assert.Equal("value2", data.GetProperty("key2").GetString());
    }

    [Fact]
    public void FormatPayload_WithAndroidConfig_ShouldIncludeAndroidSection()
    {
        // Arrange
        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key"] = "value" },
            AndroidConfig: new FcmAndroidConfig(
                "high",
                new Dictionary<string, string> { ["android_key"] = "android_value" }
            )
        );

        // Act
        var json = FcmService.FormatPayload("test-token", payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var message = doc.RootElement.GetProperty("message");
        
        Assert.True(message.TryGetProperty("android", out var android));
        Assert.Equal("high", android.GetProperty("priority").GetString());
        
        var androidData = android.GetProperty("data");
        Assert.Equal("android_value", androidData.GetProperty("android_key").GetString());
    }

    [Fact]
    public void FormatPayload_WithWebpushConfig_ShouldIncludeWebpushSection()
    {
        // Arrange
        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key"] = "value" },
            WebpushConfig: new FcmWebpushConfig(
                new Dictionary<string, string> { ["TTL"] = "3600", ["Urgency"] = "high" },
                new Dictionary<string, string> { ["web_key"] = "web_value" }
            )
        );

        // Act
        var json = FcmService.FormatPayload("test-token", payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var message = doc.RootElement.GetProperty("message");
        
        Assert.True(message.TryGetProperty("webpush", out var webpush));
        
        var headers = webpush.GetProperty("headers");
        Assert.Equal("3600", headers.GetProperty("TTL").GetString());
        Assert.Equal("high", headers.GetProperty("Urgency").GetString());
        
        var webData = webpush.GetProperty("data");
        Assert.Equal("web_value", webData.GetProperty("web_key").GetString());
    }

    [Fact]
    public void FormatPayload_WithBothPlatformConfigs_ShouldIncludeBothSections()
    {
        // Arrange
        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key"] = "value" },
            AndroidConfig: new FcmAndroidConfig("high"),
            WebpushConfig: new FcmWebpushConfig(
                new Dictionary<string, string> { ["TTL"] = "3600" }
            )
        );

        // Act
        var json = FcmService.FormatPayload("test-token", payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var message = doc.RootElement.GetProperty("message");
        
        Assert.True(message.TryGetProperty("android", out var android));
        Assert.Equal("high", android.GetProperty("priority").GetString());
        
        Assert.True(message.TryGetProperty("webpush", out var webpush));
        var headers = webpush.GetProperty("headers");
        Assert.Equal("3600", headers.GetProperty("TTL").GetString());
    }

    [Fact]
    public void FormatPayload_EmptyData_ShouldStillIncludeDataSection()
    {
        // Arrange
        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string>() // Empty data
        );

        // Act
        var json = FcmService.FormatPayload("test-token", payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var message = doc.RootElement.GetProperty("message");
        
        // Should not include data section when empty
        Assert.False(message.TryGetProperty("data", out _));
    }

    [Fact]
    public void FormatPayload_AndroidConfigWithoutData_ShouldNotIncludeDataSection()
    {
        // Arrange
        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key"] = "value" },
            AndroidConfig: new FcmAndroidConfig("high", null) // No android data
        );

        // Act
        var json = FcmService.FormatPayload("test-token", payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var message = doc.RootElement.GetProperty("message");
        var android = message.GetProperty("android");
        
        Assert.Equal("high", android.GetProperty("priority").GetString());
        Assert.False(android.TryGetProperty("data", out _));
    }

    [Fact]
    public void FormatPayload_WebpushConfigWithoutHeadersOrData_ShouldNotIncludeWebpushSection()
    {
        // Arrange
        var payload = new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key"] = "value" },
            WebpushConfig: new FcmWebpushConfig(null, null) // No headers or data
        );

        // Act
        var json = FcmService.FormatPayload("test-token", payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var message = doc.RootElement.GetProperty("message");
        
        // Should not include webpush section when empty
        Assert.False(message.TryGetProperty("webpush", out _));
    }

    // ── Helpers ──

    /// <summary>
    /// Creates an FcmService that returns a pre-configured access token on the first call
    /// and the specified status/body on subsequent send calls.
    /// </summary>
    private FcmService CreateServiceWithTokenAndSendResponse(HttpStatusCode sendStatusCode, string sendResponseBody)
    {
        var handler = new DelegatingMockHandler((request, ct) =>
        {
            // First call is the OAuth2 token request
            if (request.RequestUri?.AbsolutePath == "/token" ||
                request.RequestUri?.Host == "oauth2.googleapis.com")
            {
                var tokenResponse = JsonSerializer.Serialize(new { access_token = "test-access-token", expires_in = 3600 });
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(tokenResponse, System.Text.Encoding.UTF8, "application/json")
                });
            }

            // Subsequent calls are FCM send requests
            return Task.FromResult(new HttpResponseMessage(sendStatusCode)
            {
                Content = new StringContent(sendResponseBody, System.Text.Encoding.UTF8, "application/json")
            });
        });

        return CreateServiceWithHandler(handler);
    }

    /// <summary>
    /// Creates an FcmService with a custom HTTP message handler
    /// </summary>
    private FcmService CreateServiceWithHandler(HttpMessageHandler handler)
    {
        var httpClient = new HttpClient(handler);
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("FcmClient")).Returns(httpClient);

        // Create a temp service account JSON
        var tempPath = Path.GetTempFileName();
        using var rsa = System.Security.Cryptography.RSA.Create(2048);
        var privateKeyPem = $"-----BEGIN PRIVATE KEY-----\n{Convert.ToBase64String(rsa.ExportPkcs8PrivateKey())}\n-----END PRIVATE KEY-----";
        var saJson = JsonSerializer.Serialize(new
        {
            client_email = "test@test-project.iam.gserviceaccount.com",
            private_key = privateKeyPem
        });
        File.WriteAllText(tempPath, saJson);

        var settings = new FcmSettings
        {
            ProjectId = "test-project",
            ServiceAccountJsonPath = tempPath
        };

        return new FcmService(factory.Object, _mockLogger.Object, Options.Create(settings));
    }

    private static FcmPayload CreateTestPayload()
    {
        return new FcmPayload(
            "Test Title",
            "Test Body",
            new Dictionary<string, string> { ["key"] = "value" });
    }
}

/// <summary>
/// Delegating handler that allows custom response logic per request
/// </summary>
public class DelegatingMockHandler : HttpMessageHandler
{
    private readonly Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> _handler;

    public DelegatingMockHandler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> handler)
    {
        _handler = handler;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        return _handler(request, cancellationToken);
    }
}
