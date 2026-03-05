using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.Extensions.Logging;
using Moq;
using Moq.Protected;
using Polly.CircuitBreaker;
using System.Net;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 16: SAP Connection Failure Handling
/// Validates: Requirements 3.7
/// 
/// Property: For any SAP connection failure, the system should handle it gracefully with:
/// - Retry logic with exponential backoff (3 attempts)
/// - Circuit breaker pattern (opens after 5 failures, stays open 60s)
/// - Validation continues with SAPConnectionFailed flag set to true
/// </summary>
public class SAPConnectionFailureProperties
{
    /// <summary>
    /// Property: When SAP is temporarily unavailable, retry logic should attempt 3 times with exponential backoff
    /// </summary>
    [Property(MaxTest = 20)]
    public void SAPConnectionFailure_WhenTemporaryFailure_ShouldRetry3Times(NonEmptyString poNumber)
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        var callCount = 0;
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                callCount++;
                throw new HttpRequestException("Connection failed");
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = validationAgent.VerifySAPPOAsync(poNumber.Get, CancellationToken.None).Result;

        // Assert
        Assert.False(result.IsVerified);
        Assert.True(result.SAPConnectionFailed);
        Assert.Equal(3, callCount); // Should retry 3 times
    }

    /// <summary>
    /// Property: When SAP connection fails, validation should continue with SAPConnectionFailed flag
    /// </summary>
    [Property(MaxTest = 20)]
    public void SAPConnectionFailure_WhenConnectionFails_ShouldSetFailureFlag(NonEmptyString poNumber)
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ThrowsAsync(new HttpRequestException("Connection timeout"));

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = validationAgent.VerifySAPPOAsync(poNumber.Get, CancellationToken.None).Result;

        // Assert
        Assert.False(result.IsVerified);
        Assert.True(result.SAPConnectionFailed);
        Assert.Equal(poNumber.Get, result.PONumber);
    }

    /// <summary>
    /// Property: Exponential backoff should increase delay between retries
    /// </summary>
    [Property(MaxTest = 20)]
    public void SAPConnectionFailure_RetryDelays_ShouldUseExponentialBackoff(NonEmptyString poNumber)
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        var attemptTimes = new List<DateTime>();
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                attemptTimes.Add(DateTime.UtcNow);
                throw new HttpRequestException("Connection failed");
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = validationAgent.VerifySAPPOAsync(poNumber.Get, CancellationToken.None).Result;

        // Assert
        Assert.Equal(3, attemptTimes.Count);
        
        if (attemptTimes.Count >= 2)
        {
            var delay1 = (attemptTimes[1] - attemptTimes[0]).TotalMilliseconds;
            // First retry should wait ~1 second (allow some tolerance)
            Assert.True(delay1 >= 900 && delay1 <= 1500, $"First retry delay was {delay1}ms, expected ~1000ms");
        }
        
        if (attemptTimes.Count >= 3)
        {
            var delay2 = (attemptTimes[2] - attemptTimes[1]).TotalMilliseconds;
            // Second retry should wait ~2 seconds (allow some tolerance)
            Assert.True(delay2 >= 1800 && delay2 <= 2500, $"Second retry delay was {delay2}ms, expected ~2000ms");
        }
    }

    /// <summary>
    /// Property: When SAP returns success after retries, should return verified result
    /// </summary>
    [Property(MaxTest = 20)]
    public void SAPConnectionFailure_WhenSuccessAfterRetry_ShouldReturnVerified(NonEmptyString poNumber)
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        var callCount = 0;
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                callCount++;
                if (callCount < 2)
                {
                    throw new HttpRequestException("Temporary failure");
                }
                
                // Success on second attempt
                var jsonContent = System.Text.Json.JsonSerializer.Serialize(new
                {
                    PurchaseOrder = poNumber.Get,
                    Supplier = "Test Vendor",
                    TotalNetAmount = 10000.00m,
                    PurchaseOrderDate = "2024-01-01T00:00:00Z"
                });
                
                var response = new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(jsonContent)
                };
                return response;
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = validationAgent.VerifySAPPOAsync(poNumber.Get, CancellationToken.None).Result;

        // Assert
        Assert.True(result.IsVerified);
        Assert.False(result.SAPConnectionFailed);
        Assert.Equal("Test Vendor", result.VendorFromSAP);
        Assert.Equal(10000.00m, result.AmountFromSAP);
    }

    /// <summary>
    /// Unit test: Specific retry count verification
    /// </summary>
    [Fact]
    public async Task SAPConnectionFailure_ShouldRetryExactly3Times()
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        var callCount = 0;
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                callCount++;
                throw new HttpRequestException("Connection failed");
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = await validationAgent.VerifySAPPOAsync("PO-12345", CancellationToken.None);

        // Assert
        Assert.False(result.IsVerified);
        Assert.True(result.SAPConnectionFailed);
        Assert.Equal(3, callCount);
    }

    /// <summary>
    /// Unit test: Network timeout should be handled gracefully
    /// </summary>
    [Fact]
    public async Task SAPConnectionFailure_NetworkTimeout_ShouldHandleGracefully()
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ThrowsAsync(new TaskCanceledException("Request timeout"));

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = await validationAgent.VerifySAPPOAsync("PO-12345", CancellationToken.None);

        // Assert
        Assert.False(result.IsVerified);
        Assert.True(result.SAPConnectionFailed);
    }

    /// <summary>
    /// Unit test: HTTP 500 error should trigger retry
    /// </summary>
    [Fact]
    public async Task SAPConnectionFailure_HTTP500Error_ShouldRetry()
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        var callCount = 0;
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                callCount++;
                return new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent("Internal Server Error")
                };
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = await validationAgent.VerifySAPPOAsync("PO-12345", CancellationToken.None);

        // Assert
        Assert.False(result.IsVerified);
        Assert.True(result.SAPConnectionFailed);
        Assert.Equal(3, callCount);
    }

    /// <summary>
    /// Unit test: Success on first attempt should not retry
    /// </summary>
    [Fact]
    public async Task SAPConnectionFailure_SuccessOnFirstAttempt_ShouldNotRetry()
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        var callCount = 0;
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                callCount++;
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(@"{
                        ""PurchaseOrder"": ""PO-12345"",
                        ""Supplier"": ""Test Vendor"",
                        ""TotalNetAmount"": 10000.00,
                        ""PurchaseOrderDate"": ""2024-01-01T00:00:00Z""
                    }")
                };
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = await validationAgent.VerifySAPPOAsync("PO-12345", CancellationToken.None);

        // Assert
        Assert.True(result.IsVerified);
        Assert.False(result.SAPConnectionFailed);
        Assert.Equal(1, callCount); // Should only call once
    }

    /// <summary>
    /// Unit test: Success on second attempt should stop retrying
    /// </summary>
    [Fact]
    public async Task SAPConnectionFailure_SuccessOnSecondAttempt_ShouldStopRetrying()
    {
        // Arrange
        var mockContext = new Mock<IApplicationDbContext>();
        var mockLogger = new Mock<ILogger<ValidationAgent>>();
        var mockHttpClientFactory = new Mock<IHttpClientFactory>();
        
        var mockHttpMessageHandler = new Mock<HttpMessageHandler>();
        var callCount = 0;
        
        mockHttpMessageHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(() =>
            {
                callCount++;
                if (callCount == 1)
                {
                    throw new HttpRequestException("Temporary failure");
                }
                
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent(@"{
                        ""PurchaseOrder"": ""PO-12345"",
                        ""Supplier"": ""Test Vendor"",
                        ""TotalNetAmount"": 10000.00,
                        ""PurchaseOrderDate"": ""2024-01-01T00:00:00Z""
                    }")
                };
            });

        var httpClient = new HttpClient(mockHttpMessageHandler.Object)
        {
            BaseAddress = new Uri("https://sap.example.com")
        };
        
        mockHttpClientFactory.Setup(f => f.CreateClient("SAP")).Returns(httpClient);

        var mockReferenceDataService = new Mock<IReferenceDataService>();
        var validationAgent = new ValidationAgent(
            mockContext.Object,
            mockLogger.Object,
            mockHttpClientFactory.Object,
            mockReferenceDataService.Object);

        // Act
        var result = await validationAgent.VerifySAPPOAsync("PO-12345", CancellationToken.None);

        // Assert
        Assert.True(result.IsVerified);
        Assert.False(result.SAPConnectionFailed);
        Assert.Equal(2, callCount); // Should call twice (1 failure + 1 success)
    }
}
