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
    private readonly AzureDocumentIntelligenceService _documentIntelligenceService;
    private const double CONFIDENCE_THRESHOLD = 0.70;
    private const double FIELD_CONFIDENCE_THRESHOLD = 0.60;

    public DocumentAgent(
        IConfiguration configuration,
        ILogger<DocumentAgent> logger,
        HttpClient httpClient,
        IFileStorageService fileStorageService,
        AzureDocumentIntelligenceService documentIntelligenceService)
    {
        _logger = logger;
        _httpClient = httpClient;
        _fileStorageService = fileStorageService;
        _documentIntelligenceService = documentIntelligenceService;

        var endpoint = configuration["AzureOpenAI:Endpoint"] 
            ?? throw new InvalidOperationException("Azure OpenAI endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] 
            ?? throw new InvalidOperationException("Azure OpenAI API key not configured");
        _deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        _openAIClient = new OpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
    }

    /// <summary>
    /// Checks if the file is a document type that requires Azure Document Intelligence
    /// </summary>
    private bool IsDocumentFile(string blobUrl)
    {
        var lowerUrl = blobUrl.ToLowerInvariant();
        return lowerUrl.EndsWith(".pdf") || 
               lowerUrl.EndsWith(".doc") || 
               lowerUrl.EndsWith(".docx");
    }

    /// <summary>
    /// Checks if the file is an image that can be processed by Vision API
    /// </summary>
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
    /// Prepares image data for Azure OpenAI Vision API
    /// For files larger than 100KB, uses SAS URL instead of data URI to avoid URI length limits
    /// Returns null for non-image files (PDFs, Word docs)
    /// </summary>
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
    /// Creates a ChatMessageImageContentItem from a URL (either data URI or HTTPS URL with SAS)
    /// </summary>
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
    /// Classifies a document using Azure OpenAI GPT-4 Vision for images
    /// For PDFs/Word docs, returns classification based on user's document type selection
    /// </summary>
    public async Task<DocumentClassification> ClassifyAsync(
        string blobUrl, 
        CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting document classification for URL: {BlobUrl}", blobUrl);

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
                    Type = DocumentType.AdditionalDocument,
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
    /// Extracts structured data from a Purchase Order document
    /// Uses Azure Document Intelligence for PDFs/Word docs, GPT-4 Vision for images
    /// </summary>
    public async Task<POData> ExtractPOAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting PO extraction for URL: {BlobUrl}", blobUrl);

            // For document files (PDF, Word), use Azure Document Intelligence
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected - using Azure Document Intelligence for extraction");
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                var result = await _documentIntelligenceService.ExtractPOAsync(new Uri(sasUrl), cancellationToken);
                _logger.LogInformation(
                    "Document Intelligence extraction completed. PO: {PONumber}, Amount: {Amount}",
                    result.PONumber, result.TotalAmount);
                return result;
            }

            // For images, use GPT-4 Vision
            var imageData = await PrepareImageDataAsync(blobUrl);
            
            if (imageData == null)
            {
                _logger.LogWarning("Could not prepare image data for PO extraction");
                return new POData
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
                    new ChatRequestSystemMessage(@"You are a Purchase Order data extraction expert with exceptional OCR capabilities.
Carefully analyze the provided PO document image and extract ALL visible information with high accuracy.

CRITICAL INSTRUCTIONS:
1. Extract EXACT values as they appear in the document
2. For PO numbers, look for fields labeled 'PO Number', 'Purchase Order', 'PO No', etc.
3. Extract all line items with complete details
4. Pay attention to totals, subtotals, and tax amounts

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

            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received PO extraction response: {Response}", content);

            var poData = ParsePOResponse(content);

            _logger.LogInformation(
                "PO extraction completed. PO Number: {PONumber}, Total Amount: {TotalAmount}, Line Items: {ItemCount}, Flagged: {Flagged}",
                poData.PONumber, poData.TotalAmount, poData.LineItems.Count, poData.IsFlaggedForReview);

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
    /// Extracts structured data from an Invoice document
    /// Uses Azure Document Intelligence for PDFs/Word docs, GPT-4 Vision for images
    /// </summary>
    public async Task<InvoiceData> ExtractInvoiceAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Invoice extraction for URL: {BlobUrl}", blobUrl);

            // For document files (PDF, Word), use Azure Document Intelligence
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected - using Azure Document Intelligence for extraction");
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                var result = await _documentIntelligenceService.ExtractInvoiceAsync(new Uri(sasUrl), cancellationToken);
                _logger.LogInformation(
                    "Document Intelligence extraction completed. Invoice: {InvoiceNumber}, Amount: {Amount}",
                    result.InvoiceNumber, result.TotalAmount);
                return result;
            }

            // For images, use GPT-4 Vision
            var imageData = await PrepareImageDataAsync(blobUrl);
            
            if (imageData == null)
            {
                _logger.LogWarning("Could not prepare image data for invoice extraction");
                return new InvoiceData
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
                    new ChatRequestSystemMessage(@"You are an Invoice data extraction expert with exceptional OCR capabilities.
Carefully analyze the provided invoice document image and extract ALL visible information with high accuracy.

CRITICAL INSTRUCTIONS:
1. Look for fields labeled 'Total', 'Tot Inv. Amt', 'Total Amount', 'Grand Total', 'Invoice Total', or similar
2. Extract the EXACT numeric values you see, including decimals
3. For invoice numbers, look for fields labeled 'Invoice No', 'Invoice Number', 'Bill No', etc.
4. Pay special attention to tables and line items
5. If you see multiple totals (like 'Total' and 'Tot Inv. Amt'), use the larger/final total amount

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
Extract EVERY field you can see. Do not leave fields empty if data is visible in the image."),
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

            var content = response.Value.Choices[0].Message.Content;
            _logger.LogInformation("Received Invoice extraction response: {Response}", content);

            var invoiceData = ParseInvoiceResponse(content);

            _logger.LogInformation(
                "Invoice extraction completed. Invoice Number: {InvoiceNumber}, Total Amount: {TotalAmount}, Line Items: {ItemCount}, Flagged: {Flagged}",
                invoiceData.InvoiceNumber, invoiceData.TotalAmount, invoiceData.LineItems.Count, invoiceData.IsFlaggedForReview);

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
    /// Extracts structured data from a Cost Summary document
    /// Uses Azure Document Intelligence for PDFs/Word docs, GPT-4 Vision for images
    /// </summary>
    public async Task<CostSummaryData> ExtractCostSummaryAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Cost Summary extraction for URL: {BlobUrl}", blobUrl);

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
                    new ChatRequestSystemMessage(@"You are a Cost Summary data extraction expert with exceptional OCR capabilities.
Carefully analyze the provided cost summary document image and extract ALL visible information with high accuracy.

CRITICAL INSTRUCTIONS:
1. Extract EXACT values as they appear in the document
2. Look for campaign details, dates, and cost breakdowns
3. Extract all cost categories and their amounts
4. Pay attention to totals and subtotals

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
Extract EVERY field you can see. Do not leave fields empty if data is visible in the image."),
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
                "Cost Summary extraction completed. Campaign: {Campaign}, Total Cost: {TotalCost}, Cost Breakdowns: {BreakdownCount}, Flagged: {Flagged}",
                costSummaryData.CampaignName, costSummaryData.TotalCost, costSummaryData.CostBreakdowns.Count, costSummaryData.IsFlaggedForReview);

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

    /// <summary>
    /// Extracts text from PDF using Azure Document Intelligence
    /// </summary>
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
                new ChatRequestSystemMessage(@"You are a Cost Summary data extraction expert.
Analyze the provided text extracted from a cost summary document and extract structured information.

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
}"),
                new ChatRequestUserMessage($"Extract cost summary data from this text:\n\n{extractedText}")
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
}
