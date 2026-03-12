using System.Net;
using System.Text;
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
/// Unit tests for ApnsService
/// </summary>
public class ApnsServiceTests
{
    private readonly Mock<ILogger<ApnsService>> _mockLogger;
    private readonly ApnsSettings _settings;

    public ApnsServiceTests()
    {
        _mockLogger = new Mock<ILogger<ApnsService>>();
        _settings = new ApnsSettings
        {
            KeyId = "TESTKEY123",
            TeamId = "TESTTEAM12",
            BundleId = "com.bajaj.test",
            KeyFilePath = "test-key.p8",
            IsProduction = false
        };
    }

    // ── SendAsync ──

    [Fact]
    public async Task SendAsync_ValidPayload_ShouldReturnSuccess()
    {
        // Arrange
        var handler = new MockHttpMessageHandler(HttpStatusCode.OK, "");
        var service = CreateServiceWithHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-device-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    [Fact]
    public async Task SendAsync_InvalidTokenResponse_ShouldReturnInvalidToken()
    {
        // Arrange
        var errorBody = JsonSerializer.Serialize(new { reason = "BadDeviceToken" });
        var handler = new MockHttpMessageHandler(HttpStatusCode.BadRequest, errorBody);
        var service = CreateServiceWithHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("bad-device-token-1234567890ab", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsInvalidToken);
    }

    [Fact]
    public async Task SendAsync_ServiceError_ShouldReturnTransientFailure()
    {
        // Arrange
        var errorBody = JsonSerializer.Serialize(new { reason = "InternalServerError" });
        var handler = new MockHttpMessageHandler(HttpStatusCode.InternalServerError, errorBody);
        var service = CreateServiceWithHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-device-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
    }

    [Fact]
    public async Task SendAsync_EmptyToken_ShouldReturnInvalidToken()
    {
        // Arrange
        var handler = new MockHttpMessageHandler(HttpStatusCode.OK, "");
        var service = CreateServiceWithHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsInvalidToken);
    }

    // ── Payload formatting (tested via send flow) ──

