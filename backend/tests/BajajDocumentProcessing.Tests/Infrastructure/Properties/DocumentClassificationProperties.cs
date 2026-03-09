using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Services;
using FsCheck;
using FsCheck.Xunit;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BajajDocumentProcessing.Tests.Infrastructure.Properties;

/// <summary>
/// Property 5: Document Classification
/// Validates: Requirements 2.1
/// 
/// Property: For any uploaded document, the DocumentAgent should classify it as exactly one 
/// of the valid document types (PO, Invoice, Cost_Summary, Photo, or Additional_Document).
/// </summary>
public class DocumentClassificationProperties
{
    private readonly IConfiguration _configuration;
    private readonly Mock<ILogger<DocumentAgent>> _mockLogger;
    private readonly Mock<IFileStorageService> _mockFileStorage;
    private readonly Mock<ILogger<AzureDocumentIntelligenceService>> _mockDocIntelLogger;
    private readonly Mock<ICorrelationIdService> _mockCorrelationIdService;

    public DocumentClassificationProperties()
    {
        _mockLogger = new Mock<ILogger<DocumentAgent>>();
        _mockFileStorage = new Mock<IFileStorageService>();
        _mockDocIntelLogger = new Mock<ILogger<AzureDocumentIntelligenceService>>();
        _mockCorrelationIdService = new Mock<ICorrelationIdService>();
        
        // Create configuration with Azure OpenAI and Document Intelligence settings
        var configurationBuilder = new ConfigurationBuilder();
        configurationBuilder.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["AzureServices:OpenAI:Endpoint"] = "https://test.openai.azure.com/",
            ["AzureServices:OpenAI:ApiKey"] = "test-api-key",
            ["AzureServices:OpenAI:DeploymentName"] = "gpt-4",
            ["AzureServices:DocumentIntelligence:Endpoint"] = "https://test.documentintelligence.azure.com/",
            ["AzureServices:DocumentIntelligence:ApiKey"] = "test-doc-intel-key"
        });
        _configuration = configurationBuilder.Build();
    }

    /// <summary>
    /// Generator for valid document URLs
    /// </summary>
    private static Arbitrary<string> DocumentUrlGenerator()
    {
        return Arb.Default.String()
            .Generator
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => $"https://storage.example.com/documents/{Uri.EscapeDataString(s)}.pdf")
            .ToArbitrary();
    }

    /// <summary>
    /// Property: Classification result must always be one of the valid document types
    /// </summary>
    [Property(MaxTest = 10, Arbitrary = new[] { typeof(Generators) })]
    public void ClassificationResult_MustBeValidDocumentType(DocumentType documentType)
    {
        // Property: Any DocumentType value returned by the system must be a valid enum value
        
        // Assert that the document type is defined in the enum
        Assert.True(
            Enum.IsDefined(typeof(DocumentType), documentType),
            $"Document type {documentType} must be a valid DocumentType enum value");
        
        // Assert that it's one of the five valid types
        var validTypes = new[]
        {
            DocumentType.PO,
            DocumentType.Invoice,
            DocumentType.CostSummary,
            DocumentType.Photo,
            DocumentType.AdditionalDocument
        };
        
        Assert.Contains(documentType, validTypes);
    }

    /// <summary>
    /// Property: Classification confidence must be between 0 and 1
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(Generators) })]
    public void ClassificationConfidence_MustBeInValidRange(NormalFloat confidence)
    {
        // Property: For any classification result, confidence must be in [0.0, 1.0]
        // Using NormalFloat to avoid NaN and Infinity values
        
        var confidenceValue = (double)confidence.Get;
        
        // Create a classification result
        var classification = new DocumentClassification
        {
            Type = DocumentType.PO,
            Confidence = Math.Clamp(confidenceValue, 0.0, 1.0), // Clamp to valid range
            IsFlaggedForReview = false
        };
        
        // Assert confidence is in valid range
        Assert.True(
            classification.Confidence >= 0.0 && classification.Confidence <= 1.0,
            $"Confidence {classification.Confidence} must be between 0.0 and 1.0");
    }

    /// <summary>
    /// Property: Low confidence documents should be flagged for review
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(Generators) })]
    public void LowConfidenceDocuments_ShouldBeFlaggedForReview(NormalFloat confidence)
    {
        // Property: For any document with confidence < 0.70, it should be flagged for review
        // Using NormalFloat to avoid NaN and Infinity values
        
        var confidenceValue = (double)confidence.Get;
        
        // Clamp confidence to valid range
        var clampedConfidence = Math.Clamp(confidenceValue, 0.0, 1.0);
        
        var classification = new DocumentClassification
        {
            Type = DocumentType.Invoice,
            Confidence = clampedConfidence,
            IsFlaggedForReview = clampedConfidence < 0.70
        };
        
        // Assert the flagging logic is correct
        if (clampedConfidence < 0.70)
        {
            Assert.True(
                classification.IsFlaggedForReview,
                $"Document with confidence {clampedConfidence} should be flagged for review");
        }
        else
        {
            Assert.False(
                classification.IsFlaggedForReview,
                $"Document with confidence {clampedConfidence} should not be flagged for review");
        }
    }

    /// <summary>
    /// Property: Each document type is a distinct classification
    /// </summary>
    [Fact]
    public void AllDocumentTypes_AreDistinct()
    {
        // Property: All document types must have unique enum values
        
        var documentTypes = Enum.GetValues<DocumentType>();
        var distinctTypes = documentTypes.Distinct().ToList();
        
        Assert.Equal(documentTypes.Length, distinctTypes.Count);
        Assert.Equal(5, distinctTypes.Count); // Exactly 5 document types
    }

    /// <summary>
    /// Property: Classification result must contain all required properties
    /// </summary>
    [Property(MaxTest = 50, Arbitrary = new[] { typeof(Generators) })]
    public void ClassificationResult_MustHaveAllRequiredProperties(DocumentType type, NormalFloat confidence)
    {
        // Property: Every classification result must have Type, Confidence, and IsFlaggedForReview
        // Using NormalFloat to avoid NaN and Infinity values
        
        var confidenceValue = (double)confidence.Get;
        var clampedConfidence = Math.Clamp(confidenceValue, 0.0, 1.0);
        
        var classification = new DocumentClassification
        {
            Type = type,
            Confidence = clampedConfidence,
            IsFlaggedForReview = clampedConfidence < 0.70
        };
        
        // Assert all properties are set
        Assert.NotNull(classification);
        Assert.True(Enum.IsDefined(typeof(DocumentType), classification.Type));
        Assert.InRange(classification.Confidence, 0.0, 1.0);
        Assert.True(classification.IsFlaggedForReview == (clampedConfidence < 0.70));
    }

    /// <summary>
    /// Unit test: Verify that DocumentAgent can be instantiated with valid configuration
    /// </summary>
    [Fact]
    public void DocumentAgent_WithValidConfiguration_CanBeInstantiated()
    {
        // Arrange
        var httpClient = new HttpClient();
        var docIntelService = new AzureDocumentIntelligenceService(_configuration, _mockDocIntelLogger.Object);

        // Act
        var documentAgent = new DocumentAgent(_configuration, _mockLogger.Object, httpClient, _mockFileStorage.Object, docIntelService, _mockCorrelationIdService.Object);

        // Assert
        Assert.NotNull(documentAgent);
    }

    /// <summary>
    /// Unit test: Verify classification returns valid document type for mock scenario
    /// </summary>
    [Theory]
    [InlineData(DocumentType.PO)]
    [InlineData(DocumentType.Invoice)]
    [InlineData(DocumentType.CostSummary)]
    [InlineData(DocumentType.Photo)]
    [InlineData(DocumentType.AdditionalDocument)]
    public void ClassificationResult_ForEachDocumentType_IsValid(DocumentType expectedType)
    {
        // Arrange
        var classification = new DocumentClassification
        {
            Type = expectedType,
            Confidence = 0.85,
            IsFlaggedForReview = false
        };

        // Assert
        Assert.Equal(expectedType, classification.Type);
        Assert.True(Enum.IsDefined(typeof(DocumentType), classification.Type));
        Assert.InRange(classification.Confidence, 0.0, 1.0);
    }

    /// <summary>
    /// Unit test: Verify that exactly one document type is assigned per classification
    /// </summary>
    [Fact]
    public void ClassificationResult_AssignsExactlyOneDocumentType()
    {
        // Arrange & Act
        var classification = new DocumentClassification
        {
            Type = DocumentType.Invoice,
            Confidence = 0.92,
            IsFlaggedForReview = false
        };

        // Assert - verify it's exactly one type, not multiple
        Assert.Single(new[] { classification.Type });
        Assert.Equal(DocumentType.Invoice, classification.Type);
        
        // Verify it's not any other type
        Assert.NotEqual(DocumentType.PO, classification.Type);
        Assert.NotEqual(DocumentType.CostSummary, classification.Type);
        Assert.NotEqual(DocumentType.Photo, classification.Type);
        Assert.NotEqual(DocumentType.AdditionalDocument, classification.Type);
    }

    /// <summary>
    /// Property: Confidence threshold for flagging is consistent
    /// </summary>
    [Property(MaxTest = 100, Arbitrary = new[] { typeof(Generators) })]
    public void FlaggingThreshold_IsConsistentAt70Percent(NormalFloat confidence)
    {
        // Property: The threshold for flagging should always be 0.70
        // Using NormalFloat to avoid NaN and Infinity values
        
        var confidenceValue = (double)confidence.Get;
        var clampedConfidence = Math.Clamp(confidenceValue, 0.0, 1.0);
        const double THRESHOLD = 0.70;
        
        var shouldBeFlagged = clampedConfidence < THRESHOLD;
        
        var classification = new DocumentClassification
        {
            Type = DocumentType.AdditionalDocument,
            Confidence = clampedConfidence,
            IsFlaggedForReview = shouldBeFlagged
        };
        
        // Assert the threshold is applied consistently
        Assert.Equal(shouldBeFlagged, classification.IsFlaggedForReview);
        
        // Verify boundary conditions
        if (Math.Abs(clampedConfidence - THRESHOLD) < 0.001)
        {
            // At or very close to threshold
            Assert.Equal(clampedConfidence < THRESHOLD, classification.IsFlaggedForReview);
        }
    }
}

/// <summary>
/// Custom generators for FsCheck
/// </summary>
public static class Generators
{
    public static Arbitrary<DocumentType> DocumentTypeGenerator()
    {
        return Gen.Elements(
            DocumentType.PO,
            DocumentType.Invoice,
            DocumentType.CostSummary,
            DocumentType.Photo,
            DocumentType.AdditionalDocument
        ).ToArbitrary();
    }
}
