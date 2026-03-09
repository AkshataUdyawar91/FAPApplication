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

            // CHANGE: Switched from direct Document Intelligence to hybrid approach (Doc Intelligence extracts text → OpenAI analyzes text)
            // For document files (PDF, Word), use Azure Document Intelligence to extract text, then OpenAI to analyze
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected - using hybrid extraction (Document Intelligence + OpenAI)");
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                
                try
                {
                    // CHANGE: Extract raw text from PDF using Document Intelligence
                    var extractedText = await ExtractTextFromPdfAsync(new Uri(sasUrl), cancellationToken);
                    
                    // CHANGE: Send extracted text to OpenAI for detailed field extraction
                    var result = await AnalyzePOTextAsync(extractedText, cancellationToken);
                    _logger.LogInformation(
                        "PO hybrid extraction completed. PO: {PONumber}, Amount: {Amount}",
                        result.PONumber, result.TotalAmount);
                    return result;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in hybrid PO extraction, falling back to Document Intelligence only");
                    var result = await _documentIntelligenceService.ExtractPOAsync(new Uri(sasUrl), cancellationToken);
                    return result;
                }
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
    /// Extracts structured data from an Invoice document
    /// Uses Azure Document Intelligence for PDFs/Word docs, GPT-4 Vision for images
    /// </summary>
    public async Task<InvoiceData> ExtractInvoiceAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Invoice extraction for URL: {BlobUrl}", blobUrl);

            // CHANGE: Switched from direct Document Intelligence to hybrid approach (Doc Intelligence extracts text → OpenAI analyzes text)
            // For document files (PDF, Word), use Azure Document Intelligence to extract text, then OpenAI to analyze
            if (IsDocumentFile(blobUrl))
            {
                _logger.LogInformation("Document file detected - using hybrid extraction (Document Intelligence + OpenAI)");
                var sasUrl = await _fileStorageService.GetPublicUrlWithSasAsync(blobUrl, TimeSpan.FromHours(1));
                
                try
                {
                    // CHANGE: Extract raw text from PDF using Document Intelligence
                    var extractedText = await ExtractTextFromPdfAsync(new Uri(sasUrl), cancellationToken);
                    
                    // CHANGE: Send extracted text to OpenAI for detailed field extraction
                    var result = await AnalyzeInvoiceTextAsync(extractedText, cancellationToken);
                    _logger.LogInformation(
                        "Invoice hybrid extraction completed. Invoice: {InvoiceNumber}, Amount: {Amount}",
                        result.InvoiceNumber, result.TotalAmount);
                    return result;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in hybrid invoice extraction, falling back to Document Intelligence only");
                    var result = await _documentIntelligenceService.ExtractInvoiceAsync(new Uri(sasUrl), cancellationToken);
                    return result;
                }
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
                    new ChatRequestSystemMessage(@"You are an AI Invoice Data Extraction Engine specialized in invoices.

Your task is to analyze OCR-extracted text from an invoice document and extract structured information with maximum accuracy.

Extract only the information present in the document. Do NOT guess or hallucinate values.

Think step-by-step and carefully verify each extracted value before producing the final JSON output.

--------------------------------------------------
STEP 1 — UNDERSTAND DOCUMENT STRUCTURE
--------------------------------------------------

First analyze the invoice text and identify these sections if present:

1. Vendor / Supplier details
2. Customer / Agency details
3. Billing information (Bill To)
4. Invoice metadata (Invoice number, invoice date)
5. GST information
6. Purchase order references
7. Line item table
8. Tax summary and totals

After identifying these sections, extract the required fields.

--------------------------------------------------
STEP 2 — INVOICE METADATA
--------------------------------------------------

Extract the Invoice Number.

Look for keywords:
Invoice No
Invoice Number
Inv No
Bill No
Tax Invoice No

Return the exact value.

Extract the Invoice Date and normalize it to ISO format:

YYYY-MM-DD

Handle formats like:
12/03/2025
12-03-25
12 March 2025
Mar 12 2025

--------------------------------------------------
STEP 3 — AGENCY / CUSTOMER DETAILS
--------------------------------------------------

Extract:
Agency Name
Agency Address
Agency Code

Possible labels:
Customer
Client
Agency
Ship To
Consignee

Agency Code is typically:
Alphanumeric
Length between 4–10 characters

Example:
AGT104
CUS9087

--------------------------------------------------
STEP 4 — BILLING DETAILS
--------------------------------------------------

Extract:
Billing Name
Billing Address

Look near sections labeled:
Bill To
Billed To
Invoice To
Billing Address

Billing name may be the same as agency name.

--------------------------------------------------
STEP 5 — VENDOR / SUPPLIER DETAILS
--------------------------------------------------

Extract:
Vendor Name
Vendor Code

Look near:
Supplier
Vendor
Company Name
Registered Office
From

Vendor code may appear close to the vendor name.

--------------------------------------------------
STEP 6 — GST INFORMATION (CRITICAL)
--------------------------------------------------

Extract the GSTIN.

GSTIN format:
15 characters

Example:
27ABCDE1234F1Z5

Structure:
First 2 digits = State Code
Next 10 = PAN
Next 1 = Entity number
Next 1 = Z
Last 1 = checksum

Rules:
Extract the first valid GSTIN.
If both vendor and customer GSTIN exist, prefer Vendor GSTIN.

Also extract:
State Code → first two digits of GSTIN
State Name → derive using state code

Example state mapping:
27 = Maharashtra
29 = Karnataka
07 = Delhi
33 = Tamil Nadu
24 = Gujarat
19 = West Bengal

--------------------------------------------------
STEP 7 — HSN / SAC CODE
--------------------------------------------------

Extract the HSN or SAC code.

Possible labels:
HSN
SAC
HSN/SAC
HSN Code

Typical formats:
9983
998314
847130

Remove spaces if present.

--------------------------------------------------
STEP 8 — PURCHASE ORDER NUMBER
--------------------------------------------------

Extract PO Number.

Look for:
PO No
PO Number
Purchase Order
PO Ref
Ref PO
Purchase No

Return the first valid PO reference.

--------------------------------------------------
STEP 9 — TAX DETAILS
--------------------------------------------------

Extract:
GST Percentage
Tax Amount
Sub Total
Total Amount

Common GST rates:
5
12
18
28

Currency normalization:
Remove symbols like:
₹
INR
Rs.
,

Example:
₹12,450.00 → 12450

Total Amount Rule:
If multiple totals exist, select the FINAL payable amount or the largest value.

Ignore:
Round Off
Adjustment
Discount

--------------------------------------------------
STEP 10 — LINE ITEM TABLE EXTRACTION
--------------------------------------------------

Identify the invoice item table.

Possible headers:
Description
Item
Product
Qty
Quantity
Rate
Unit Price
Amount
HSN
GST

Extract ALL rows.

For each line item extract:

description
quantity
unit_price
amount
hsn_sac_code
gst_percentage

Rules:
Quantity must be numeric.
Unit price must be numeric.
Amount must be numeric.

If any field is missing, return empty or zero.

--------------------------------------------------
STEP 11 — CROSS VALIDATION
--------------------------------------------------

Validate totals:

Sub Total + Tax Amount ≈ Total Amount

If mismatch occurs, prefer the explicit totals shown in the invoice summary.

--------------------------------------------------
STEP 12 — MISSING FIELD HANDLING
--------------------------------------------------

If a field is not present in the document:

Return:
"" for text fields
0 for numeric fields

--------------------------------------------------
STEP 13 — OUTPUT JSON SCHEMA
--------------------------------------------------

Return ONLY valid JSON in the following structure:

{
  ""invoice_number"": "" "",
  ""invoice_date"": "" "",
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
}

--------------------------------------------------
STEP 14 — CONFIDENCE SCORE
--------------------------------------------------

Return a confidence score between 0.0 and 1.0.

Guidelines:

0.9 – 1.0 → Clear structured invoice  
0.75 – 0.9 → Minor OCR noise  
0.6 – 0.75 → Some fields missing  
0.4 – 0.6 → Partial extraction  
<0.4 → Poor quality OCR

--------------------------------------------------
FINAL RULES
--------------------------------------------------

Return ONLY valid JSON.

Do NOT include explanations.
Do NOT add extra text.
Do NOT invent values.

Ensure the JSON strictly follows the schema above."),

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

            // CHANGE: Added mapping for all new fields (Agency, Billing, GST, HSN, PO, State, VendorCode)
            var invoiceData = new InvoiceData
            {
                InvoiceNumber = parsed.InvoiceNumber ?? string.Empty,
                VendorName = parsed.VendorName ?? string.Empty,
                VendorCode = parsed.VendorCode ?? string.Empty,
                InvoiceDate = parsed.InvoiceDate ?? DateTime.Now,
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
        public DateTime? InvoiceDate { get; set; }
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
    /// Extracts EXIF metadata from a photo
    /// </summary>
    public async Task<PhotoMetadata> ExtractPhotoMetadataAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting photo metadata extraction for URL: {BlobUrl}", blobUrl);

            // Download the image using file storage service (handles authentication)
            var imageBytes = await _fileStorageService.GetFileBytesAsync(blobUrl);
            
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

    // CHANGE: Added new method - Analyzes photo using OpenAI Vision to detect blue tshirt, 3W vehicle, and read GPS overlay
    /// <summary>
    /// Analyzes photo content using GPT-4 Vision
    /// </summary>
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
  ""locationText"": ""string""
}

If GPS overlay is not visible, set photoDateFromOverlay to empty string and lat/long to null."),
                new ChatRequestUserMessage(
                    new ChatMessageContentItem[]
                    {
                        new ChatMessageTextContentItem("Analyze this campaign photo. Detect: 1) People with blue t-shirt (count them), 2) Any 3-wheel vehicle, 3) Read GPS overlay text if visible (date, lat/long, location)."),
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
    /// Analyzes extracted text using GPT-4 to extract Invoice data
    /// </summary>
    private async Task<InvoiceData> AnalyzeInvoiceTextAsync(string extractedText, CancellationToken cancellationToken)
    {
        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are an Invoice data extraction expert specializing in invoices.
Analyze the provided text extracted from an invoice document and extract ALL structured information with maximum accuracy.

REQUIRED FIELDS TO EXTRACT:
1. Invoice Number - Look for: 'Invoice No', 'Invoice Number', 'Bill No', 'Inv No', 'Document No'
2. Invoice Date - Date of invoice (format: YYYY-MM-DD)
3. Agency Name - Name of the agency/customer/recipient receiving the invoice
4. Agency Address - Full address of the agency/recipient
5. Agency Code - Agency identifier code (alphanumeric, 4-10 characters)
6. Billing Name - Bill to party name (may be same as agency)
7. Billing Address - Bill to address
8. Vendor Name - Supplier/vendor company name (look near 'Supplier', 'From', 'M/S')
9. Vendor Code - Vendor identifier code
10. State Name - State where service/goods supplied (e.g., 'Maharashtra', 'Bihar', 'Karnataka')
11. State Code - 2-digit state code (e.g., '27' for Maharashtra, '10' for Bihar)
12. GST Number - 15-character GSTIN (format: 2 digits state + 10 chars PAN + 1 digit + 1 letter + 1 check)
13. GST Percentage - GST rate applied (common: 5, 12, 18, 28)
14. HSN/SAC Code - 4-8 digit code for goods/services classification
15. PO Number - Reference Purchase Order number
16. Sub Total - Amount before tax (look for 'Taxable Amount', 'Sub Total')
17. Tax Amount - Total GST/tax amount (CGST + SGST or IGST)
18. Total Amount - Final invoice amount (look for 'Tot Inv. Amt', 'Grand Total', 'Total')
19. Line Items - ALL items with description, quantity, unit price, amount, HSN, GST%

CRITICAL INSTRUCTIONS FOR INDIAN INVOICES:
- GSTIN: Must be 15 characters. First 2 digits = state code.
- If both supplier and recipient GSTIN exist, extract SUPPLIER GSTIN as gstNumber.
- State Code: First 2 digits of GSTIN. Common: 10=Bihar, 27=Maharashtra, 29=Karnataka, 07=Delhi, 33=Tamil Nadu.
- State Name: Derive from state code or 'Place of Supply' field.
- HSN/SAC Code: Usually in the line items table header.
- Total Amount: If multiple totals exist, use the FINAL payable amount.
- Agency = Recipient/Customer/Bill To party.
- If a field is not found, use empty string for text, 0 for numbers.

Respond ONLY with a JSON object in this exact format:
{
  ""invoiceNumber"": ""string"",
  ""invoiceDate"": ""YYYY-MM-DD"",
  ""agencyName"": ""string"",
  ""agencyAddress"": ""string"",
  ""agencyCode"": ""string"",
  ""billingName"": ""string"",
  ""billingAddress"": ""string"",
  ""vendorName"": ""string"",
  ""vendorCode"": ""string"",
  ""stateName"": ""string"",
  ""stateCode"": ""string"",
  ""gstNumber"": ""string"",
  ""gstPercentage"": 0,
  ""hsnSacCode"": ""string"",
  ""poNumber"": ""string"",
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
}"),
                new ChatRequestUserMessage($"Extract all invoice data from this text:\n\n{extractedText}")
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        _logger.LogInformation("Received Invoice text analysis response: {Response}", content);
        
        return ParseInvoiceResponse(content);
    }

    // CHANGE: Expanded PO text analysis prompt to extract all fields like Invoice
    /// <summary>
    /// Analyzes extracted text using GPT-4 to extract PO data
    /// </summary>
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
        // CHANGE: Truncate text if too large to avoid token limits — send first 30000 chars
        var textToSend = extractedText.Length > 30000 ? extractedText.Substring(0, 30000) : extractedText;
        DebugLog($"[ENQUIRY] Sending text length: {textToSend.Length} (original: {extractedText.Length})");

        var chatCompletionsOptions = new ChatCompletionsOptions
        {
            DeploymentName = _deploymentName,
            Messages =
            {
                new ChatRequestSystemMessage(@"You are a data extraction expert. Extract structured records from the tabular text below.

The text is from an Excel file with enquiry records. The columns may include:
Sr No, Date, Dealership Name, District, Segment, Company Name, Brand, Address, Principal Name, Contact, Secondary Name, Contact, 3W, EV, 4W, Total Van, Category, Remark, Age, Test Drive, Visit, and possibly others.

For EACH row, extract these fields (map from whatever columns exist):
- state: State name from document context (e.g. Bihar)
- date: Date value, convert to YYYY-MM-DD format
- dealerCode: Dealer code if present, otherwise empty string
- dealerName: Dealership Name or Dealer Name
- district: District
- pincode: Pincode if present, otherwise empty string
- customerName: Principal Name or Company Name or Customer Name
- customerNumber: Contact number (first contact column)
- testRideTaken: Test Drive value, normalize to Yes or No

CRITICAL: Extract EVERY row. Do NOT skip any rows. Do NOT summarize.
If a field is missing, use empty string.

Return ONLY valid JSON:
{
  ""state"": ""overall state"",
  ""totalRecords"": number,
  ""records"": [{""state"":"""",""date"":"""",""dealerCode"":"""",""dealerName"":"""",""district"":"""",""pincode"":"""",""customerName"":"""",""customerNumber"":"""",""testRideTaken"":""""}],
  ""confidence"": 0.8
}"),
                new ChatRequestUserMessage($"Extract ALL records from this data:\n\n{textToSend}")
            }
        };

        var response = await _openAIClient.GetChatCompletionsAsync(chatCompletionsOptions, cancellationToken);
        var content = response.Value.Choices[0].Message.Content;
        // CHANGE: Log raw OpenAI response for debugging
        DebugLog($"[ENQUIRY] OpenAI response length: {content?.Length}, finish reason: {response.Value.Choices[0].FinishReason}");
        DebugLog($"[ENQUIRY] OpenAI response preview: {content?.Substring(0, Math.Min(1000, content?.Length ?? 0))}");
        _logger.LogInformation("Received Enquiry Dump text analysis response length: {Length}", content?.Length);

        return ParseEnquiryDumpResponse(content);
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