    [Fact]
    public async Task SendAsync_ShouldSendJsonPayloadToApns()
    {
        // Arrange — capture the request body sent to APNs
        string? capturedBody = null;
        var handler = new DelegatingMockHandler(async (request, ct) =>
        {
            capturedBody = request.Content != null ? await request.Content.ReadAsStringAsync(ct) : null;
            return new HttpResponseMessage(HttpStatusCode.OK);
        });
        var service = CreateServiceWithDelegatingHandler(handler);
        var payload = new ApnsPayload(
            "Test Title",
            "Test Body",
            "default",
            1,
            new Dictionary<string, string> { ["deepLink"] = "app://test" });

        // Act
        await service.SendAsync("valid-device-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.NotNull(capturedBody);
        using var doc = JsonDocument.Parse(capturedBody);
        Assert.True(doc.RootElement.TryGetProperty("aps", out var aps));
        Assert.True(aps.TryGetProperty("alert", out var alert));
        Assert.Equal("Test Title", alert.GetProperty("title").GetString());
        Assert.Equal("Test Body", alert.GetProperty("body").GetString());
    }

    [Fact]
    public async Task SendAsync_PayloadExceedsMaxSize_ShouldReturnFailure()
    {
        // Arrange
        var handler = new MockHttpMessageHandler(HttpStatusCode.OK, "");
        var service = CreateServiceWithHandler(handler);
        
        // Create a payload that exceeds 4KB limit (4096 bytes)
        // JSON overhead + 5000 character body should definitely exceed 4KB
        var largeBody = new string('A', 5000);
        var payload = new ApnsPayload("Title", largeBody, "default", 1, null);

        // Act
        var result = await service.SendAsync("valid-device-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("PayloadTooLarge", result.ErrorCode);
        Assert.Contains("exceeds maximum size", result.ErrorMessage);
    }

    [Fact]
    public async Task SendAsync_HttpRequestException_ShouldReturnTransientFailure()
    {
        // Arrange
        var handler = new ThrowingMockHandler(new HttpRequestException("Network error"));
        var service = CreateServiceWithThrowingHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-device-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
        Assert.Equal("HttpError", result.ErrorCode);
        Assert.Contains("HTTP error communicating with APNs", result.ErrorMessage);
    }

    [Fact]
    public async Task SendAsync_Timeout_ShouldReturnTransientFailure()
    {
        // Arrange
        var handler = new ThrowingMockHandler(new TaskCanceledException("Timeout"));
        var service = CreateServiceWithThrowingHandler(handler);
        var payload = CreateTestPayload();

        // Act
        var result = await service.SendAsync("valid-device-token-1234567890", payload, CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.True(result.IsTransient);
        Assert.Equal("Timeout", result.ErrorCode);
        Assert.Contains("APNs request timed out", result.ErrorMessage);
    }

    // ── ValidateCredentialsAsync ──

    [Fact]
    public async Task ValidateCredentialsAsync_ValidCredentials_ShouldReturnSuccess()
    {
        // Arrange
        var handler = new MockHttpMessageHandler(HttpStatusCode.OK, "");
        var service = CreateServiceWithHandler(handler);

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.True(result.Success);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingKeyId_ShouldReturnFailure()
    {
        // Arrange
        var settings = new ApnsSettings
        {
            KeyId = "", // Missing
            TeamId = "TESTTEAM12",
            BundleId = "com.bajaj.test",
            KeyFilePath = "test-key.p8",
            IsProduction = false
        };
        var service = CreateServiceWithSettings(settings);

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("MissingKeyId", result.ErrorCode);
        Assert.Contains("KeyId is not configured", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingTeamId_ShouldReturnFailure()
    {
        // Arrange
        var settings = new ApnsSettings
        {
            KeyId = "TESTKEY123",
            TeamId = "", // Missing
            BundleId = "com.bajaj.test",
            KeyFilePath = "test-key.p8",
            IsProduction = false
        };
        var service = CreateServiceWithSettings(settings);

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("MissingTeamId", result.ErrorCode);
        Assert.Contains("TeamId is not configured", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingBundleId_ShouldReturnFailure()
    {
        // Arrange
        var settings = new ApnsSettings
        {
            KeyId = "TESTKEY123",
            TeamId = "TESTTEAM12",
            BundleId = "", // Missing
            KeyFilePath = "test-key.p8",
            IsProduction = false
        };
        var service = CreateServiceWithSettings(settings);

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("MissingBundleId", result.ErrorCode);
        Assert.Contains("BundleId is not configured", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_MissingKeyFilePath_ShouldReturnFailure()
    {
        // Arrange
        var settings = new ApnsSettings
        {
            KeyId = "TESTKEY123",
            TeamId = "TESTTEAM12",
            BundleId = "com.bajaj.test",
            KeyFilePath = "", // Missing
            IsProduction = false
        };
        var service = CreateServiceWithSettings(settings);

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("MissingKeyFilePath", result.ErrorCode);
        Assert.Contains("KeyFilePath is not configured", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_KeyFileNotFound_ShouldReturnFailure()
    {
        // Arrange
        var settings = new ApnsSettings
        {
            KeyId = "TESTKEY123",
            TeamId = "TESTTEAM12",
            BundleId = "com.bajaj.test",
            KeyFilePath = "nonexistent-key.p8", // File doesn't exist
            IsProduction = false
        };
        var service = CreateServiceWithSettings(settings);

        // Act
        var result = await service.ValidateCredentialsAsync(CancellationToken.None);

        // Assert
        Assert.False(result.Success);
        Assert.Equal("KeyFileNotFound", result.ErrorCode);
        Assert.Contains("P8 key file not found", result.ErrorMessage);
    }

    [Fact]
    public async Task ValidateCredentialsAsync_InvalidKeyFile_ShouldReturnFailure()
    {
        // Arrange
        var tempKeyPath = Path.GetTempFileName();
        File.WriteAllText(tempKeyPath, "invalid key content"); // Invalid P8 content

        var settings = new ApnsSettings
        {
            KeyId = "TESTKEY123",
            TeamId = "TESTTEAM12",
            BundleId = "com.bajaj.test",
            KeyFilePath = tempKeyPath,
            IsProduction = false
        };
        var service = CreateServiceWithSettings(settings);

        try
        {
            // Act
            var result = await service.ValidateCredentialsAsync(CancellationToken.None);

            // Assert
            Assert.False(result.Success);
            Assert.Equal("InvalidCredentials", result.ErrorCode);
            Assert.Contains("credential validation failed", result.ErrorMessage);
        }
        finally
        {
            File.Delete(tempKeyPath);
        }
    }

    // ── Payload Formatting Tests ──

    [Fact]
    public void FormatPayload_BasicPayload_ShouldCreateCorrectJson()
    {
        // Arrange
        var payload = new ApnsPayload("Test Title", "Test Body", "default", 5, null);

        // Act
        var json = ApnsService.FormatPayload(payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        
        Assert.True(root.TryGetProperty("aps", out var aps));
        Assert.True(aps.TryGetProperty("alert", out var alert));
        Assert.Equal("Test Title", alert.GetProperty("title").GetString());
        Assert.Equal("Test Body", alert.GetProperty("body").GetString());
        Assert.Equal("default", aps.GetProperty("sound").GetString());
        Assert.Equal(5, aps.GetProperty("badge").GetInt32());
        Assert.Equal(1, aps.GetProperty("mutable-content").GetInt32());
    }

    [Fact]
    public void FormatPayload_WithCustomData_ShouldIncludeCustomFields()
    {
        // Arrange
        var customData = new Dictionary<string, string>
        {
            ["deepLink"] = "app://submissions/123",
            ["notificationType"] = "SubmissionStatusUpdate",
            ["packageId"] = "pkg-456"
        };
        var payload = new ApnsPayload("Title", "Body", "custom.caf", 3, customData);

        // Act
        var json = ApnsService.FormatPayload(payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        
        Assert.True(root.TryGetProperty("aps", out var aps));
        Assert.Equal("custom.caf", aps.GetProperty("sound").GetString());
        Assert.Equal(3, aps.GetProperty("badge").GetInt32());
        
        // Custom data should be at root level
        Assert.Equal("app://submissions/123", root.GetProperty("deepLink").GetString());
        Assert.Equal("SubmissionStatusUpdate", root.GetProperty("notificationType").GetString());
        Assert.Equal("pkg-456", root.GetProperty("packageId").GetString());
    }

    [Fact]
    public void FormatPayload_EmptySound_ShouldUseDefault()
    {
        // Arrange
        var payload = new ApnsPayload("Title", "Body", "", 1, null);

        // Act
        var json = ApnsService.FormatPayload(payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var aps = doc.RootElement.GetProperty("aps");
        Assert.Equal("default", aps.GetProperty("sound").GetString());
    }

    [Fact]
    public void FormatPayload_NullSound_ShouldUseDefault()
    {
        // Arrange
        var payload = new ApnsPayload("Title", "Body", null, 1, null);

        // Act
        var json = ApnsService.FormatPayload(payload);

        // Assert
        using var doc = JsonDocument.Parse(json);
        var aps = doc.RootElement.GetProperty("aps");
        Assert.Equal("default", aps.GetProperty("sound").GetString());
    }

    private ApnsService CreateServiceWithDelegatingHandler(DelegatingMockHandler handler)
    {
        var httpClient = new HttpClient(handler);
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("ApnsClient")).Returns(httpClient);

        var tempKeyPath = Path.GetTempFileName();
        var ecDsa = System.Security.Cryptography.ECDsa.Create();
        var keyBytes = ecDsa.ExportPkcs8PrivateKey();
        var pem = $"-----BEGIN PRIVATE KEY-----\n{Convert.ToBase64String(keyBytes)}\n-----END PRIVATE KEY-----";
        File.WriteAllText(tempKeyPath, pem);

        var settings = new ApnsSettings
        {
            KeyId = _settings.KeyId,
            TeamId = _settings.TeamId,
            BundleId = _settings.BundleId,
            KeyFilePath = tempKeyPath,
            IsProduction = false
        };

        return new ApnsService(factory.Object, _mockLogger.Object, Options.Create(settings));
    }

    private ApnsService CreateServiceWithThrowingHandler(ThrowingMockHandler handler)
    {
        var httpClient = new HttpClient(handler);
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("ApnsClient")).Returns(httpClient);

        var tempKeyPath = Path.GetTempFileName();
        var ecDsa = System.Security.Cryptography.ECDsa.Create();
        var keyBytes = ecDsa.ExportPkcs8PrivateKey();
        var pem = $"-----BEGIN PRIVATE KEY-----\n{Convert.ToBase64String(keyBytes)}\n-----END PRIVATE KEY-----";
        File.WriteAllText(tempKeyPath, pem);

        var settings = new ApnsSettings
        {
            KeyId = _settings.KeyId,
            TeamId = _settings.TeamId,
            BundleId = _settings.BundleId,
            KeyFilePath = tempKeyPath,
            IsProduction = false
        };

        return new ApnsService(factory.Object, _mockLogger.Object, Options.Create(settings));
    }

    private ApnsService CreateServiceWithSettings(ApnsSettings settings)
    {
        var handler = new MockHttpMessageHandler(HttpStatusCode.OK, "");
        var httpClient = new HttpClient(handler);
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("ApnsClient")).Returns(httpClient);

        return new ApnsService(factory.Object, _mockLogger.Object, Options.Create(settings));
    }

    // ── Helpers ──

    private ApnsService CreateServiceWithHandler(MockHttpMessageHandler handler)
    {
        var httpClient = new HttpClient(handler);
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(f => f.CreateClient("ApnsClient")).Returns(httpClient);

        // Create a temp P8 key file for JWT generation
        var tempKeyPath = Path.GetTempFileName();
        var ecDsa = System.Security.Cryptography.ECDsa.Create();
        var keyBytes = ecDsa.ExportPkcs8PrivateKey();
        var pem = $"-----BEGIN PRIVATE KEY-----\n{Convert.ToBase64String(keyBytes)}\n-----END PRIVATE KEY-----";
        File.WriteAllText(tempKeyPath, pem);

        var settings = new ApnsSettings
        {
            KeyId = _settings.KeyId,
            TeamId = _settings.TeamId,
            BundleId = _settings.BundleId,
            KeyFilePath = tempKeyPath,
            IsProduction = false
        };

        return new ApnsService(factory.Object, _mockLogger.Object, Options.Create(settings));
    }

    private static ApnsPayload CreateTestPayload()
    {
        return new ApnsPayload(
            "Test Title",
            "Test Body",
            "default",
            1,
            new Dictionary<string, string> { ["deepLink"] = "app://test" });
    }
}

/// <summary>
/// Mock HTTP message handler for testing HTTP client calls
/// </summary>
public class MockHttpMessageHandler : HttpMessageHandler
{
    private readonly HttpStatusCode _statusCode;
    private readonly string _responseContent;

    public MockHttpMessageHandler(HttpStatusCode statusCode, string responseContent)
    {
        _statusCode = statusCode;
        _responseContent = responseContent;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var response = new HttpResponseMessage(_statusCode)
        {
            Content = new StringContent(_responseContent, Encoding.UTF8, "application/json")
        };
        return Task.FromResult(response);
    }
}

/// <summary>
/// Mock handler that throws exceptions for testing error scenarios
/// </summary>
public class ThrowingMockHandler : HttpMessageHandler
{
    private readonly Exception _exception;

    public ThrowingMockHandler(Exception exception)
    {
        _exception = exception;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        throw _exception;
    }
}
