using Azure;
using Azure.AI.OpenAI;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using MetadataExtractor;
using MetadataExtractor.Formats.Exif;
// CHANGE: Added ClosedXML for reading Excel files (Enquiry Dump)
using ClosedXML.Excel;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Document Agent service for document classification and field extraction using Azure OpenAI.
/// Supports both image files (via GPT-4 Vision) and document files (via Azure Document Intelligence + GPT-4).
/// </summary>
public class DocumentAgent : IDocumentAgent
{
    private readonly OpenAIClient _openAIClient;
    private readonly string _deploymentName;
    private readonly ILogger<DocumentAgent> _logger;
    private readonly HttpClient _httpClient;
    private readonly IFileStorageService _fileStorageService;
    private readonly AzureDocumentIntelligenceService _documentIntelligenceService;
    private readonly ICorrelationIdService _correlationIdService;
    private readonly IPerceptualHashService _perceptualHashService;
    private const double CONFIDENCE_THRESHOLD = 0.70;
    private const double FIELD_CONFIDENCE_THRESHOLD = 0.60;

    /// <summary>
    /// Initializes a new instance of the DocumentAgent class.
    /// Configures Azure OpenAI client for document processing.
    /// </summary>
    /// <param name="configuration">Application configuration containing Azure OpenAI settings</param>
    /// <param name="logger">Logger for diagnostic information</param>
    /// <param name="httpClient">HTTP client for external requests</param>
    /// <param name="fileStorageService">Service for accessing blob storage</param>
    /// <param name="documentIntelligenceService">Service for Azure Document Intelligence operations</param>
    /// <param name="correlationIdService">Service for accessing correlation ID</param>
    /// <param name="perceptualHashService">Service for computing perceptual hashes of images</param>
    /// <exception cref="InvalidOperationException">Thrown when Azure OpenAI configuration is missing</exception>
    public DocumentAgent(
        IConfiguration configuration,
        ILogger<DocumentAgent> logger,
        HttpClient httpClient,
        IFileStorageService fileStorageService,
        AzureDocumentIntelligenceService documentIntelligenceService,
        ICorrelationIdService correlationIdService,
        IPerceptualHashService perceptualHashService)
    {
        _logger = logger;
        _httpClient = httpClient;
        _fileStorageService = fileStorageService;
        _documentIntelligenceService = documentIntelligenceService;
        _correlationIdService = correlationIdService;
        _perceptualHashService = perceptualHashService;

        var endpoint = configuration["AzureOpenAI:Endpoint"] 
            ?? throw new InvalidOperationException("Azure OpenAI endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] 
            ?? throw new InvalidOperationException("Azure OpenAI API key not configured");
        _deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        _openAIClient = new OpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
    }

    /// <summary>
    /// Checks if the file is a document type that requires Azure Document Intelligence.
    /// Supports PDF and Word document formats.
    /// </summary>
    /// <param name="blobUrl">The blob URL to check</param>
    /// <returns>True if the file is a PDF or Word document; otherwise, false</returns>
    // CHANGE: Added .xls, .xlsx, .csv to recognized document file extensions for Enquiry Dump and Activity Summary
    private bool IsDocumentFile(string blobUrl)
    {
        var lowerUrl = blobUrl.ToLowerInvariant();
        return lowerUrl.EndsWith(".pdf") || 
               lowerUrl.EndsWith(".doc") || 
               lowerUrl.EndsWith(".docx") ||
               lowerUrl.EndsWith(".xls") ||
               lowerUrl.EndsWith(".xlsx") ||
               lowerUrl.EndsWith(".csv");
    }

    /// <summary>
    /// Checks if the file is an image that can be processed by Vision API.
    /// Supports common image formats including JPG, PNG, GIF, BMP, TIFF, and WebP.
    /// </summary>
    /// <param name="blobUrl">The blob URL to check</param>
    /// <returns>True if the file is a supported image format; otherwise, false</returns>
    private bool IsImageFile(string blobUrl)
    {
        var lowerUrl = blobUrl.ToLowerInvariant();
        return lowerUrl.EndsWith(".jpg") || 
               lowerUrl.EndsWith(".jpeg") || 
               lowerUrl.EndsWith(".png") || 
               lowerUrl.EndsWith(".gif") ||
               lowerUrl.EndsWith(".bmp") ||
               lowerUrl.EndsWith(".tiff") ||
               lowerUrl.EndsWith(".tif") ||
               lowerUrl.EndsWith(".webp");
    }

    /// <summary>
    /// Prepares image data for Azure OpenAI Vision API.
    /// For files larger than 100KB, uses SAS URL instead of data URI to avoid URI length limits.
    /// Returns null for non-image files (PDFs, Word docs).
    /// </summary>
    /// <param name="blobUrl">The blob URL of the image to prepare</param>
    /// <returns>A data URI or SAS URL for the image, or null if not an image file</returns>
    /// <exception cref="Exception">Thrown when image preparation fails</exception>
    private async Task<string?> PrepareImageDataAsync(string blobUrl)
    {
        try
        {
            // Check if it's a document file - these need Document Intelligence, not Vision
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected ({BlobUrl}) - will use Document Intelligence", blobUrl);
                return null;
            }
            
            // Check file size first
            var fileBytes = await _fileStorageService.GetFileBytesAsync(blobUrl);
            
            _logger.LogInformation("File size: {Size} bytes for {BlobUrl}", fileBytes.Length, blobUrl);
            
            // If file is larger than 100KB, use SAS URL instead of data URI
            if (fileBytes.Length > 100 * 1024)
            {
                _logger.LogInformation("File too large for data URI, generating SAS URL instead");
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                return sasUrl;
            }
            
            // For smaller files, use data URI
            var base64 = Convert.ToBase64String(fileBytes);
            
            // Determine MIME type from file extension
            var mimeType = "image/jpeg"; // default
            if (blobUrl.EndsWith(".png", StringComparison.OrdinalIgnoreCase))
                mimeType = "image/png";
            else if (blobUrl.EndsWith(".gif", StringComparison.OrdinalIgnoreCase))
                mimeType = "image/gif";
            else if (blobUrl.EndsWith(".webp", StringComparison.OrdinalIgnoreCase))
                mimeType = "image/webp";
            else if (blobUrl.EndsWith(".tiff", StringComparison.OrdinalIgnoreCase) || 
                     blobUrl.EndsWith(".tif", StringComparison.OrdinalIgnoreCase))
                mimeType = "image/tiff";
            else if (blobUrl.EndsWith(".bmp", StringComparison.OrdinalIgnoreCase))
                mimeType = "image/bmp";
            
            var dataUri = $"data:{mimeType};base64,{base64}";
            _logger.LogInformation("Created data URI of length: {Length}", dataUri.Length);
            return dataUri;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to prepare image data: {BlobUrl}", blobUrl);
            throw;
        }
    }

    /// <summary>
    /// Creates a ChatMessageImageContentItem from a URL (either data URI or HTTPS URL with SAS).
    /// Configures the image with high detail level for optimal extraction quality.
    /// </summary>
    /// <param name="imageUrl">The image URL (data URI or HTTPS URL)</param>
    /// <returns>A ChatMessageImageContentItem configured for GPT-4 Vision</returns>
    private ChatMessageImageContentItem CreateImageContentItem(string imageUrl)
    {
        // Azure OpenAI expects a URI (either HTTP/HTTPS URL or data URI)
        // For large files, we use SAS URLs; for small files, we use data URIs
        _logger.LogInformation("Creating image content item from URL: {UrlPrefix}", 
            imageUrl.Length > 100 ? imageUrl.Substring(0, 100) + "..." : imageUrl);
        
        // For GPT-4o and GPT-4o-mini, we need to use the detail parameter
        // Try creating with Uri and detail level
        var uri = new Uri(imageUrl);
        return new ChatMessageImageContentItem(uri, ChatMessageImageDetailLevel.High);
    }

