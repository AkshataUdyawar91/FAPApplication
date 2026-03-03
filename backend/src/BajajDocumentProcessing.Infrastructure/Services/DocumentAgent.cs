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

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Document Agent service for document classification and field extraction using Azure OpenAI
/// </summary>
public class DocumentAgent : IDocumentAgent
{
    private readonly OpenAIClient _openAIClient;
    private readonly string _deploymentName;
    private readonly ILogger<DocumentAgent> _logger;
    private readonly HttpClient _httpClient;
    private readonly IFileStorageService _fileStorageService;
    private const double CONFIDENCE_THRESHOLD = 0.70;
    private const double FIELD_CONFIDENCE_THRESHOLD = 0.60;

    public DocumentAgent(
        IConfiguration configuration,
        ILogger<DocumentAgent> logger,
        HttpClient httpClient,
        IFileStorageService fileStorageService)
    {
        _logger = logger;
        _httpClient = httpClient;
        _fileStorageService = fileStorageService;

        var endpoint = configuration["AzureOpenAI:Endpoint"] 
            ?? throw new InvalidOperationException("Azure OpenAI endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] 
            ?? throw new InvalidOperationException("Azure OpenAI API key not configured");
        _deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        _openAIClient = new OpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
    }

    /// <summary>
    /// Prepares image data for Azure OpenAI Vision API
    /// Always converts to base64 since Azure OpenAI can't access private blob URLs
    /// </summary>
    private async Task<string> PrepareImageDataAsync(string blobUrl)
    {
        try
        {
            // Always convert to base64 - Azure OpenAI can't access private blob URLs
            var fileBytes = await _fileStorageService.GetFileBytesAsync(blobUrl);
            var base64 = Convert.ToBase64String(fileBytes);
            
            // Determine MIME type from file extension
            var mimeType = "image/jpeg"; // default
            if (blobUrl.EndsWith(".png", StringComparison.OrdinalIgnoreCase))
                mimeType = "image/png";
            else if (blobUrl.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
                mimeType = "application/pdf";
            else if (blobUrl.EndsWith(".tiff", StringComparison.OrdinalIgnoreCase) || 
                     blobUrl.EndsWith(".tif", StringComparison.OrdinalIgnoreCase))
                mimeType = "image/tiff";
            
            _logger.LogInformation("Converted file to base64: {BlobUrl}, Size: {Size} bytes", blobUrl, fileBytes.Length);
            return $"data:{mimeType};base64,{base64}";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to convert file to base64: {BlobUrl}", blobUrl);
            throw;
        }
    }

    /// <summary>
    /// Classifies a document using Azure OpenAI GPT-4 Vision
    /// </summary>
    public async Task<DocumentClassification> ClassifyAsync(
        string blobUrl, 
        CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting document classification for URL: {BlobUrl}", blobUrl);

            // Prepare image data (convert local files to base64)
            var imageData = await PrepareImageDataAsync(blobUrl);

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
                    new ChatRequestUserMessage($"Please classify this document. Image: {imageData.Substring(0, Math.Min(50, imageData.Length))}...")
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
                "Document classified as {Type} with confidence {Confidence}. Flagged for review: {Flagged}",
                result.Type, result.Confidence, result.IsFlaggedForReview);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error classifying document from URL: {BlobUrl}", blobUrl);
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
                    "Invalid document type '{Type}' returned. Defaulting to Additional_Document", 
                    parsed.TypeString);
                documentType = DocumentType.AdditionalDocument;
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
                Type = DocumentType.AdditionalDocument,
                TypeString = "Additional_Document",
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
    /// Extracts structured data from a Purchase Order document using GPT-4 Vision
    /// </summary>
    public async Task<POData> ExtractPOAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting PO extraction for URL: {BlobUrl}", blobUrl);

            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    new ChatRequestSystemMessage(@"You are a Purchase Order data extraction expert.
Analyze the provided PO document image and extract the following information:
- PO Number
- Vendor Name
- PO Date
- Total Amount
- Line Items (ItemCode, Description, Quantity, UnitPrice, LineTotal)

Respond ONLY with a JSON object in this exact format:
{
  ""poNumber"": ""string"",
  ""vendorName"": ""string"",
  ""poDate"": ""YYYY-MM-DD"",
  ""totalAmount"": 0.00,
  ""lineItems"": [
    {
      ""itemCode"": ""string"",
      ""description"": ""string"",
      ""quantity"": 0,
      ""unitPrice"": 0.00,
      ""lineTotal"": 0.00
    }
  ],
  ""confidence"": 0.0
}

Where confidence is your overall confidence in the extraction (0.0 to 1.0).
If a field is not found, use null or empty values."),
                    new ChatRequestUserMessage($"Please extract data from this Purchase Order. Image URL: {blobUrl}")
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(
                chatCompletionsOptions, 
                cancellationToken);

            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received PO extraction response");

            var poData = ParsePOResponse(content);

            _logger.LogInformation(
                "PO extraction completed. PO Number: {PONumber}, Line Items: {ItemCount}, Flagged: {Flagged}",
                poData.PONumber, poData.LineItems.Count, poData.IsFlaggedForReview);

            return poData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting PO data from URL: {BlobUrl}", blobUrl);
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
                VendorName = parsed.VendorName ?? string.Empty,
                PODate = parsed.PODate ?? DateTime.Now,
                TotalAmount = parsed.TotalAmount,
                LineItems = parsed.LineItems?.Select(li => new POLineItem
                {
                    ItemCode = li.ItemCode ?? string.Empty,
                    Description = li.Description ?? string.Empty,
                    Quantity = li.Quantity,
                    UnitPrice = li.UnitPrice,
                    LineTotal = li.LineTotal
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

    private class PODataResponse
    {
        public string? PONumber { get; set; }
        public string? VendorName { get; set; }
        public DateTime? PODate { get; set; }
        public decimal TotalAmount { get; set; }
        public List<POLineItemResponse>? LineItems { get; set; }
        public double Confidence { get; set; }
    }

    private class POLineItemResponse
    {
        public string? ItemCode { get; set; }
        public string? Description { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal LineTotal { get; set; }
    }

    /// <summary>
    /// Extracts structured data from an Invoice document using GPT-4 Vision
    /// </summary>
    public async Task<InvoiceData> ExtractInvoiceAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Invoice extraction for URL: {BlobUrl}", blobUrl);

            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    new ChatRequestSystemMessage(@"You are an Invoice data extraction expert.
Analyze the provided invoice document image and extract the following information:
- Invoice Number
- Vendor Name
- Invoice Date
- SubTotal
- Tax Amount
- Total Amount
- Line Items (ItemCode, Description, Quantity, UnitPrice, LineTotal)

Respond ONLY with a JSON object in this exact format:
{
  ""invoiceNumber"": ""string"",
  ""vendorName"": ""string"",
  ""invoiceDate"": ""YYYY-MM-DD"",
  ""subTotal"": 0.00,
  ""taxAmount"": 0.00,
  ""totalAmount"": 0.00,
  ""lineItems"": [
    {
      ""itemCode"": ""string"",
      ""description"": ""string"",
      ""quantity"": 0,
      ""unitPrice"": 0.00,
      ""lineTotal"": 0.00
    }
  ],
  ""confidence"": 0.0
}

Where confidence is your overall confidence in the extraction (0.0 to 1.0).
If a field is not found, use null or empty values."),
                    new ChatRequestUserMessage($"Please extract data from this Invoice. Image URL: {blobUrl}")
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(
                chatCompletionsOptions, 
                cancellationToken);

            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received Invoice extraction response");

            var invoiceData = ParseInvoiceResponse(content);

            _logger.LogInformation(
                "Invoice extraction completed. Invoice Number: {InvoiceNumber}, Line Items: {ItemCount}, Flagged: {Flagged}",
                invoiceData.InvoiceNumber, invoiceData.LineItems.Count, invoiceData.IsFlaggedForReview);

            return invoiceData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting Invoice data from URL: {BlobUrl}", blobUrl);
            throw;
        }
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

            var invoiceData = new InvoiceData
            {
                InvoiceNumber = parsed.InvoiceNumber ?? string.Empty,
                VendorName = parsed.VendorName ?? string.Empty,
                InvoiceDate = parsed.InvoiceDate ?? DateTime.Now,
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

    private class InvoiceDataResponse
    {
        public string? InvoiceNumber { get; set; }
        public string? VendorName { get; set; }
        public DateTime? InvoiceDate { get; set; }
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
    /// Extracts structured data from a Cost Summary document using GPT-4 Vision
    /// </summary>
    public async Task<CostSummaryData> ExtractCostSummaryAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Cost Summary extraction for URL: {BlobUrl}", blobUrl);

            var chatCompletionsOptions = new ChatCompletionsOptions
            {
                DeploymentName = _deploymentName,
                Messages =
                {
                    new ChatRequestSystemMessage(@"You are a Cost Summary data extraction expert.
Analyze the provided cost summary document image and extract the following information:
- Campaign Name
- State
- Campaign Start Date
- Campaign End Date
- Total Cost
- Cost Breakdowns (Category, Amount)

Respond ONLY with a JSON object in this exact format:
{
  ""campaignName"": ""string"",
  ""state"": ""string"",
  ""campaignStartDate"": ""YYYY-MM-DD"",
  ""campaignEndDate"": ""YYYY-MM-DD"",
  ""totalCost"": 0.00,
  ""costBreakdowns"": [
    {
      ""category"": ""string"",
      ""amount"": 0.00
    }
  ],
  ""confidence"": 0.0
}

Where confidence is your overall confidence in the extraction (0.0 to 1.0).
If a field is not found, use null or empty values."),
                    new ChatRequestUserMessage($"Please extract data from this Cost Summary. Image URL: {blobUrl}")
                }
            };

            var response = await _openAIClient.GetChatCompletionsAsync(
                chatCompletionsOptions, 
                cancellationToken);

            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received Cost Summary extraction response");

            var costSummaryData = ParseCostSummaryResponse(content);

            _logger.LogInformation(
                "Cost Summary extraction completed. Campaign: {Campaign}, Cost Breakdowns: {BreakdownCount}, Flagged: {Flagged}",
                costSummaryData.CampaignName, costSummaryData.CostBreakdowns.Count, costSummaryData.IsFlaggedForReview);

            return costSummaryData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting Cost Summary data from URL: {BlobUrl}", blobUrl);
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

            var costSummaryData = new CostSummaryData
            {
                CampaignName = parsed.CampaignName ?? string.Empty,
                State = parsed.State ?? string.Empty,
                CampaignStartDate = parsed.CampaignStartDate ?? DateTime.Now,
                CampaignEndDate = parsed.CampaignEndDate ?? DateTime.Now,
                TotalCost = parsed.TotalCost,
                CostBreakdowns = parsed.CostBreakdowns?.Select(cb => new CostBreakdown
                {
                    Category = cb.Category ?? string.Empty,
                    Amount = cb.Amount
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

    private class CostSummaryDataResponse
    {
        public string? CampaignName { get; set; }
        public string? State { get; set; }
        public DateTime? CampaignStartDate { get; set; }
        public DateTime? CampaignEndDate { get; set; }
        public decimal TotalCost { get; set; }
        public List<CostBreakdownResponse>? CostBreakdowns { get; set; }
        public double Confidence { get; set; }
    }

    private class CostBreakdownResponse
    {
        public string? Category { get; set; }
        public decimal Amount { get; set; }
    }

    /// <summary>
    /// Extracts EXIF metadata from a photo
    /// </summary>
    public async Task<PhotoMetadata> ExtractPhotoMetadataAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting photo metadata extraction for URL: {BlobUrl}", blobUrl);

            // Download the image
            var imageBytes = await _httpClient.GetByteArrayAsync(blobUrl, cancellationToken);
            
            using var stream = new MemoryStream(imageBytes);
            var directories = ImageMetadataReader.ReadMetadata(stream);

            var metadata = new PhotoMetadata();
            var fieldConfidences = new Dictionary<string, double>();

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

            // Calculate overall document confidence and flag if below threshold
            var documentConfidence = CalculateDocumentConfidence(fieldConfidences);
            metadata.IsFlaggedForReview = documentConfidence < CONFIDENCE_THRESHOLD;

            _logger.LogInformation(
                "Photo metadata extraction completed. Timestamp: {Timestamp}, Location: {HasLocation}, Confidence: {Confidence}, Flagged: {Flagged}",
                metadata.Timestamp, metadata.Latitude.HasValue && metadata.Longitude.HasValue, documentConfidence, metadata.IsFlaggedForReview);

            return metadata;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting photo metadata from URL: {BlobUrl}", blobUrl);
            
            // Return empty metadata with low confidence and flagged for review on error
            return new PhotoMetadata
            {
                FieldConfidences = new Dictionary<string, double>(),
                IsFlaggedForReview = true // Flag for review when extraction fails
            };
        }
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
    /// Cleans JSON response by removing markdown code blocks
    /// </summary>
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
}