    /// <summary>
    /// Classifies a document using Azure OpenAI GPT-4 Vision for images.
    /// For PDFs/Word docs, returns classification based on user's document type selection.
    /// </summary>
    /// <param name="blobUrl">The blob URL of the document to classify</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>A DocumentClassification containing the document type and confidence score</returns>
    /// <exception cref="Exception">Thrown when classification fails</exception>
    public async Task<DocumentClassification> ClassifyAsync(
        string blobUrl, 
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        
        try
        {
            _logger.LogInformation(
                "Starting document classification for URL: {BlobUrl}. CorrelationId: {CorrelationId}",
                blobUrl, correlationId);

            // For document files (PDF, Word), we trust the user's document type selection
            // Classification will be based on extraction results
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected - classification will be based on user selection and extraction");
                return new DocumentClassification
                {
                    Type = DocumentType.Invoice, // Default, will be overridden by user's selection
                    Confidence = 0.95, // High confidence since user selected the type
                    IsFlaggedForReview = false
                };
            }

            // For images, use Vision API for classification
            var imageData = await PrepareImageDataAsync(blobUrl);
            
            if (imageData == null)
            {
                _logger.LogWarning("Could not prepare image data for classification");
                return new DocumentClassification
                {
                    Type = DocumentType.TeamPhoto, // Default to TeamPhoto for unclassifiable images
                    Confidence = 0.5,
                    IsFlaggedForReview = true
                };
            }

            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    new ChatRequestSystemMessage(@"You are a document classification expert. 
Analyze the provided document image and classify it into exactly one of these categories:
- PO (Purchase Order)
- Invoice
- Cost_Summary (Cost Summary spreadsheet or document)
- Photo (Activity photo or site photo)
- Additional_Document (Any other supporting document like contracts, agreements, etc.)

Respond ONLY with a JSON object in this exact format:
{
  ""type"": ""<document_type>"",
  ""confidence"": <0.0-1.0>,
  ""reasoning"": ""<brief explanation>""
}

Where:
- type is one of: PO, Invoice, Cost_Summary, Photo, Additional_Document
- confidence is a number between 0.0 and 1.0
- reasoning is a brief explanation of your classification

Be precise and confident in your classification."),
                    new ChatRequestUserMessage(
                        new ChatMessageContentItem[]
                        {
                            new ChatMessageTextContentItem("Please classify this document image."),
                            CreateImageContentItem(imageData)
                        })
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(
                chatCompletionsOptions, 
                cancellationToken);

            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received classification response: {Content}", content);

            // Parse the JSON response
            var classificationResult = ParseClassificationResponse(content);

            var result = new DocumentClassification
            {
                Type = classificationResult.Type,
                Confidence = classificationResult.Confidence,
                IsFlaggedForReview = classificationResult.Confidence < CONFIDENCE_THRESHOLD
            };

            _logger.LogInformation(
                "Document classified as {Type} with confidence {Confidence}. Flagged for review: {Flagged}. CorrelationId: {CorrelationId}",
                result.Type, result.Confidence, result.IsFlaggedForReview, correlationId);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error classifying document from URL: {BlobUrl}. CorrelationId: {CorrelationId}",
                blobUrl, correlationId);
            throw;
        }
    }

    private ClassificationResponse ParseClassificationResponse(string content)
    {
        try
        {
            // Remove markdown code blocks if present
            var jsonContent = content.Trim();
            if (jsonContent.StartsWith("```json"))
            {
                jsonContent = jsonContent.Substring(7);
            }
            if (jsonContent.StartsWith("```"))
            {
                jsonContent = jsonContent.Substring(3);
            }
            if (jsonContent.EndsWith("```"))
            {
                jsonContent = jsonContent.Substring(0, jsonContent.Length - 3);
            }
            jsonContent = jsonContent.Trim();

            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };

            var parsed = JsonSerializer.Deserialize<ClassificationResponse>(jsonContent, options);
            
            if (parsed == null)
            {
                throw new InvalidOperationException("Failed to parse classification response");
            }

            // Validate the document type
            if (!Enum.TryParse<DocumentType>(parsed.TypeString, true, out var documentType))
            {
                _logger.LogWarning(
                    "Invalid document type '{Type}' returned. Defaulting to TeamPhoto", 
                    parsed.TypeString);
                documentType = DocumentType.TeamPhoto; // Default to TeamPhoto for unrecognized types
                parsed.Confidence = 0.5; // Lower confidence for fallback
            }

            parsed.Type = documentType;
            return parsed;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse classification response: {Content}", content);
            
            // Return a default classification with low confidence
            return new ClassificationResponse
            {
                Type = DocumentType.TeamPhoto, // Default to TeamPhoto for parse failures
                TypeString = "TeamPhoto",
                Confidence = 0.3,
                Reasoning = "Failed to parse classification response"
            };
        }
    }

    private class ClassificationResponse
    {
        [System.Text.Json.Serialization.JsonPropertyName("type")]
        public string TypeString { get; set; } = string.Empty;
        
        [System.Text.Json.Serialization.JsonIgnore]
        public DocumentType Type { get; set; }
        
        [System.Text.Json.Serialization.JsonPropertyName("confidence")]
        public double Confidence { get; set; }
        
        [System.Text.Json.Serialization.JsonPropertyName("reasoning")]
        public string Reasoning { get; set; } = string.Empty;
    }

    /// <summary>
    /// Extracts structured data from a Purchase Order document.
    /// Uses Azure Document Intelligence for PDFs/Word docs, GPT-4 Vision for images.
    /// Extracts all PO fields including line items, vendor details, and amounts.
    /// </summary>
    /// <param name="blobUrl">The blob URL of the PO document</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>POData containing all extracted purchase order information</returns>
    /// <exception cref="Exception">Thrown when extraction fails</exception>
    public async Task<POData> ExtractPOAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        var totalStopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            _logger.LogInformation(
                "🔍 [PO EXTRACTION START] URL: {BlobUrl}, CorrelationId: {CorrelationId}",
                blobUrl, correlationId);

            // CHANGE: Switched from direct Document Intelligence to hybrid approach (Doc Intelligence extracts text → OpenAI analyzes text)
            // For document files (PDF, Word), use Azure Document Intelligence to extract text, then OpenAI to analyze
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("📄 [PO] Document file detected - using hybrid extraction (Document Intelligence + OpenAI)");
                
                var sasStopwatch = System.Diagnostics.Stopwatch.StartNew();
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                sasStopwatch.Stop();
                _logger.LogInformation("⏱️ [PO - Step 1] SAS URL Generation: {ElapsedMs}ms", sasStopwatch.ElapsedMilliseconds);
                
                try
                {
                    // CHANGE: Extract raw text from PDF using Document Intelligence
                    var textExtractionStopwatch = System.Diagnostics.Stopwatch.StartNew();
                    var extractedText = await ExtractTextFromPdfAsync(new Uri(sasUrl), cancellationToken);
                    textExtractionStopwatch.Stop();
                    _logger.LogInformation("⏱️ [PO - Step 2] Document Intelligence Text Extraction: {ElapsedMs}ms, Text Length: {TextLength} chars", 
                        textExtractionStopwatch.ElapsedMilliseconds, extractedText?.Length ?? 0);
                    
                    // CHANGE: Send extracted text to OpenAI for detailed field extraction
                    var openAIStopwatch = System.Diagnostics.Stopwatch.StartNew();
                    var result = await AnalyzePOTextAsync(extractedText, cancellationToken);
                    openAIStopwatch.Stop();
                    _logger.LogInformation("⏱️ [PO - Step 3] OpenAI Text Analysis: {ElapsedMs}ms", openAIStopwatch.ElapsedMilliseconds);
                    
                    totalStopwatch.Stop();
                    _logger.LogInformation(
                        "✅ [PO EXTRACTION COMPLETE] Total: {TotalMs}ms (SAS: {SasMs}ms, DocIntel: {DocIntelMs}ms, OpenAI: {OpenAIMs}ms) - PO: {PONumber}, Amount: {Amount}",
                        totalStopwatch.ElapsedMilliseconds, sasStopwatch.ElapsedMilliseconds, 
                        textExtractionStopwatch.ElapsedMilliseconds, openAIStopwatch.ElapsedMilliseconds,
                        result.PONumber, result.TotalAmount);
                    return result;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "❌ [PO] Error in hybrid extraction, falling back to Document Intelligence only");
                    var fallbackStopwatch = System.Diagnostics.Stopwatch.StartNew();
                    var result = await _documentIntelligenceService.ExtractPOAsync(new Uri(sasUrl), cancellationToken);
                    fallbackStopwatch.Stop();
                    _logger.LogInformation("⏱️ [PO - Fallback] Document Intelligence Only: {ElapsedMs}ms", fallbackStopwatch.ElapsedMilliseconds);
                    totalStopwatch.Stop();
                    _logger.LogInformation("✅ [PO EXTRACTION COMPLETE - Fallback] Total: {TotalMs}ms", totalStopwatch.ElapsedMilliseconds);
                    return result;
                }
            }

            // For images, use GPT-4 Vision
            _logger.LogInformation("🖼️ [PO] Image file detected - using GPT-4 Vision");
            
            var imageStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var imageData = await PrepareImageDataAsync(blobUrl);
            imageStopwatch.Stop();
            _logger.LogInformation("⏱️ [PO - Step 1] Image Preparation: {ElapsedMs}ms", imageStopwatch.ElapsedMilliseconds);
            
            if (imageData == null)
            {
                _logger.LogWarning("⚠️ [PO] Could not prepare image data for extraction");
                return new POData
                {
                    FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                    IsFlaggedForReview = true
                };
            }

            var visionStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    // CHANGE: Expanded PO image prompt to extract all fields like Invoice
                    new ChatRequestSystemMessage(@"You are a Purchase Order data extraction expert with exceptional OCR capabilities.
Carefully analyze the provided PO document image and extract ALL visible information with high accuracy.

REQUIRED FIELDS TO EXTRACT:
1. PO Number - Look for: 'PO No', 'PO Number', 'Purchase Order'
2. PO Type - Look for: 'PO TYPE', 'Order Type' (e.g., 'Marketing PO')
3. Vendor Name - Look for: 'Vendor', 'Supplier'
4. Vendor Code - Look for: 'Vendor Code'
5. Vendor Address - Look for: 'Vendor Address'
6. Buyer Name - Look for: 'Buyer'
7. Delivery Terms - Look for: 'Delivery Terms'
8. Payment Terms - Look for: 'Payment Terms'
9. PO Date - Look for: 'PO Date' (format: YYYY-MM-DD)
10. Total Amount - Look for: 'Total PO Price', 'Total Amount'
11. Line Items - ALL items with Item Code, Description, Qty, Rate, Amount, Plant, Tax Code, Currency

CRITICAL INSTRUCTIONS:
- Extract EXACT values visible in the image.
- Remove currency symbols and commas from amounts.
- If a field is not found, use empty string for text, 0 for numbers.

Respond ONLY with a JSON object in this exact format:
{
  ""poNumber"": ""string"",
  ""poType"": ""string"",
  ""vendorName"": ""string"",
  ""vendorCode"": ""string"",
  ""vendorAddress"": ""string"",
  ""buyerName"": ""string"",
  ""deliveryTerms"": ""string"",
  ""paymentTerms"": ""string"",
  ""poDate"": ""YYYY-MM-DD"",
  ""totalAmount"": 0.00,
  ""lineItems"": [
    {
      ""itemCode"": ""string"",
      ""description"": ""string"",
      ""quantity"": 0,
      ""unitPrice"": 0.00,
      ""lineTotal"": 0.00,
      ""plant"": ""string"",
      ""taxCode"": ""string"",
      ""currency"": ""string"",
    }
  ],
  ""confidence"": 0.0
}

Where confidence is your overall confidence in the extraction (0.0 to 1.0).
Extract EVERY field you can see. Do not leave fields empty if data is visible in the image."),
                    new ChatRequestUserMessage(
                        new ChatMessageContentItem[]
                        {
                            new ChatMessageTextContentItem("Please extract ALL data from this Purchase Order image. Be thorough and accurate."),
                            CreateImageContentItem(imageData)
                        })
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(
                chatCompletionsOptions, 
                cancellationToken);
            visionStopwatch.Stop();
            _logger.LogInformation("⏱️ [PO - Step 2] GPT-4 Vision API Call: {ElapsedMs}ms", visionStopwatch.ElapsedMilliseconds);

            var parseStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("📝 [PO] Received extraction response: {ResponseLength} chars", content?.Length ?? 0);

            var poData = ParsePOResponse(content);
            parseStopwatch.Stop();
            _logger.LogInformation("⏱️ [PO - Step 3] Response Parsing: {ElapsedMs}ms", parseStopwatch.ElapsedMilliseconds);

            totalStopwatch.Stop();
            _logger.LogInformation(
                "✅ [PO EXTRACTION COMPLETE] Total: {TotalMs}ms (ImagePrep: {ImageMs}ms, Vision: {VisionMs}ms, Parse: {ParseMs}ms) - PO: {PONumber}, Amount: {TotalAmount}, Items: {ItemCount}, Flagged: {Flagged}, CorrelationId: {CorrelationId}",
                totalStopwatch.ElapsedMilliseconds, imageStopwatch.ElapsedMilliseconds, 
                visionStopwatch.ElapsedMilliseconds, parseStopwatch.ElapsedMilliseconds,
                poData.PONumber, poData.TotalAmount, poData.LineItems.Count, poData.IsFlaggedForReview, correlationId);

            return poData;
        }
        catch (Exception ex)
        {
            totalStopwatch.Stop();
            _logger.LogError(
                ex,
                "❌ [PO EXTRACTION FAILED] Total: {TotalMs}ms, URL: {BlobUrl}, CorrelationId: {CorrelationId}",
                totalStopwatch.ElapsedMilliseconds, blobUrl, correlationId);
            throw;
        }
    }

    private POData ParsePOResponse(string content)
    {
        try
        {
            var jsonContent = CleanJsonResponse(content);
            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };

            var parsed = JsonSerializer.Deserialize<PODataResponse>(jsonContent, options);
            
            if (parsed == null)
            {
                throw new InvalidOperationException("Failed to parse PO response");
            }

            var poData = new POData
            {
                PONumber = parsed.PONumber ?? string.Empty,
                // CHANGE: Added mapping for all new PO fields
                POType = parsed.PoType ?? string.Empty,
                AgencyCode = parsed.AgencyCode ?? string.Empty,
                AgencyName = parsed.AgencyName ?? string.Empty,
                AgencyAddress = parsed.AgencyAddress ?? string.Empty,
                VendorName = parsed.VendorName ?? string.Empty,
                VendorCode = parsed.VendorCode ?? string.Empty,
                VendorAddress = parsed.VendorAddress ?? string.Empty,
                BuyerName = parsed.BuyerName ?? string.Empty,
                PurchasingOrg = parsed.PurchasingOrg ?? string.Empty,
                StateName = parsed.StateName ?? string.Empty,
                StateCode = parsed.StateCode ?? string.Empty,
                GSTNumber = parsed.GstNumber ?? string.Empty,
                GSTPercentage = parsed.GstPercentage,
                HSNSACCode = parsed.HsnSacCode ?? string.Empty,
                DeliveryTerms = parsed.DeliveryTerms ?? string.Empty,
                PaymentTerms = parsed.PaymentTerms ?? string.Empty,
                PODate = parsed.PODate ?? DateTime.Now,
                TotalAmount = parsed.TotalAmount,
                LineItems = parsed.LineItems?.Select(li => new POLineItem
                {
                    ItemCode = li.ItemCode ?? string.Empty,
                    Description = li.Description ?? string.Empty,
                    Quantity = li.Quantity,
                    UnitPrice = li.UnitPrice,
                    LineTotal = li.LineTotal,
                    // CHANGE: Added new line item field mappings
                    Plant = li.Plant ?? string.Empty,
                    TaxCode = li.TaxCode ?? string.Empty,
                    Currency = li.Currency ?? string.Empty,
                    HSNSACCode = li.HsnSacCode ?? string.Empty
                }).ToList() ?? new List<POLineItem>(),
                FieldConfidences = new Dictionary<string, double>
                {
                    ["Overall"] = parsed.Confidence
                },
                IsFlaggedForReview = parsed.Confidence < CONFIDENCE_THRESHOLD
            };

            return poData;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse PO response: {Content}", content);
            return new POData
            {
                FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                IsFlaggedForReview = true
            };
        }
    }

    // CHANGE: Added all new fields to PODataResponse to match expanded POData DTO
    private class PODataResponse
    {
        public string? PONumber { get; set; }
        public string? PoType { get; set; }
        public string? AgencyCode { get; set; }
        public string? AgencyName { get; set; }
        public string? AgencyAddress { get; set; }
        public string? VendorName { get; set; }
        public string? VendorCode { get; set; }
        public string? VendorAddress { get; set; }
        public string? BuyerName { get; set; }
        public string? PurchasingOrg { get; set; }
        public string? StateName { get; set; }
        public string? StateCode { get; set; }
        public string? GstNumber { get; set; }
        public decimal GstPercentage { get; set; }
        public string? HsnSacCode { get; set; }
        public string? DeliveryTerms { get; set; }
        public string? PaymentTerms { get; set; }
        public DateTime? PODate { get; set; }
        public decimal TotalAmount { get; set; }
        public List<POLineItemResponse>? LineItems { get; set; }
        public double Confidence { get; set; }
    }

    // CHANGE: Added Plant, TaxCode, Currency, HsnSacCode to POLineItemResponse
    private class POLineItemResponse
    {
        public string? ItemCode { get; set; }
        public string? Description { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal LineTotal { get; set; }
        public string? Plant { get; set; }
        public string? TaxCode { get; set; }
        public string? Currency { get; set; }
        public string? HsnSacCode { get; set; }
    }

    /// <summary>
    /// Extracts structured data from an Invoice document.
    /// Uses Azure Document Intelligence for PDFs/Word docs, GPT-4 Vision for images.
    /// Extracts all invoice fields including line items, GST details, and amounts.
    /// </summary>
    /// <param name="blobUrl">The blob URL of the invoice document</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>InvoiceData containing all extracted invoice information</returns>
    /// <exception cref="Exception">Thrown when extraction fails</exception>
    public async Task<InvoiceData> ExtractInvoiceAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        var totalStopwatch = System.Diagnostics.Stopwatch.StartNew();
        
        try
        {
            _logger.LogInformation(
                "🔍 [INVOICE EXTRACTION START] URL: {BlobUrl}, CorrelationId: {CorrelationId}",
                blobUrl, correlationId);

            // CHANGE: Switched from direct Document Intelligence to hybrid approach (Doc Intelligence extracts text → OpenAI analyzes text)
            // For document files (PDF, Word), use Azure Document Intelligence to extract text, then OpenAI to analyze
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("📄 [INVOICE] Document file detected - using hybrid extraction (Document Intelligence + OpenAI)");
                
                // ============================================
                // STEP 1: Generate SAS URL
                // ============================================
                _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                _logger.LogInformation("STEP 1: Generate SAS URL");
                _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                _logger.LogInformation("� INPUT: Blob URL = {BlobUrl}", blobUrl);
                
                var sasStopwatch = System.Diagnostics.Stopwatch.StartNew();
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                sasStopwatch.Stop();
                
                _logger.LogInformation("📤 OUTPUT: SAS URL = {SasUrl}", sasUrl);
                _logger.LogInformation("⏱️ TIME TAKEN: {ElapsedMs}ms", sasStopwatch.ElapsedMilliseconds);
                _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
                
                try
                {
                    // ============================================
                    // STEP 2: Extract Text using Document Intelligence
                    // ============================================
                    _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                    _logger.LogInformation("STEP 2: Document Intelligence Text Extraction");
                    _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                    _logger.LogInformation("📥 INPUT: Document URI = {DocumentUri}", sasUrl);
                    
                    var textExtractionStopwatch = System.Diagnostics.Stopwatch.StartNew();
                    var extractedText = await ExtractTextFromPdfAsync(new Uri(sasUrl), cancellationToken);
                    textExtractionStopwatch.Stop();
                    
                    _logger.LogInformation("📤 OUTPUT: Extracted Text ({TextLength} characters):", extractedText?.Length ?? 0);
                    _logger.LogInformation("─────────────────────────────────────────");
                    _logger.LogInformation("{ExtractedText}", extractedText ?? "[NULL]");
                    _logger.LogInformation("─────────────────────────────────────────");
                    _logger.LogInformation("⏱️ TIME TAKEN: {ElapsedMs}ms", textExtractionStopwatch.ElapsedMilliseconds);
                    _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
                    
                    // ============================================
                    // STEP 3: Analyze Text with OpenAI
                    // ============================================
                    _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                    _logger.LogInformation("STEP 3: OpenAI Text Analysis");
                    _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                    _logger.LogInformation("📥 INPUT: Extracted Text ({TextLength} characters)", extractedText?.Length ?? 0);
                    _logger.LogInformation("📥 INPUT: Deployment Name = {DeploymentName}", _deploymentName);
                    
                    var openAIStopwatch = System.Diagnostics.Stopwatch.StartNew();
                    var result = await AnalyzeInvoiceTextAsync(extractedText, cancellationToken);
                    openAIStopwatch.Stop();
                    
                    _logger.LogInformation("� OUTPUT: Structured Invoice Data:");
                    _logger.LogInformation("─────────────────────────────────────────");
                    _logger.LogInformation("  Invoice Number: {InvoiceNumber}", result.InvoiceNumber);
                    _logger.LogInformation("  Vendor Name: {VendorName}", result.VendorName);
                    _logger.LogInformation("  Vendor Code: {VendorCode}", result.VendorCode);
                    _logger.LogInformation("  Invoice Date: {InvoiceDate}", result.InvoiceDate);
                    _logger.LogInformation("  Agency Name: {AgencyName}", result.AgencyName);
                    _logger.LogInformation("  Agency Code: {AgencyCode}", result.AgencyCode);
                    _logger.LogInformation("  Agency Address: {AgencyAddress}", result.AgencyAddress);
                    _logger.LogInformation("  Billing Name: {BillingName}", result.BillingName);
                    _logger.LogInformation("  Billing Address: {BillingAddress}", result.BillingAddress);
                    _logger.LogInformation("  State: {StateName} ({StateCode})", result.StateName, result.StateCode);
                    _logger.LogInformation("  GST Number: {GSTNumber}", result.GSTNumber);
                    _logger.LogInformation("  GST Percentage: {GSTPercentage}%", result.GSTPercentage);
                    _logger.LogInformation("  HSN/SAC Code: {HSNSACCode}", result.HSNSACCode);
                    _logger.LogInformation("  PO Number: {PONumber}", result.PONumber);
                    _logger.LogInformation("  Sub Total: ₹{SubTotal}", result.SubTotal);
                    _logger.LogInformation("  Tax Amount: ₹{TaxAmount}", result.TaxAmount);
                    _logger.LogInformation("  Total Amount: ₹{TotalAmount}", result.TotalAmount);
                    _logger.LogInformation("  Line Items: {LineItemCount} items", result.LineItems?.Count ?? 0);
                    if (result.LineItems?.Any() == true)
                    {
                        foreach (var item in result.LineItems)
                        {
                            _logger.LogInformation("    - {Description} | Qty: {Qty} | Unit Price: ₹{UnitPrice} | Total: ₹{LineTotal}", 
                                item.Description, item.Quantity, item.UnitPrice, item.LineTotal);
                        }
                    }
                    _logger.LogInformation("  Confidence: {Confidence}", result.FieldConfidences?.GetValueOrDefault("Overall", 0));
                    _logger.LogInformation("  Flagged for Review: {Flagged}", result.IsFlaggedForReview);
                    _logger.LogInformation("─────────────────────────────────────────");
                    _logger.LogInformation("⏱️ TIME TAKEN: {ElapsedMs}ms", openAIStopwatch.ElapsedMilliseconds);
                    _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
                    
                    totalStopwatch.Stop();
                    _logger.LogInformation(
                        "✅ [INVOICE EXTRACTION COMPLETE] Total: {TotalMs}ms (SAS: {SasMs}ms, DocIntel: {DocIntelMs}ms, OpenAI: {OpenAIMs}ms)",
                        totalStopwatch.ElapsedMilliseconds, sasStopwatch.ElapsedMilliseconds, 
                        textExtractionStopwatch.ElapsedMilliseconds, openAIStopwatch.ElapsedMilliseconds);
                    return result;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "❌ [INVOICE] Error in hybrid extraction, falling back to Document Intelligence only");
                    var fallbackStopwatch = System.Diagnostics.Stopwatch.StartNew();
                    var result = await _documentIntelligenceService.ExtractInvoiceAsync(new Uri(sasUrl), cancellationToken);
                    fallbackStopwatch.Stop();
                    _logger.LogInformation("⏱️ [INVOICE - Fallback] Document Intelligence Only: {ElapsedMs}ms", fallbackStopwatch.ElapsedMilliseconds);
                    totalStopwatch.Stop();
                    _logger.LogInformation("✅ [INVOICE EXTRACTION COMPLETE - Fallback] Total: {TotalMs}ms", totalStopwatch.ElapsedMilliseconds);
                    return result;
                }
            }

            // For images, use GPT-4 Vision
            _logger.LogInformation("🖼️ [INVOICE] Image file detected - using GPT-4 Vision");
            
            // ============================================
            // STEP 1: Prepare Image Data
            // ============================================
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            _logger.LogInformation("STEP 1: Image Preparation");
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            _logger.LogInformation("📥 INPUT: Blob URL = {BlobUrl}", blobUrl);
            
            var imageStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var imageData = await PrepareImageDataAsync(blobUrl);
            imageStopwatch.Stop();
            
            _logger.LogInformation("📤 OUTPUT: Image Data Length = {ImageDataLength} characters", imageData?.Length ?? 0);
            _logger.LogInformation("📤 OUTPUT: Format = {Format}", imageData?.StartsWith("data:image") == true ? "Base64 Data URL" : "Unknown");
            _logger.LogInformation("📤 OUTPUT: Image Data Preview (first 200 chars): {ImageDataPreview}...", 
                imageData?.Substring(0, Math.Min(200, imageData?.Length ?? 0)));
            _logger.LogInformation("⏱️ TIME TAKEN: {ElapsedMs}ms", imageStopwatch.ElapsedMilliseconds);
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
            
            if (imageData == null)
            {
                _logger.LogWarning("⚠️ [INVOICE] Could not prepare image data for extraction");
                return new InvoiceData
                {
                    FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                    IsFlaggedForReview = true
                };
            }

            // ============================================
            // STEP 2: GPT-4 Vision API Call
            // ============================================
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            _logger.LogInformation("STEP 2: GPT-4 Vision API Call");
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            _logger.LogInformation("📥 INPUT: Deployment Name = {DeploymentName}", _deploymentName);
            _logger.LogInformation("📥 INPUT: Image Data Length = {ImageDataLength} characters", imageData?.Length ?? 0);
            _logger.LogInformation("📥 INPUT: System Prompt = Invoice extraction with step-by-step instructions");
            
            var visionStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    new ChatRequestSystemMessage(@"You are an Invoice data extraction specialist. Azure Document Intelligence has already parsed the document text. Your task is to analyze this pre-extracted text and structure it into the required JSON format.

EXTRACTION RULES:
1. Extract ONLY information present in the provided text
2. Do NOT guess or invent values
3. Normalize dates to YYYY-MM-DD format
4. Remove currency symbols (₹, INR, Rs.) and commas from amounts
5. For GSTIN: extract the 15-character code, derive state code (first 2 digits) and state name
6. If multiple totals exist, use the final/largest amount
7. Return empty string for missing text fields, 0 for missing numeric fields

KEY FIELDS TO EXTRACT:
- Invoice Number (look for: Invoice No, Inv No, Bill No, Tax Invoice No)
- Invoice Date (normalize to YYYY-MM-DD)
- Vendor Name & Code
- Agency/Customer Name, Address & Code
- Billing Name & Address
- GST Number (15 chars), State Code (first 2 digits), State Name
- HSN/SAC Code
- PO Number (look for: PO No, Purchase Order, PO Ref)
- Sub Total, Tax Amount, Total Amount
- GST Percentage (common: 5%, 12%, 18%, 28%)
- Line Items: description, quantity, unit_price, amount, hsn_sac_code, gst_percentage

STATE CODE MAPPING:
07=Delhi, 19=West Bengal, 24=Gujarat, 27=Maharashtra, 29=Karnataka, 33=Tamil Nadu

VALIDATION:
- Verify: Sub Total + Tax Amount ≈ Total Amount
- If mismatch, use explicit totals from invoice summary

CONFIDENCE SCORING (0.0-1.0):
0.9-1.0: All key fields extracted clearly
0.75-0.9: Minor fields missing
0.6-0.75: Some important fields missing
0.4-0.6: Partial extraction only
<0.4: Poor quality data

OUTPUT FORMAT (JSON only, no explanations):
{
  ""invoice_number"": """",
  ""invoice_date"": ""YYYY-MM-DD"",
  ""agency_name"": """",
  ""agency_address"": """",
  ""agency_code"": """",
  ""billing_name"": """",
  ""billing_address"": """",
  ""vendor_name"": """",
  ""vendor_code"": """",
  ""state_name"": """",
  ""state_code"": """",
  ""gst_number"": """",
  ""gst_percentage"": 0,
  ""hsn_sac_code"": """",
  ""po_number"": """",
  ""sub_total"": 0,
  ""tax_amount"": 0,
  ""total_amount"": 0,
  ""line_items"": [
    {
      ""description"": """",
      ""quantity"": 0,
      ""unit_price"": 0,
      ""amount"": 0,
      ""hsn_sac_code"": """",
      ""gst_percentage"": 0
    }
  ],
  ""confidence"": 0.0
}"),

//                     (@"You are an Invoice data extraction expert with exceptional OCR capabilities.
// Carefully analyze the provided invoice document image and extract ALL visible information with high accuracy.

// CRITICAL INSTRUCTIONS:
// 1. Look for fields labeled 'Total', 'Tot Inv. Amt', 'Total Amount', 'Grand Total', 'Invoice Total', or similar
// 2. Extract the EXACT numeric values you see, including decimals
// 3. For invoice numbers, look for fields labeled 'Invoice No', 'Invoice Number', 'Bill No', etc.
// 4. Pay special attention to tables and line items
// 5. If you see multiple totals (like 'Total' and 'Tot Inv. Amt'), use the larger/final total amount

// Respond ONLY with a JSON object in this exact format:
// {
//   ""invoiceNumber"": ""string"",
//   ""vendorName"": ""string"",
//   ""invoiceDate"": ""YYYY-MM-DD"",
//   ""subTotal"": 0.00,
//   ""taxAmount"": 0.00,
//   ""totalAmount"": 0.00,
//   ""lineItems"": [
//     {
//       ""itemCode"": ""string"",
//       ""description"": ""string"",
//       ""quantity"": 0,
//       ""unitPrice"": 0.00,
//       ""lineTotal"": 0.00
//     }
//   ],
//   ""confidence"": 0.0
// }

// Where confidence is your overall confidence in the extraction (0.0 to 1.0).
// Extract EVERY field you can see. Do not leave fields empty if data is visible in the image."),
                    new ChatRequestUserMessage(
                        new ChatMessageContentItem[]
                        {
                            new ChatMessageTextContentItem("Please extract ALL data from this invoice image. Be thorough and accurate."),
                            CreateImageContentItem(imageData)
                        })
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(
                chatCompletionsOptions, 
                cancellationToken);
            visionStopwatch.Stop();
            
            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("📤 OUTPUT: Raw API Response ({ResponseLength} characters):", content?.Length ?? 0);
            _logger.LogInformation("─────────────────────────────────────────");
            _logger.LogInformation("{RawResponse}", content ?? "[NULL]");
            _logger.LogInformation("─────────────────────────────────────────");
            _logger.LogInformation("⏱️ TIME TAKEN: {ElapsedMs}ms", visionStopwatch.ElapsedMilliseconds);
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

            // ============================================
            // STEP 3: Parse Response
            // ============================================
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            _logger.LogInformation("STEP 3: Parse Response");
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            _logger.LogInformation("📥 INPUT: Raw JSON Response ({ResponseLength} characters)", content?.Length ?? 0);
            
            var parseStopwatch = System.Diagnostics.Stopwatch.StartNew();
            var invoiceData = ParseInvoiceResponse(content);
            parseStopwatch.Stop();
            
            _logger.LogInformation("📤 OUTPUT: Structured Invoice Data:");
            _logger.LogInformation("─────────────────────────────────────────");
            _logger.LogInformation("  Invoice Number: {InvoiceNumber}", invoiceData.InvoiceNumber);
            _logger.LogInformation("  Vendor Name: {VendorName}", invoiceData.VendorName);
            _logger.LogInformation("  Vendor Code: {VendorCode}", invoiceData.VendorCode);
            _logger.LogInformation("  Invoice Date: {InvoiceDate}", invoiceData.InvoiceDate);
            _logger.LogInformation("  Agency Name: {AgencyName}", invoiceData.AgencyName);
            _logger.LogInformation("  Agency Code: {AgencyCode}", invoiceData.AgencyCode);
            _logger.LogInformation("  Agency Address: {AgencyAddress}", invoiceData.AgencyAddress);
            _logger.LogInformation("  Billing Name: {BillingName}", invoiceData.BillingName);
            _logger.LogInformation("  Billing Address: {BillingAddress}", invoiceData.BillingAddress);
            _logger.LogInformation("  State: {StateName} ({StateCode})", invoiceData.StateName, invoiceData.StateCode);
            _logger.LogInformation("  GST Number: {GSTNumber}", invoiceData.GSTNumber);
            _logger.LogInformation("  GST Percentage: {GSTPercentage}%", invoiceData.GSTPercentage);
            _logger.LogInformation("  HSN/SAC Code: {HSNSACCode}", invoiceData.HSNSACCode);
            _logger.LogInformation("  PO Number: {PONumber}", invoiceData.PONumber);
            _logger.LogInformation("  Sub Total: ₹{SubTotal}", invoiceData.SubTotal);
            _logger.LogInformation("  Tax Amount: ₹{TaxAmount}", invoiceData.TaxAmount);
            _logger.LogInformation("  Total Amount: ₹{TotalAmount}", invoiceData.TotalAmount);
            _logger.LogInformation("  Line Items: {LineItemCount} items", invoiceData.LineItems?.Count ?? 0);
            if (invoiceData.LineItems?.Any() == true)
            {
                foreach (var item in invoiceData.LineItems)
                {
                    _logger.LogInformation("    - {Description} | Qty: {Qty} | Unit Price: ₹{UnitPrice} | Total: ₹{LineTotal}", 
                        item.Description, item.Quantity, item.UnitPrice, item.LineTotal);
                }
            }
            _logger.LogInformation("  Confidence: {Confidence}", invoiceData.FieldConfidences?.GetValueOrDefault("Overall", 0));
            _logger.LogInformation("  Flagged for Review: {Flagged}", invoiceData.IsFlaggedForReview);
            _logger.LogInformation("─────────────────────────────────────────");
            _logger.LogInformation("⏱️ TIME TAKEN: {ElapsedMs}ms", parseStopwatch.ElapsedMilliseconds);
            _logger.LogInformation("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

            totalStopwatch.Stop();
            _logger.LogInformation(
                "✅ [INVOICE EXTRACTION COMPLETE] Total: {TotalMs}ms (ImagePrep: {ImageMs}ms, Vision: {VisionMs}ms, Parse: {ParseMs}ms), CorrelationId: {CorrelationId}",
                totalStopwatch.ElapsedMilliseconds, imageStopwatch.ElapsedMilliseconds, 
                visionStopwatch.ElapsedMilliseconds, parseStopwatch.ElapsedMilliseconds, correlationId);

            return invoiceData;
        }
        catch (Exception ex)
        {
            totalStopwatch.Stop();
            _logger.LogError(
                ex,
                "❌ [INVOICE EXTRACTION FAILED] Total: {TotalMs}ms, URL: {BlobUrl}, CorrelationId: {CorrelationId}",
                totalStopwatch.ElapsedMilliseconds, blobUrl, correlationId);
            throw;
        }
    }

    /// <summary>
    /// Extracts structured data from an Invoice document with filename context.
    /// Wrapper method that calls ExtractInvoiceAsync with additional logging.
    /// </summary>
    /// <param name="blobUrl">The blob URL of the Invoice document</param>
    /// <param name="fileName">Original filename for context</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>InvoiceData containing all extracted invoice information</returns>
    public async Task<InvoiceData> ExtractInvoiceDataAsync(string blobUrl, string fileName, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting invoice data extraction for file: {FileName}, URL: {BlobUrl}", fileName, blobUrl);
        return await ExtractInvoiceAsync(blobUrl, cancellationToken);
    }

    private InvoiceData ParseInvoiceResponse(string content)
    {
        try
        {
            var jsonContent = CleanJsonResponse(content);
            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };

            var parsed = JsonSerializer.Deserialize<InvoiceDataResponse>(jsonContent, options);
            
            if (parsed == null)
            {
                throw new InvalidOperationException("Failed to parse Invoice response");
            }

            // CHANGE: Added mapping for all new fields (Agency, Billing, GST, HSN, PO, State, VendorCode)
            var invoiceData = new InvoiceData
            {
                InvoiceNumber = parsed.InvoiceNumber ?? string.Empty,
                VendorName = parsed.VendorName ?? string.Empty,
                VendorCode = parsed.VendorCode ?? string.Empty,
                InvoiceDate = DateTime.TryParse(parsed.InvoiceDate, out var parsedDate) ? parsedDate : DateTime.Now,
                AgencyName = parsed.AgencyName ?? string.Empty,
                AgencyAddress = parsed.AgencyAddress ?? string.Empty,
                AgencyCode = parsed.AgencyCode ?? string.Empty,
                BillingName = parsed.BillingName ?? string.Empty,
                BillingAddress = parsed.BillingAddress ?? string.Empty,
                StateName = parsed.StateName ?? string.Empty,
                StateCode = parsed.StateCode ?? string.Empty,
                GSTNumber = parsed.GstNumber ?? string.Empty,
                GSTPercentage = parsed.GstPercentage,
                HSNSACCode = parsed.HsnSacCode ?? string.Empty,
                PONumber = parsed.PoNumber ?? string.Empty,
                SubTotal = parsed.SubTotal,
                TaxAmount = parsed.TaxAmount,
                TotalAmount = parsed.TotalAmount,
                LineItems = parsed.LineItems?.Select(li => new InvoiceLineItem
                {
                    ItemCode = li.ItemCode ?? string.Empty,
                    Description = li.Description ?? string.Empty,
                    Quantity = li.Quantity,
                    UnitPrice = li.UnitPrice,
                    LineTotal = li.LineTotal
                }).ToList() ?? new List<InvoiceLineItem>(),
                FieldConfidences = new Dictionary<string, double>
                {
                    ["Overall"] = parsed.Confidence
                },
                IsFlaggedForReview = parsed.Confidence < CONFIDENCE_THRESHOLD
            };

            return invoiceData;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse Invoice response: {Content}", content);
            return new InvoiceData
            {
                FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                IsFlaggedForReview = true
            };
        }
    }

    // CHANGE: Added all missing fields to match InvoiceData DTO for complete extraction
    private class InvoiceDataResponse
    {
        public string? InvoiceNumber { get; set; }
        public string? VendorName { get; set; }
        public string? VendorCode { get; set; }
        public string? InvoiceDate { get; set; }
        public string? AgencyName { get; set; }
        public string? AgencyAddress { get; set; }
        public string? AgencyCode { get; set; }
        public string? BillingName { get; set; }
        public string? BillingAddress { get; set; }
        public string? StateName { get; set; }
        public string? StateCode { get; set; }
        public string? GstNumber { get; set; }
        public decimal GstPercentage { get; set; }
        public string? HsnSacCode { get; set; }
        public string? PoNumber { get; set; }
        public decimal SubTotal { get; set; }
        public decimal TaxAmount { get; set; }
        public decimal TotalAmount { get; set; }
        public List<InvoiceLineItemResponse>? LineItems { get; set; }
        public double Confidence { get; set; }
    }

    private class InvoiceLineItemResponse
    {
        public string? ItemCode { get; set; }
        public string? Description { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal LineTotal { get; set; }
    }

    /// <summary>
    /// Extracts structured data from a Cost Summary document.
    /// Uses Azure Document Intelligence for PDFs/Word docs, GPT-4 Vision for images.
    /// Extracts campaign details, cost breakdowns, and totals.
    /// </summary>
    /// <param name="blobUrl">The blob URL of the cost summary document</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>CostSummaryData containing all extracted cost summary information</returns>
    /// <exception cref="Exception">Thrown when extraction fails</exception>
    public async Task<CostSummaryData> ExtractCostSummaryAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        
        try
        {
            _logger.LogInformation(
                "Starting Cost Summary extraction for URL: {BlobUrl}. CorrelationId: {CorrelationId}",
                blobUrl, correlationId);

            // For document files (PDF, Word), use Azure Document Intelligence with generic document model
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected - using Azure Document Intelligence for extraction");
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                
                // Use Document Intelligence to extract text and structure
                // For Cost Summary, we'll use GPT-4 to analyze the extracted text
                try
                {
                    var extractedText = await ExtractTextFromPdfAsync(new Uri(sasUrl), cancellationToken);
                    
                    // Now use GPT-4 to analyze the extracted text
                    var result = await AnalyzeCostSummaryTextAsync(extractedText, cancellationToken);
                    _logger.LogInformation(
                        "Cost Summary extraction completed. Total: {Total}",
                        result.TotalCost);
                    return result;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error extracting Cost Summary with Document Intelligence, returning placeholder");
                    return CreatePlaceholderCostSummary();
                }
            }

            // For images, use GPT-4 Vision
            var imageData = await PrepareImageDataAsync(blobUrl);
            
            if (imageData == null)
            {
                _logger.LogWarning("Could not prepare image data for cost summary extraction");
                return CreatePlaceholderCostSummary();
            }

            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    // CHANGE: Expanded Cost Summary image prompt to extract all required fields
                    new ChatRequestSystemMessage(@"You are a Cost Summary data extraction expert with exceptional OCR capabilities.
Carefully analyze the provided cost summary document image and extract ALL visible information with high accuracy.

REQUIRED FIELDS TO EXTRACT:
1. Campaign Name - Activity/campaign title
2. State - State name
3. Place of Supply - Look for: 'Place of Supply', 'State'
4. Campaign Start Date - Start date (format: YYYY-MM-DD)
5. Campaign End Date - End date (format: YYYY-MM-DD)
6. Number of Days - Look for 'Days' column, text like '90 day'. Use MAXIMUM days value.
7. Number of Teams - Look for 'Team', 'No of Teams', text like 'By 2 Team'
8. Number of Activations - Look for 'Activations'
9. Total Cost - Final total including tax
10. Cost Breakdowns - EVERY line item with ALL details

FOR EACH COST BREAKDOWN ITEM:
- category: Item name (e.g., 'Vehicle Branding', 'Promoter')
- elementName: Same as category
- amount: Total column value
- quantity: Qty column value
- unit: Unit of measurement
- isFixedCost: true if 'One Time' in Days column
- isVariableCost: true if numeric Days (78, 90)

CRITICAL: Do NOT include tax rows (CGST, SGST) as breakdown items.

Respond ONLY with a JSON object in this exact format:
{
  ""campaignName"": ""string"",
  ""state"": ""string"",
  ""placeOfSupply"": ""string"",
  ""campaignStartDate"": ""YYYY-MM-DD"",
  ""campaignEndDate"": ""YYYY-MM-DD"",
  ""numberOfDays"": 0,
  ""numberOfTeams"": 0,
  ""numberOfActivations"": 0,
  ""totalCost"": 0.00,
  ""costBreakdowns"": [
    {
      ""category"": ""string"",
      ""elementName"": ""string"",
      ""amount"": 0.00,
      ""quantity"": 0,
      ""unit"": ""string"",
      ""isFixedCost"": false,
      ""isVariableCost"": false
    }
  ],
  ""confidence"": 0.0
}

Extract EVERY field you can see. Do not leave fields empty if data is visible."),
                    new ChatRequestUserMessage(
                        new ChatMessageContentItem[]
                        {
                            new ChatMessageTextContentItem("Please extract ALL data from this Cost Summary image. Be thorough and accurate."),
                            CreateImageContentItem(imageData)
                        })
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(
                chatCompletionsOptions, 
                cancellationToken);

            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received Cost Summary extraction response: {Response}", content);

            var costSummaryData = ParseCostSummaryResponse(content);

            _logger.LogInformation(
                "Cost Summary extraction completed. Campaign: {Campaign}, Total Cost: {TotalCost}, Cost Breakdowns: {BreakdownCount}, Flagged: {Flagged}. CorrelationId: {CorrelationId}",
                costSummaryData.CampaignName, costSummaryData.TotalCost, costSummaryData.CostBreakdowns.Count, costSummaryData.IsFlaggedForReview, correlationId);

            return costSummaryData;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error extracting Cost Summary data from URL: {BlobUrl}. CorrelationId: {CorrelationId}",
                blobUrl, correlationId);
            throw;
        }
    }

    private CostSummaryData ParseCostSummaryResponse(string content)
    {
        try
        {
            var jsonContent = CleanJsonResponse(content);
            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };

            var parsed = JsonSerializer.Deserialize<CostSummaryDataResponse>(jsonContent, options);
            
            if (parsed == null)
            {
                throw new InvalidOperationException("Failed to parse Cost Summary response");
            }

            // CHANGE: Added mapping for all new Cost Summary fields (PlaceOfSupply, NumberOfDays, NumberOfTeams, NumberOfActivations, and breakdown details)
            var costSummaryData = new CostSummaryData
            {
                CampaignName = parsed.CampaignName ?? string.Empty,
                State = parsed.State ?? string.Empty,
                PlaceOfSupply = parsed.PlaceOfSupply,
                CampaignStartDate = parsed.CampaignStartDate ?? DateTime.Now,
                CampaignEndDate = parsed.CampaignEndDate ?? DateTime.Now,
                TotalCost = parsed.TotalCost,
                NumberOfDays = parsed.NumberOfDays,
                NumberOfTeams = parsed.NumberOfTeams,
                NumberOfActivations = parsed.NumberOfActivations,
                CostBreakdowns = parsed.CostBreakdowns?.Select(cb => new CostBreakdown
                {
                    Category = cb.Category ?? string.Empty,
                    ElementName = cb.ElementName,
                    Amount = cb.Amount,
                    Quantity = cb.Quantity,
                    Unit = cb.Unit,
                    IsFixedCost = cb.IsFixedCost,
                    IsVariableCost = cb.IsVariableCost
                }).ToList() ?? new List<CostBreakdown>(),
                FieldConfidences = new Dictionary<string, double>
                {
                    ["Overall"] = parsed.Confidence
                },
                IsFlaggedForReview = parsed.Confidence < CONFIDENCE_THRESHOLD
            };

            return costSummaryData;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse Cost Summary response: {Content}", content);
            return new CostSummaryData
            {
                FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                IsFlaggedForReview = true
            };
        }
    }

    // CHANGE: Added all missing fields to CostSummaryDataResponse (PlaceOfSupply, NumberOfDays, NumberOfTeams, NumberOfActivations)
    private class CostSummaryDataResponse
    {
        public string? CampaignName { get; set; }
        public string? State { get; set; }
        public string? PlaceOfSupply { get; set; }
        public DateTime? CampaignStartDate { get; set; }
        public DateTime? CampaignEndDate { get; set; }
        public decimal TotalCost { get; set; }
        public int? NumberOfDays { get; set; }
        public int? NumberOfTeams { get; set; }
        public int? NumberOfActivations { get; set; }
        public List<CostBreakdownResponse>? CostBreakdowns { get; set; }
        public double Confidence { get; set; }
    }

    // CHANGE: Added ElementName, Quantity, Unit, IsFixedCost, IsVariableCost to CostBreakdownResponse
    private class CostBreakdownResponse
    {
        public string? Category { get; set; }
        public string? ElementName { get; set; }
        public decimal Amount { get; set; }
        public int? Quantity { get; set; }
        public string? Unit { get; set; }
        public bool IsFixedCost { get; set; }
        public bool IsVariableCost { get; set; }
    }

    /// <summary>
    /// Extracts EXIF metadata from a photo including timestamp, GPS location, and device information.
    /// Also performs AI-based content analysis to detect blue t-shirt persons and Bajaj vehicles.
    /// </summary>
    /// <param name="blobUrl">The blob URL of the photo</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>PhotoMetadata containing EXIF data and AI-detected content features</returns>
    public async Task<PhotoMetadata> ExtractPhotoMetadataAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        
        try
        {
            _logger.LogInformation(
                "Starting photo metadata extraction for URL: {BlobUrl}. CorrelationId: {CorrelationId}",
                blobUrl, correlationId);

            // Download the image using file storage service (handles authentication)
            var imageBytes = await _fileStorageService.GetFileBytesAsync(blobUrl);
            
            using var stream = new MemoryStream(imageBytes);
            var directories = ImageMetadataReader.ReadMetadata(stream);

            var metadata = new PhotoMetadata();
            var fieldConfidences = new Dictionary<string, double>();

            // Compute perceptual hash for duplicate detection
            try
            {
                using var hashStream = new MemoryStream(imageBytes);
                var perceptualHash = await _perceptualHashService.ComputeHashAsync(hashStream, cancellationToken);
                if (perceptualHash != null)
                {
                    metadata.PerceptualHash = perceptualHash;
                    _logger.LogDebug("Computed perceptual hash {Hash} for {BlobUrl}", perceptualHash, blobUrl);
                }
            }
            catch (Exception hashEx)
            {
                _logger.LogWarning(hashEx, "Failed to compute perceptual hash for {BlobUrl}, continuing without it", blobUrl);
            }

            // Extract EXIF data
            var exifSubIfdDirectory = directories.OfType<ExifSubIfdDirectory>().FirstOrDefault();
            var exifIfd0Directory = directories.OfType<ExifIfd0Directory>().FirstOrDefault();
            var gpsDirectory = directories.OfType<GpsDirectory>().FirstOrDefault();

            // Extract timestamp
            if (exifSubIfdDirectory?.TryGetDateTime(ExifDirectoryBase.TagDateTimeOriginal, out var dateTime) == true)
            {
                metadata.Timestamp = dateTime;
                fieldConfidences["Timestamp"] = 1.0; // EXIF data is reliable
            }
            else if (exifIfd0Directory?.TryGetDateTime(ExifDirectoryBase.TagDateTime, out dateTime) == true)
            {
                metadata.Timestamp = dateTime;
                fieldConfidences["Timestamp"] = 1.0;
            }

            // Extract GPS location
            if (gpsDirectory != null)
            {
                var location = gpsDirectory.GetGeoLocation();
                if (location != null)
                {
                    metadata.Latitude = location.Latitude;
                    metadata.Longitude = location.Longitude;
                    fieldConfidences["Location"] = 1.0;
                }
            }

            // Extract device information
            if (exifIfd0Directory != null)
            {
                metadata.DeviceMake = exifIfd0Directory.GetDescription(ExifDirectoryBase.TagMake);
                metadata.DeviceModel = exifIfd0Directory.GetDescription(ExifDirectoryBase.TagModel);
                
                if (metadata.DeviceMake != null)
                    fieldConfidences["DeviceMake"] = 1.0;
                if (metadata.DeviceModel != null)
                    fieldConfidences["DeviceModel"] = 1.0;
            }

            // Extract image dimensions
            if (exifSubIfdDirectory != null)
            {
                if (exifSubIfdDirectory.TryGetInt32(ExifDirectoryBase.TagExifImageWidth, out var width))
                {
                    metadata.ImageWidth = width;
                    fieldConfidences["ImageWidth"] = 1.0;
                }

                if (exifSubIfdDirectory.TryGetInt32(ExifDirectoryBase.TagExifImageHeight, out var height))
                {
                    metadata.ImageHeight = height;
                    fieldConfidences["ImageHeight"] = 1.0;
                }
            }

            metadata.FieldConfidences = fieldConfidences;

            // CHANGE: Fixed photo Vision analysis - was passing raw base64 instead of proper data URI/SAS URL
            // Must use PrepareImageDataAsync (like Invoice/PO/CostSummary do) to create proper URL for OpenAI
            try
            {
                var imageUrl = await PrepareImageDataAsync(blobUrl);
                if (imageUrl != null)
                {
                    var visionAnalysis = await AnalyzePhotoContentAsync(imageUrl, cancellationToken);
                
                    metadata.HasBlueTshirtPerson = visionAnalysis.HasBlueTshirtPerson;
                    metadata.BlueTshirtPersonCount = visionAnalysis.BlueTshirtPersonCount;
                    metadata.HasBajajVehicle = visionAnalysis.HasBajajVehicle;
                    metadata.Has3WVehicle = visionAnalysis.Has3WVehicle;
                    metadata.BlueTshirtConfidence = visionAnalysis.BlueTshirtConfidence;
                    metadata.VehicleConfidence = visionAnalysis.VehicleConfidence;
                    metadata.PhotoDateFromOverlay = visionAnalysis.PhotoDateFromOverlay;
                    metadata.LocationText = visionAnalysis.LocationText;
                    metadata.HasHumanFace = visionAnalysis.HasHumanFace;
                    metadata.FaceCount = visionAnalysis.FaceCount;
                    metadata.FaceDetectionConfidence = visionAnalysis.FaceDetectionConfidence;
                
                    // Use overlay date if EXIF timestamp is missing
                    if (!metadata.Timestamp.HasValue && !string.IsNullOrEmpty(visionAnalysis.PhotoDateFromOverlay))
                    {
                        if (DateTime.TryParse(visionAnalysis.PhotoDateFromOverlay, out var overlayDate))
                        {
                            metadata.Timestamp = overlayDate;
                            fieldConfidences["Timestamp"] = 0.85;
                        }
                    }
                
                    // Use overlay lat/long if EXIF GPS is missing
                    if (!metadata.Latitude.HasValue && visionAnalysis.OverlayLatitude.HasValue)
                    {
                        metadata.Latitude = visionAnalysis.OverlayLatitude;
                        metadata.Longitude = visionAnalysis.OverlayLongitude;
                        fieldConfidences["Location"] = 0.85;
                    }
                
                    fieldConfidences["BlueTshirt"] = visionAnalysis.BlueTshirtConfidence;
                    fieldConfidences["Vehicle"] = visionAnalysis.VehicleConfidence;
                    metadata.FieldConfidences = fieldConfidences;
                
                    _logger.LogInformation(
                        "Photo Vision analysis completed. BlueTshirt: {HasBlue} (count: {Count}), 3W Vehicle: {Has3W}, OverlayDate: {Date}",
                        metadata.HasBlueTshirtPerson, metadata.BlueTshirtPersonCount, metadata.Has3WVehicle, metadata.PhotoDateFromOverlay);
                }
            }
            catch (Exception visionEx)
            {
                _logger.LogWarning(visionEx, "Vision analysis failed for photo, continuing with EXIF data only");
            }

            // Calculate overall document confidence and flag if below threshold
            var documentConfidence = CalculateDocumentConfidence(fieldConfidences);
            metadata.IsFlaggedForReview = documentConfidence < CONFIDENCE_THRESHOLD;

            _logger.LogInformation(
                "Photo metadata extraction completed. Timestamp: {Timestamp}, Location: {HasLocation}, Confidence: {Confidence}, Flagged: {Flagged}. CorrelationId: {CorrelationId}",
                metadata.Timestamp, metadata.Latitude.HasValue && metadata.Longitude.HasValue, documentConfidence, metadata.IsFlaggedForReview, correlationId);

            return metadata;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error extracting photo metadata from URL: {BlobUrl}. CorrelationId: {CorrelationId}",
                blobUrl, correlationId);
            
            // Return empty metadata with low confidence and flagged for review on error
            return new PhotoMetadata
            {
                FieldConfidences = new Dictionary<string, double>(),
                IsFlaggedForReview = true // Flag for review when extraction fails
            };
        }
    }

    /// <summary>
    /// Analyzes photo content using GPT-4 Vision to detect campaign verification elements.
    /// Detects people wearing blue t-shirts, 3-wheel vehicles, and reads GPS overlay text.
    /// </summary>
    /// <param name="imageData">Base64-encoded image data</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>PhotoVisionResponse containing detected features and confidence scores</returns>
    private async Task<PhotoVisionResponse> AnalyzePhotoContentAsync(string imageData, CancellationToken cancellationToken)
    {
        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are a photo analysis expert for marketing campaign verification in India.

Analyze this photo carefully and detect the following. Be precise and thorough.

WHAT TO DETECT:

1. PERSON WITH BLUE T-SHIRT/SHIRT:
   - Look for any person wearing blue clothing (light blue, dark blue, navy, royal blue)
   - Must be worn by a real person (not on a banner/poster)
   - Count how many people are wearing blue
   - Confidence: 0.9+ if clearly visible, 0.5-0.8 if partially visible

2. 3-WHEEL VEHICLE (Auto-Rickshaw / Cargo Vehicle):
   - Three-wheeled vehicle (auto-rickshaw, Bajaj RE, cargo 3-wheeler)
   - May have Bajaj branding
   - Common in Indian streets
   - Set has3WVehicle=true if ANY 3-wheeler is visible

3. GPS OVERLAY TEXT (if visible at bottom of image):
   - Read the DATE from the overlay (format like '01/04/2025')
   - Read the LAT LONG values
   - Read the LOCATION text (city, state, country)
   - Many campaign photos have a GPS Map Camera overlay with this info

4. HUMAN FACE DETECTION:
   - Detect if any human face is visible in the photo
   - Count the number of distinct human faces
   - This is independent of blue t-shirt detection
   - Confidence: 0.9+ if face clearly visible, 0.5-0.8 if partially visible

Respond ONLY with JSON:
{
  ""hasBlueTshirtPerson"": false,
  ""blueTshirtPersonCount"": 0,
  ""blueTshirtConfidence"": 0.0,
  ""hasBajajVehicle"": false,
  ""has3WVehicle"": false,
  ""vehicleConfidence"": 0.0,
  ""photoDateFromOverlay"": ""YYYY-MM-DD"",
  ""overlayLatitude"": null,
  ""overlayLongitude"": null,
  ""locationText"": ""string"",
  ""hasHumanFace"": false,
  ""faceCount"": 0,
  ""faceDetectionConfidence"": 0.0
}

If GPS overlay is not visible, set photoDateFromOverlay to empty string and lat/long to null."),
                new ChatRequestUserMessage(
                    new ChatMessageContentItem[]
                    {
                        new ChatMessageTextContentItem("Analyze this campaign photo. Detect: 1) People with blue t-shirt (count them), 2) Any 3-wheel vehicle, 3) Read GPS overlay text if visible (date, lat/long, location), 4) Human faces (count them, independent of clothing)."),
                        CreateImageContentItem(imageData)
                    })
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        
        _logger.LogInformation("Received photo vision analysis response: {Response}", content);
        
        var jsonContent = CleanJsonResponse(content);
        var visionResult = JsonSerializer.Deserialize<PhotoVisionResponse>(jsonContent, new JsonSerializerOptions 
        { 
            PropertyNameCaseInsensitive = true 
        });
        
        return visionResult ?? new PhotoVisionResponse();
    }

    // CHANGE: Added PhotoVisionResponse class for Vision API response parsing
    private class PhotoVisionResponse
    {
        public bool HasBlueTshirtPerson { get; set; }
        public int BlueTshirtPersonCount { get; set; }
        public double BlueTshirtConfidence { get; set; }
        public bool HasBajajVehicle { get; set; }
        public bool Has3WVehicle { get; set; }
        public double VehicleConfidence { get; set; }
        public string? PhotoDateFromOverlay { get; set; }
        public double? OverlayLatitude { get; set; }
        public double? OverlayLongitude { get; set; }
        public string? LocationText { get; set; }
        public bool HasHumanFace { get; set; }
        public int FaceCount { get; set; }
        public double FaceDetectionConfidence { get; set; }
    }

    /// <summary>
    /// Calculates the overall confidence score for a document based on field-level confidences
    /// </summary>
    /// <param name="fieldConfidences">Dictionary of field names to confidence scores</param>
    /// <returns>Average confidence score (0.0 to 1.0)</returns>
    public double CalculateDocumentConfidence(Dictionary<string, double> fieldConfidences)
    {
        if (fieldConfidences == null || fieldConfidences.Count == 0)
            return 0.0;

        // Calculate average of all field confidences
        var averageConfidence = fieldConfidences.Values.Average();

        // Apply penalty for fields below threshold
        var belowThresholdCount = fieldConfidences.Values.Count(c => c < FIELD_CONFIDENCE_THRESHOLD);
        var penalty = belowThresholdCount * 0.05; // 5% penalty per low-confidence field

        var finalConfidence = Math.Max(0.0, averageConfidence - penalty);

        _logger.LogDebug(
            "Document confidence calculated: {Confidence} (avg: {Average}, penalty: {Penalty})",
            finalConfidence, averageConfidence, penalty);

        return finalConfidence;
    }

    /// <summary>
    /// Cleans JSON response by removing markdown code blocks and extra formatting.
    /// Handles responses wrapped in ```json or ``` blocks.
    /// </summary>
    /// <param name="content">The raw JSON content to clean</param>
    /// <returns>Cleaned JSON string ready for deserialization</returns>
    private string CleanJsonResponse(string content)
    {
        var jsonContent = content.Trim();
        if (jsonContent.StartsWith("```json"))
        {
            jsonContent = jsonContent.Substring(7);
        }
        if (jsonContent.StartsWith("```"))
        {
            jsonContent = jsonContent.Substring(3);
        }
        if (jsonContent.EndsWith("```"))
        {
            jsonContent = jsonContent.Substring(0, jsonContent.Length - 3);
        }
        return jsonContent.Trim();
    }

    /// <summary>
    /// Extracts text from PDF using Azure Document Intelligence.
    /// Uses the prebuilt-read model to extract all text content.
    /// </summary>
    /// <param name="documentUri">The URI of the document to extract text from</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>Extracted text content from the document</returns>
    /// <exception cref="Exception">Thrown when text extraction fails</exception>
    private async Task<string> ExtractTextFromPdfAsync(Uri documentUri, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _documentIntelligenceService.ExtractTextFromDocumentAsync(documentUri, cancellationToken);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting text from PDF");
            throw;
        }
    }

    // CHANGE: Added ExtractTextFromExcelAsync to read Excel files using ClosedXML and convert to text for OpenAI
    /// <summary>
    /// Downloads and reads an Excel file, converting all cell data to text format for OpenAI analysis
    /// </summary>
    private async Task<string> ExtractTextFromExcelAsync(string sasUrl, CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Starting Excel text extraction");

            using var httpClient = new HttpClient();
            var fileBytes = await httpClient.GetByteArrayAsync(sasUrl, cancellationToken);

            using var stream = new MemoryStream(fileBytes);
            using var workbook = new XLWorkbook(stream);

            var textBuilder = new System.Text.StringBuilder();

            foreach (var worksheet in workbook.Worksheets)
            {
                textBuilder.AppendLine($"--- Sheet: {worksheet.Name} ---");

                var usedRange = worksheet.RangeUsed();
                if (usedRange == null) continue;

                // Read header row
                var firstRow = usedRange.FirstRow();
                var headers = new List<string>();
                foreach (var cell in firstRow.Cells())
                {
                    headers.Add(cell.GetString());
                }
                textBuilder.AppendLine(string.Join(" | ", headers));
                textBuilder.AppendLine(new string('-', 80));

                // Read data rows
                foreach (var row in usedRange.Rows().Skip(1))
                {
                    var values = new List<string>();
                    foreach (var cell in row.Cells())
                    {
                        values.Add(cell.GetString());
                    }
                    textBuilder.AppendLine(string.Join(" | ", values));
                }
            }

            var extractedText = textBuilder.ToString();
            _logger.LogInformation("Excel text extraction completed. Extracted {Length} characters from {Sheets} sheets",
                extractedText.Length, workbook.Worksheets.Count);

            return extractedText;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting text from Excel file");
            throw;
        }
    }

    // CHANGE: Added new method - Analyzes PDF-extracted text using OpenAI to get all Invoice fields
    /// <summary>
    /// Analyzes extracted text using GPT-4 to extract Invoice data.
    /// Performs detailed field extraction from Document Intelligence text output.
    /// </summary>
    /// <param name="extractedText">The text extracted from the invoice document</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>InvoiceData containing all extracted invoice information</returns>
    private async Task<InvoiceData> AnalyzeInvoiceTextAsync(string extractedText, CancellationToken cancellationToken)
    {
        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are an Invoice data extraction specialist. Azure Document Intelligence has already parsed the document text. Your task is to analyze this pre-extracted text and structure it into the required JSON format.

EXTRACTION RULES:
1. Extract ONLY information present in the provided text
2. Do NOT guess or invent values
3. Normalize dates to YYYY-MM-DD format
4. Remove currency symbols (₹, INR, Rs.) and commas from amounts
5. For GSTIN: extract the 15-character code, derive state code (first 2 digits) and state name
6. If multiple totals exist, use the final/largest amount
7. Return empty string for missing text fields, 0 for missing numeric fields

KEY FIELDS TO EXTRACT:
- Invoice Number (look for: Invoice No, Inv No, Bill No, Tax Invoice No)
- Invoice Date (normalize to YYYY-MM-DD)
- Vendor Name & Code (supplier/from party)
- Agency/Customer Name, Address & Code (recipient/bill to party)
- Billing Name & Address
- GST Number (15 chars - prefer SUPPLIER GSTIN), State Code (first 2 digits), State Name
- HSN/SAC Code
- PO Number (look for: PO No, Purchase Order, PO Ref)
- Sub Total, Tax Amount, Total Amount
- GST Percentage (common: 5%, 12%, 18%, 28%)
- Line Items: itemCode, description, quantity, unitPrice, lineTotal

STATE CODE MAPPING:
07=Delhi, 10=Bihar, 19=West Bengal, 24=Gujarat, 27=Maharashtra, 29=Karnataka, 33=Tamil Nadu

VALIDATION:
- Verify: Sub Total + Tax Amount ≈ Total Amount
- If mismatch, use explicit totals from invoice summary

CONFIDENCE SCORING (0.0-1.0):
0.9-1.0: All key fields extracted clearly
0.75-0.9: Minor fields missing
0.6-0.75: Some important fields missing
0.4-0.6: Partial extraction only
<0.4: Poor quality data

OUTPUT FORMAT (JSON only, no explanations):
{
  ""invoiceNumber"": """",
  ""invoiceDate"": ""YYYY-MM-DD"",
  ""agencyName"": """",
  ""agencyAddress"": """",
  ""agencyCode"": """",
  ""billingName"": """",
  ""billingAddress"": """",
  ""vendorName"": """",
  ""vendorCode"": """",
  ""stateName"": """",
  ""stateCode"": """",
  ""gstNumber"": """",
  ""gstPercentage"": 0,
  ""hsnSacCode"": """",
  ""poNumber"": """",
  ""subTotal"": 0,
  ""taxAmount"": 0,
  ""totalAmount"": 0,
  ""lineItems"": [
    {
      ""itemCode"": """",
      ""description"": """",
      ""quantity"": 0,
      ""unitPrice"": 0,
      ""lineTotal"": 0
    }
  ],
  ""confidence"": 0.0
}"),
                new ChatRequestUserMessage($"Extract all invoice data from this text:\n\n{extractedText}")
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        _logger.LogInformation("Received Invoice text analysis response: {Response}", content);
        
        return ParseInvoiceResponse(content);
    }

    /// <summary>
    /// Analyzes extracted text using GPT-4 to extract PO data.
    /// Performs detailed field extraction from Document Intelligence text output.
    /// </summary>
    /// <param name="extractedText">The text extracted from the PO document</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>POData containing all extracted purchase order information</returns>
    private async Task<POData> AnalyzePOTextAsync(string extractedText, CancellationToken cancellationToken)
    {
        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are a Purchase Order data extraction expert specializing in Indian business documents.
Analyze the provided text extracted from a Purchase Order document and extract ALL structured information with maximum accuracy.

REQUIRED FIELDS TO EXTRACT:
1. PO Number - Look for: 'PO No', 'PO Number', 'Purchase Order'
2. PO Type - Look for: 'PO TYPE', 'Order Type' (e.g., 'Marketing PO')
3. Vendor Name - Look for: 'Vendor', 'Supplier'
4. Vendor Code - Look for: 'Vendor Code'
5. Vendor Address - Look for: 'Vendor Address'
6. Buyer Name - Look for: 'Buyer'
7. Delivery Terms - Look for: 'Delivery Terms'
8. Payment Terms - Look for: 'Payment Terms'
9. PO Date - Look for: 'PO Date' (format: YYYY-MM-DD)
10. Total Amount - Look for: 'Total PO Price', 'Total Amount'
11. Line Items - ALL items with Item Code, Description, Qty, Rate, Amount, Plant, Tax Code, Currency

CRITICAL INSTRUCTIONS:
- Extract EXACT values as they appear in the document.
- For amounts, remove currency symbols (₹, INR, Rs.) and commas.
- PO Date: Handle formats like 20.03.2025, 20/03/2025, 20-03-2025 → convert to YYYY-MM-DD.
- If a field is not found, use empty string for text, 0 for numbers.

Respond ONLY with a JSON object in this exact format:
{
  ""poNumber"": ""string"",
  ""poType"": ""string"",
  ""vendorName"": ""string"",
  ""vendorCode"": ""string"",
  ""vendorAddress"": ""string"",
  ""buyerName"": ""string"",
  ""deliveryTerms"": ""string"",
  ""paymentTerms"": ""string"",
  ""poDate"": ""YYYY-MM-DD"",
  ""totalAmount"": 0.00,
  ""lineItems"": [
    {
      ""itemCode"": ""string"",
      ""description"": ""string"",
      ""quantity"": 0,
      ""unitPrice"": 0.00,
      ""lineTotal"": 0.00,
      ""plant"": ""string"",
      ""taxCode"": ""string"",
      ""currency"": ""string"",
    }
  ],
  ""confidence"": 0.0
}"),
                new ChatRequestUserMessage($"Extract all purchase order data from this text:\n\n{extractedText}")
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        _logger.LogInformation("Received PO text analysis response: {Response}", content);
        
        return ParsePOResponse(content);
    }

    // CHANGE: Expanded Cost Summary text prompt to extract all required fields
    /// <summary>
    /// Analyzes extracted text using GPT-4 to extract Cost Summary data
    /// </summary>
    private async Task<CostSummaryData> AnalyzeCostSummaryTextAsync(string extractedText, CancellationToken cancellationToken)
    {
        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are a Cost Summary data extraction expert specializing in Indian marketing activity cost sheets.
Analyze the provided text extracted from a cost summary document and extract ALL structured information with maximum accuracy.

REQUIRED FIELDS TO EXTRACT:
1. Campaign Name - Activity/campaign title 
2. State - State name (e.g. 'Maharashtra')
3. Place of Supply - Look for: 'Place of Supply', 'State' (e.g., 'Bihar')
4. Campaign Start Date - Start date (format: YYYY-MM-DD). Look for: 'Date of Supply', date ranges like 'Feb.-Mar.2025'
5. Campaign End Date - End date (format: YYYY-MM-DD)
6. Number of Days - Look for: 'Days' column values, or text like '90 day', '78 days'. Use the MAXIMUM days value from the table.
7. Number of Teams - Look for: 'Team', 'No of Teams', text like 'By 2 Team'
8. Number of Activations - Look for: 'Activations', 'No of Activations'
9. Total Cost - Final total amount including tax (look for: 'Total Amount after Tax', 'Grand Total', 'Tot Inv. Amt')
10. Cost Breakdowns - Extract EVERY line item from the table with ALL details

FOR EACH COST BREAKDOWN ITEM, EXTRACT:
- category: The item name/description (e.g., 'Vehicle Branding', 'Promoter', 'Leaflet')
- elementName: Same as category (the element/activity name)
- amount: The 'Total' column value for that row
- quantity: The 'Qty' column value for that row
- unit: The unit of measurement (e.g., 'days', 'pieces', 'per person')
- isFixedCost: true if this is a one-time/fixed cost (items with 'One Time' in Days column)
- isVariableCost: true if this cost varies by days/quantity (items with numeric Days like 78, 90)

CRITICAL INSTRUCTIONS:
- 'One Time' in Days column means isFixedCost=true, isVariableCost=false
- Numeric Days (like 78, 90) means isFixedCost=false, isVariableCost=true
- DO NOT include tax rows (CGST, SGST, IGST) as cost breakdown items
- Agency Fees/Cost is a separate line item, include it
- Total Cost should be the FINAL amount after tax
- If a field is not found, use empty string for text, 0 for numbers, null for optional fields

Respond ONLY with a JSON object in this exact format:
{
  ""campaignName"": ""string"",
  ""state"": ""string"",
  ""placeOfSupply"": ""string"",
  ""campaignStartDate"": ""YYYY-MM-DD"",
  ""campaignEndDate"": ""YYYY-MM-DD"",
  ""numberOfDays"": 0,
  ""numberOfTeams"": 0,
  ""numberOfActivations"": 0,
  ""totalCost"": 0.00,
  ""costBreakdowns"": [
    {
      ""category"": ""string"",
      ""elementName"": ""string"",
      ""amount"": 0.00,
      ""quantity"": 0,
      ""unit"": ""string"",
      ""isFixedCost"": false,
      ""isVariableCost"": false
    }
  ],
  ""confidence"": 0.0
}"),
                new ChatRequestUserMessage($"Extract all cost summary data from this text:\n\n{extractedText}")
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        
        return ParseCostSummaryResponse(content);
    }

    /// <summary>
    /// Creates placeholder cost summary data
    /// </summary>
    private CostSummaryData CreatePlaceholderCostSummary()
    {
        return new CostSummaryData
        {
            TotalCost = 50000.00m,
            CostBreakdowns = new List<CostBreakdown>
            {
                new CostBreakdown { Category = "Materials", Amount = 30000.00m },
                new CostBreakdown { Category = "Labor", Amount = 15000.00m },
                new CostBreakdown { Category = "Other", Amount = 5000.00m }
            },
            FieldConfidences = new Dictionary<string, double>
            {
                ["TotalCost"] = 0.85,
                ["Overall"] = 0.85
            },
            IsFlaggedForReview = false
        };
    }

    // CHANGE: Added ExtractActivityAsync for Activity Summary document extraction (same hybrid pattern as PO/Invoice)
    /// <summary>
    /// Extracts structured data from an Activity Summary document
    /// Uses Azure Document Intelligence for PDFs → OpenAI analyzes text
    /// </summary>
    // CHANGE: Helper to write debug logs to file since terminal has space constraints
    private static void DebugLog(string message)
    {
        try
        {
            var logPath = Path.Combine(AppContext.BaseDirectory, "extraction_debug.log");
            File.AppendAllText(logPath, $"[{DateTime.Now:HH:mm:ss}] {message}\n");
        }
        catch { }
    }

    public async Task<ActivityData> ExtractActivityAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            DebugLog($"[ACTIVITY] Starting extraction for: {blobUrl}");
            DebugLog($"[ACTIVITY] IsDocumentFile: {IsDocumentFile(blobUrl)}");
            _logger.LogInformation("Starting Activity Summary extraction for URL: {BlobUrl}", blobUrl);

            // For document files (PDF, Word, Excel), use hybrid extraction
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected - using hybrid extraction (Document Intelligence + OpenAI)");
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                DebugLog($"[ACTIVITY] SAS URL obtained, length: {sasUrl?.Length}");

                try
                {
                    // CHANGE: Use ClosedXML for Excel files, Document Intelligence for PDF
                    string extractedText;
                    if (blobUrl.ToLowerInvariant().EndsWith(".xlsx") || blobUrl.ToLowerInvariant().EndsWith(".xls"))
                    {
                        DebugLog("[ACTIVITY] Using Excel extraction...");
                        extractedText = await ExtractTextFromExcelAsync(sasUrl, cancellationToken);
                    }
                    else
                    {
                        DebugLog("[ACTIVITY] Using PDF extraction (Document Intelligence)...");
                        extractedText = await ExtractTextFromPdfAsync(new Uri(sasUrl), cancellationToken);
                    }

                    DebugLog($"[ACTIVITY] Extracted text length: {extractedText?.Length ?? 0}");
                    DebugLog($"[ACTIVITY] Text preview: {extractedText?.Substring(0, Math.Min(500, extractedText?.Length ?? 0))}");

                    var result = await AnalyzeActivityTextAsync(extractedText, cancellationToken);
                    DebugLog($"[ACTIVITY] Result - Rows: {result.Rows.Count}");

                    var debugJson = System.Text.Json.JsonSerializer.Serialize(result);
                    DebugLog($"[ACTIVITY] JSON length: {debugJson.Length}, preview: {debugJson.Substring(0, Math.Min(500, debugJson.Length))}");

                    _logger.LogInformation(
                        "Activity hybrid extraction completed. Rows: {Rows}",
                        result.Rows.Count);
                    return result;
                }
                catch (Exception ex)
                {
                    DebugLog($"[ACTIVITY] ERROR: {ex.GetType().Name}: {ex.Message}");
                    DebugLog($"[ACTIVITY] Stack: {ex.StackTrace}");
                    if (ex.InnerException != null)
                        DebugLog($"[ACTIVITY] Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
                    _logger.LogError(ex, "Error in hybrid Activity extraction, returning empty result");
                    return new ActivityData
                    {
                        FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                        IsFlaggedForReview = true
                    };
                }
            }

            // For images, use GPT Vision
            var imageData = await PrepareImageDataAsync(blobUrl);

            if (imageData == null)
            {
                _logger.LogWarning("Could not prepare image data for Activity extraction");
                return new ActivityData
                {
                    FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                    IsFlaggedForReview = true
                };
            }

            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    new ChatRequestSystemMessage(@"You are an Activity Summary data extraction expert specializing in Indian marketing activity documents.
Analyze the provided Activity Summary image and extract ALL structured information with maximum accuracy.

REQUIRED FIELDS TO EXTRACT:
1. Dealer and Location Details - For EACH location extract:
   - locationName: City/town name
   - dealerName: Dealer name
   - district: District name
   - state/city: State/City name
   - numberOfDays: Number of days at this location
   - startDate: Start date at this location (YYYY-MM-DD)
   - endDate: End date at this location (YYYY-MM-DD)

CRITICAL INSTRUCTIONS:
- Extract EXACT values visible in the image.
- If a field is not found, use empty string for text, 0 for numbers, null for dates.
- Total Days should be the sum of all location days if not explicitly stated.

Respond ONLY with a JSON object in this exact format:
{
  ""locationActivities"": [
    {
      ""locationName"": ""string"",
      ""dealerName"": ""string"",
      ""state"": ""string"",
      ""numberOfDays"": 0,
      ""startDate"": ""YYYY-MM-DD"",
      ""endDate"": ""YYYY-MM-DD""
    }
  ],
  ""confidence"": 0.0
}"),
                    new ChatRequestUserMessage(
                        new ChatMessageContentItem[]
                        {
                            new ChatMessageTextContentItem("Please extract ALL data from this Activity Summary image. Be thorough and accurate."),
                            CreateImageContentItem(imageData)
                        })
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received Activity extraction response: {Response}", content);

            var activityData = ParseActivityResponse(content);
            _logger.LogInformation(
                "Activity extraction completed. Rows: {Rows}",
                activityData.Rows.Count);

            return activityData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting Activity data from URL: {BlobUrl}", blobUrl);
            throw;
        }
    }

    // CHANGE: Simplified AnalyzeActivityTextAsync to extract only: Dealer, Location, To, From, Day, Working Day
    /// <summary>
    /// Analyzes extracted text using OpenAI to extract Activity Summary data
    /// </summary>
    private async Task<ActivityData> AnalyzeActivityTextAsync(string extractedText, CancellationToken cancellationToken)
    {
        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are an Activity Summary data extraction expert.
Analyze the provided text extracted from an Activity Summary document.

The document is a table with these columns:
1. Dealer - Dealer name (e.g., 'Magadh Auto Agency')
2. Location - City/town name (e.g., 'Patna')
3. To - End date (convert to YYYY-MM-DD)
4. From - Start date (convert to YYYY-MM-DD)
5. Day - Total number of days
6. Working Day - Number of working days

CRITICAL INSTRUCTIONS:
- Extract EVERY row from the table.
- Handle date formats like 2/14/2025, 01.02.2025, 01-Feb-2025 → convert to YYYY-MM-DD.
- If a field is not found, use empty string for text, 0 for numbers, null for dates.

Respond ONLY with a JSON object in this exact format:
{
  ""rows"": [
    {
      ""dealerName"": ""string"",
      ""location"": ""string"",
      ""toDate"": ""YYYY-MM-DD"",
      ""fromDate"": ""YYYY-MM-DD"",
      ""day"": 0,
      ""workingDay"": 0
    }
  ],
  ""confidence"": 0.0
}"),
                new ChatRequestUserMessage($"Extract all activity summary rows from this text:\n\n{extractedText}")
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        _logger.LogInformation("Received Activity text analysis response: {Response}", content);

        return ParseActivityResponse(content);
    }

    // CHANGE: Simplified ParseActivityResponse to match new ActivityData DTO (Dealer, Location, To, From, Day, WorkingDay)
    private ActivityData ParseActivityResponse(string content)
    {
        try
        {
            var jsonContent = CleanJsonResponse(content);
            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var parsed = JsonSerializer.Deserialize<ActivityDataResponse>(jsonContent, options);

            if (parsed == null)
            {
                throw new InvalidOperationException("Failed to parse Activity response");
            }

            var activityData = new ActivityData
            {
                Rows = parsed.Rows?.Select(r => new ActivityRow
                {
                    DealerName = r.DealerName ?? string.Empty,
                    Location = r.Location ?? string.Empty,
                    ToDate = r.ToDate,
                    FromDate = r.FromDate,
                    Day = r.Day,
                    WorkingDay = r.WorkingDay
                }).ToList() ?? new List<ActivityRow>(),
                FieldConfidences = new Dictionary<string, double>
                {
                    ["Overall"] = parsed.Confidence
                },
                IsFlaggedForReview = parsed.Confidence < CONFIDENCE_THRESHOLD
            };

            return activityData;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse Activity response: {Content}", content);
            return new ActivityData
            {
                FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                IsFlaggedForReview = true
            };
        }
    }

    // CHANGE: Simplified ActivityDataResponse to match table columns
    private class ActivityDataResponse
    {
        public List<ActivityRowResponse>? Rows { get; set; }
        public double Confidence { get; set; }
    }

    // CHANGE: Simplified ActivityRowResponse to match table columns: Dealer, Location, To, From, Day, Working Day
    private class ActivityRowResponse
    {
        public string? DealerName { get; set; }
        public string? Location { get; set; }
        public DateTime? ToDate { get; set; }
        public DateTime? FromDate { get; set; }
        public int Day { get; set; }
        public int WorkingDay { get; set; }
    }

    // CHANGE: Added ExtractEnquiryDumpAsync for Enquiry Dump Excel extraction (same hybrid pattern as PO/Invoice)
    /// <summary>
    /// Extracts structured data from an Enquiry Dump Excel file
    /// Uses ClosedXML to read Excel → OpenAI analyzes text
    /// </summary>
    public async Task<EnquiryDumpData> ExtractEnquiryDumpAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            DebugLog($"[ENQUIRY] Starting extraction for: {blobUrl}");
            _logger.LogInformation("Starting Enquiry Dump extraction for URL: {BlobUrl}", blobUrl);

            var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
            DebugLog($"[ENQUIRY] SAS URL obtained, length: {sasUrl?.Length}");

            try
            {
                // CHANGE: Use ClosedXML to read Excel files instead of Document Intelligence (which doesn't support .xlsx)
                string extractedText;
                if (blobUrl.ToLowerInvariant().EndsWith(".xlsx") || blobUrl.ToLowerInvariant().EndsWith(".xls"))
                {
                    DebugLog("[ENQUIRY] Using Excel extraction...");
                    extractedText = await ExtractTextFromExcelAsync(sasUrl, cancellationToken);
                }
                else
                {
                    DebugLog("[ENQUIRY] Using PDF extraction...");
                    extractedText = await ExtractTextFromPdfAsync(new Uri(sasUrl), cancellationToken);
                }

                DebugLog($"[ENQUIRY] Extracted text length: {extractedText?.Length ?? 0}");
                DebugLog($"[ENQUIRY] Text preview: {extractedText?.Substring(0, Math.Min(500, extractedText?.Length ?? 0))}");

                var result = await AnalyzeEnquiryDumpTextAsync(extractedText, cancellationToken);
                DebugLog($"[ENQUIRY] Result - State: {result.State}, Records: {result.Records?.Count}, Total: {result.TotalRecords}");

                var debugJson = System.Text.Json.JsonSerializer.Serialize(result);
                DebugLog($"[ENQUIRY] JSON length: {debugJson.Length}, preview: {debugJson.Substring(0, Math.Min(500, debugJson.Length))}");

                _logger.LogInformation(
                    "Enquiry Dump extraction completed. State: {State}, Records: {Records}",
                    result.State, result.TotalRecords);
                return result;
            }
            catch (Exception ex)
            {
                DebugLog($"[ENQUIRY] ERROR: {ex.GetType().Name}: {ex.Message}");
                DebugLog($"[ENQUIRY] Stack: {ex.StackTrace}");
                if (ex.InnerException != null)
                    DebugLog($"[ENQUIRY] Inner: {ex.InnerException.GetType().Name}: {ex.InnerException.Message}");
                _logger.LogError(ex, "Error in Enquiry Dump extraction, returning empty result");
                return new EnquiryDumpData
                {
                    FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                    IsFlaggedForReview = true
                };
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting Enquiry Dump data from URL: {BlobUrl}", blobUrl);
            throw;
        }
    }

    // CHANGE: Added AnalyzeEnquiryDumpTextAsync for hybrid text analysis of Excel data
    /// <summary>
    /// Analyzes extracted text using OpenAI to extract Enquiry Dump data
    /// </summary>
    // CHANGE: Simple single-call approach for EnquiryDump extraction via OpenAI, prompt updated to match actual Excel columns
    private async Task<EnquiryDumpData> AnalyzeEnquiryDumpTextAsync(string extractedText, CancellationToken cancellationToken)
    {
        // CHANGE: Truncate text if too large to avoid token limits — send first 60000 chars
        var textToSend = extractedText.Length > 60000 ? extractedText.Substring(0, 60000) : extractedText;
        DebugLog($"[ENQUIRY] Sending text length: {textToSend.Length} (original: {extractedText.Length})");

        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are a data extraction expert. Extract structured records from tabular Excel data.

The Excel columns are (in order):
Sr No | Date | Dealership Name | District | Segment | Company Name | Brand | Address | Principal Name | Contact | Secondary Name | Secondary Contact | (possibly more columns like 3W, EV, 4W, Category, Remark, Age, Test Drive, Visit)

Map each row to these fields:
- state: Infer the state from district names in the data (e.g. Muzaffarpur → Bihar). Use one state for all records.
- date: From ""Date"" column, convert to YYYY-MM-DD format
- dealerCode: Empty string (not present in this format)
- dealerName: From ""Dealership Name"" column
- district: From ""District"" column
- pincode: Empty string (not present)
- customerName: From ""Principal Name"" column (or ""Company Name"" if Principal Name is empty)
- customerNumber: From ""Contact"" column (first contact column, column J)
- testRideTaken: From ""Test Drive"" or ""Visit"" column if present, normalize to Yes/No. If not present use empty string.

CRITICAL RULES:
- Extract EVERY data row. Do NOT skip rows. Do NOT summarize.
- Skip only the header row and any completely blank rows.
- If a field is missing or N/A, use empty string.
- Phone numbers may appear as scientific notation (e.g. 9.63E+09) — convert to full number string (e.g. ""9630000000"").

Return ONLY valid JSON (no markdown, no explanation):
{
  ""state"": ""Bihar"",
  ""totalRecords"": 479,
  ""records"": [{""state"":""Bihar"",""date"":""2025-02-15"",""dealerCode"":"""",""dealerName"":""HY Motors"",""district"":""Muzaffarpur"",""pincode"":"""",""customerName"":""Nitish"",""customerNumber"":""9630000000"",""testRideTaken"":""""}],
  ""confidence"": 0.9
}"),
                new ChatRequestUserMessage($"Extract ALL records from this Excel data:\n\n{textToSend}")
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        // CHANGE: Log raw OpenAI response for debugging
        DebugLog($"[ENQUIRY] OpenAI response length: {content?.Length}, finish reason: {response.Value.Choices[0].FinishReason}");
        DebugLog($"[ENQUIRY] OpenAI response preview: {content?.Substring(0, Math.Min(1000, content?.Length ?? 0))}");
        _logger.LogInformation("Received Enquiry Dump text analysis response length: {Length}", content?.Length);

        return ParseEnquiryDumpResponse(content ?? string.Empty);
    }

    // CHANGE: Added ParseEnquiryDumpResponse to parse OpenAI response into EnquiryDumpData
    private EnquiryDumpData ParseEnquiryDumpResponse(string content)
    {
        try
        {
            var jsonContent = CleanJsonResponse(content);
            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var parsed = JsonSerializer.Deserialize<EnquiryDumpDataResponse>(jsonContent, options);

            if (parsed == null)
            {
                throw new InvalidOperationException("Failed to parse Enquiry Dump response");
            }

            var enquiryData = new EnquiryDumpData
            {
                State = parsed.State ?? string.Empty,
                TotalRecords = parsed.TotalRecords > 0 ? parsed.TotalRecords : (parsed.Records?.Count ?? 0),
                Records = parsed.Records?.Select(r => new EnquiryRecord
                {
                    State = r.State ?? string.Empty,
                    Date = r.Date,
                    DealerCode = r.DealerCode ?? string.Empty,
                    DealerName = r.DealerName ?? string.Empty,
                    District = r.District ?? string.Empty,
                    Pincode = r.Pincode ?? string.Empty,
                    CustomerName = r.CustomerName ?? string.Empty,
                    CustomerNumber = r.CustomerNumber ?? string.Empty,
                    TestRideTaken = r.TestRideTaken ?? string.Empty
                }).ToList() ?? new List<EnquiryRecord>(),
                FieldConfidences = new Dictionary<string, double>
                {
                    ["Overall"] = parsed.Confidence
                },
                IsFlaggedForReview = parsed.Confidence < CONFIDENCE_THRESHOLD
            };

            return enquiryData;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse Enquiry Dump response: {Content}", content);
            return new EnquiryDumpData
            {
                FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.3 },
                IsFlaggedForReview = true
            };
        }
    }

    // CHANGE: Added EnquiryDumpDataResponse for JSON deserialization
    private class EnquiryDumpDataResponse
    {
        public string? State { get; set; }
        public int TotalRecords { get; set; }
        public List<EnquiryRecordResponse>? Records { get; set; }
        public double Confidence { get; set; }
    }

    // CHANGE: Added EnquiryRecordResponse for JSON deserialization
    private class EnquiryRecordResponse
    {
        public string? State { get; set; }
        public DateTime? Date { get; set; }
        public string? DealerCode { get; set; }
        public string? DealerName { get; set; }
        public string? District { get; set; }
        public string? Pincode { get; set; }
        public string? CustomerName { get; set; }
        public string? CustomerNumber { get; set; }
        public string? TestRideTaken { get; set; }
    }
}