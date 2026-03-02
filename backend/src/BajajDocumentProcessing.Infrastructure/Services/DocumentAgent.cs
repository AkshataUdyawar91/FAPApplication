using Azure;
using Azure.AI.OpenAI;
using Azure.AI.FormRecognizer.DocumentAnalysis;
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
/// Document Agent service for document classification and field extraction
/// </summary>
public class DocumentAgent : IDocumentAgent
{
    private readonly OpenAIClient _openAIClient;
    private readonly DocumentAnalysisClient _documentAnalysisClient;
    private readonly string _deploymentName;
    private readonly ILogger<DocumentAgent> _logger;
    private readonly HttpClient _httpClient;
    private const double CONFIDENCE_THRESHOLD = 0.70;
    private const double FIELD_CONFIDENCE_THRESHOLD = 0.60;

    public DocumentAgent(
        IConfiguration configuration,
        ILogger<DocumentAgent> logger,
        HttpClient httpClient)
    {
        _logger = logger;
        _httpClient = httpClient;

        var endpoint = configuration["AzureOpenAI:Endpoint"] 
            ?? throw new InvalidOperationException("Azure OpenAI endpoint not configured");
        var apiKey = configuration["AzureOpenAI:ApiKey"] 
            ?? throw new InvalidOperationException("Azure OpenAI API key not configured");
        _deploymentName = configuration["AzureOpenAI:DeploymentName"] ?? "gpt-4";

        _openAIClient = new OpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));

        var docIntelEndpoint = configuration["AzureDocumentIntelligence:Endpoint"] 
            ?? throw new InvalidOperationException("Azure Document Intelligence endpoint not configured");
        var docIntelApiKey = configuration["AzureDocumentIntelligence:ApiKey"] 
            ?? throw new InvalidOperationException("Azure Document Intelligence API key not configured");

        _documentAnalysisClient = new DocumentAnalysisClient(
            new Uri(docIntelEndpoint), 
            new AzureKeyCredential(docIntelApiKey));
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
                    new ChatRequestUserMessage($"Please classify this document. Image URL: {blobUrl}")
                },
                MaxTokens = 500,
                Temperature = 0.1f // Low temperature for consistent classification
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
        public string TypeString { get; set; } = string.Empty;
        public DocumentType Type { get; set; }
        public double Confidence { get; set; }
        public string Reasoning { get; set; } = string.Empty;

        // For JSON deserialization
        public string type
        {
            get => TypeString;
            set => TypeString = value;
        }

        public double confidence
        {
            get => Confidence;
            set => Confidence = value;
        }

        public string reasoning
        {
            get => Reasoning;
            set => Reasoning = value;
        }
    }

    /// <summary>
    /// Extracts structured data from a Purchase Order document
    /// </summary>
    public async Task<POData> ExtractPOAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting PO extraction for URL: {BlobUrl}", blobUrl);

            var operation = await _documentAnalysisClient.AnalyzeDocumentFromUriAsync(
                WaitUntil.Completed,
                "prebuilt-invoice", // Using prebuilt invoice model for PO extraction
                new Uri(blobUrl),
                cancellationToken: cancellationToken);

            var result = operation.Value;
            var poData = new POData();
            var fieldConfidences = new Dictionary<string, double>();

            // Extract from the first document
            if (result.Documents.Count > 0)
            {
                var document = result.Documents[0];

                // Extract PO Number (using InvoiceId field)
                if (document.Fields.TryGetValue("InvoiceId", out var poNumberField) && poNumberField.Content != null)
                {
                    poData.PONumber = poNumberField.Content;
                    fieldConfidences["PONumber"] = poNumberField.Confidence ?? 0.0;
                }

                // Extract Vendor Name
                if (document.Fields.TryGetValue("VendorName", out var vendorField) && vendorField.Content != null)
                {
                    poData.VendorName = vendorField.Content;
                    fieldConfidences["VendorName"] = vendorField.Confidence ?? 0.0;
                }

                // Extract PO Date (using InvoiceDate)
                if (document.Fields.TryGetValue("InvoiceDate", out var dateField))
                {
                    var dateValue = dateField.Value?.AsDate();
                    if (dateValue.HasValue)
                    {
                        poData.PODate = dateValue.Value.DateTime;
                        fieldConfidences["PODate"] = dateField.Confidence ?? 0.0;
                    }
                }

                // Extract Total Amount
                if (document.Fields.TryGetValue("InvoiceTotal", out var totalField))
                {
                    var currencyValue = totalField.Value?.AsCurrency();
                    if (currencyValue.HasValue)
                    {
                        poData.TotalAmount = (decimal)currencyValue.Value.Amount;
                        fieldConfidences["TotalAmount"] = totalField.Confidence ?? 0.0;
                    }
                }

                // Extract Line Items
                if (document.Fields.TryGetValue("Items", out var itemsField))
                {
                    var items = itemsField.Value?.AsList();
                    if (items != null)
                    {
                        foreach (var item in items)
                        {
                            var itemDict = item.Value?.AsDictionary();
                            if (itemDict != null)
                            {
                                var lineItem = new POLineItem();

                                if (itemDict.TryGetValue("ProductCode", out var codeField) && codeField.Content != null)
                                    lineItem.ItemCode = codeField.Content;

                                if (itemDict.TryGetValue("Description", out var descField) && descField.Content != null)
                                    lineItem.Description = descField.Content;

                                if (itemDict.TryGetValue("Quantity", out var qtyField))
                                {
                                    var qtyValue = qtyField.Value?.AsDouble();
                                    if (qtyValue.HasValue)
                                        lineItem.Quantity = (int)qtyValue.Value;
                                }

                                if (itemDict.TryGetValue("UnitPrice", out var priceField))
                                {
                                    var priceValue = priceField.Value?.AsCurrency();
                                    if (priceValue.HasValue)
                                        lineItem.UnitPrice = (decimal)priceValue.Value.Amount;
                                }

                                if (itemDict.TryGetValue("Amount", out var amountField))
                                {
                                    var amountValue = amountField.Value?.AsCurrency();
                                    if (amountValue.HasValue)
                                        lineItem.LineTotal = (decimal)amountValue.Value.Amount;
                                }

                                poData.LineItems.Add(lineItem);
                            }
                        }
                        fieldConfidences["LineItems"] = itemsField.Confidence ?? 0.0;
                    }
                }
            }

            poData.FieldConfidences = fieldConfidences;

            // Calculate overall document confidence and flag if below threshold
            var documentConfidence = CalculateDocumentConfidence(fieldConfidences);
            poData.IsFlaggedForReview = documentConfidence < CONFIDENCE_THRESHOLD;

            _logger.LogInformation(
                "PO extraction completed. PO Number: {PONumber}, Line Items: {ItemCount}, Confidence: {Confidence}, Flagged: {Flagged}",
                poData.PONumber, poData.LineItems.Count, documentConfidence, poData.IsFlaggedForReview);

            return poData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting PO data from URL: {BlobUrl}", blobUrl);
            throw;
        }
    }

    /// <summary>
    /// Extracts structured data from an Invoice document
    /// </summary>
    public async Task<InvoiceData> ExtractInvoiceAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Invoice extraction for URL: {BlobUrl}", blobUrl);

            var operation = await _documentAnalysisClient.AnalyzeDocumentFromUriAsync(
                WaitUntil.Completed,
                "prebuilt-invoice",
                new Uri(blobUrl),
                cancellationToken: cancellationToken);

            var result = operation.Value;
            var invoiceData = new InvoiceData();
            var fieldConfidences = new Dictionary<string, double>();

            if (result.Documents.Count > 0)
            {
                var document = result.Documents[0];

                // Extract Invoice Number
                if (document.Fields.TryGetValue("InvoiceId", out var invoiceIdField) && invoiceIdField.Content != null)
                {
                    invoiceData.InvoiceNumber = invoiceIdField.Content;
                    fieldConfidences["InvoiceNumber"] = invoiceIdField.Confidence ?? 0.0;
                }

                // Extract Vendor Name
                if (document.Fields.TryGetValue("VendorName", out var vendorField) && vendorField.Content != null)
                {
                    invoiceData.VendorName = vendorField.Content;
                    fieldConfidences["VendorName"] = vendorField.Confidence ?? 0.0;
                }

                // Extract Invoice Date
                if (document.Fields.TryGetValue("InvoiceDate", out var dateField))
                {
                    var dateValue = dateField.Value?.AsDate();
                    if (dateValue.HasValue)
                    {
                        invoiceData.InvoiceDate = dateValue.Value.DateTime;
                        fieldConfidences["InvoiceDate"] = dateField.Confidence ?? 0.0;
                    }
                }

                // Extract SubTotal
                if (document.Fields.TryGetValue("SubTotal", out var subTotalField))
                {
                    var subTotalValue = subTotalField.Value?.AsCurrency();
                    if (subTotalValue.HasValue)
                    {
                        invoiceData.SubTotal = (decimal)subTotalValue.Value.Amount;
                        fieldConfidences["SubTotal"] = subTotalField.Confidence ?? 0.0;
                    }
                }

                // Extract Tax Amount
                if (document.Fields.TryGetValue("TotalTax", out var taxField))
                {
                    var taxValue = taxField.Value?.AsCurrency();
                    if (taxValue.HasValue)
                    {
                        invoiceData.TaxAmount = (decimal)taxValue.Value.Amount;
                        fieldConfidences["TaxAmount"] = taxField.Confidence ?? 0.0;
                    }
                }

                // Extract Total Amount
                if (document.Fields.TryGetValue("InvoiceTotal", out var totalField))
                {
                    var totalValue = totalField.Value?.AsCurrency();
                    if (totalValue.HasValue)
                    {
                        invoiceData.TotalAmount = (decimal)totalValue.Value.Amount;
                        fieldConfidences["TotalAmount"] = totalField.Confidence ?? 0.0;
                    }
                }

                // Extract Line Items
                if (document.Fields.TryGetValue("Items", out var itemsField))
                {
                    var items = itemsField.Value?.AsList();
                    if (items != null)
                    {
                        foreach (var item in items)
                        {
                            var itemDict = item.Value?.AsDictionary();
                            if (itemDict != null)
                            {
                                var lineItem = new InvoiceLineItem();

                                if (itemDict.TryGetValue("ProductCode", out var codeField) && codeField.Content != null)
                                    lineItem.ItemCode = codeField.Content;

                                if (itemDict.TryGetValue("Description", out var descField) && descField.Content != null)
                                    lineItem.Description = descField.Content;

                                if (itemDict.TryGetValue("Quantity", out var qtyField))
                                {
                                    var qtyValue = qtyField.Value?.AsDouble();
                                    if (qtyValue.HasValue)
                                        lineItem.Quantity = (int)qtyValue.Value;
                                }

                                if (itemDict.TryGetValue("UnitPrice", out var priceField))
                                {
                                    var priceValue = priceField.Value?.AsCurrency();
                                    if (priceValue.HasValue)
                                        lineItem.UnitPrice = (decimal)priceValue.Value.Amount;
                                }

                                if (itemDict.TryGetValue("Amount", out var amountField))
                                {
                                    var amountValue = amountField.Value?.AsCurrency();
                                    if (amountValue.HasValue)
                                        lineItem.LineTotal = (decimal)amountValue.Value.Amount;
                                }

                                invoiceData.LineItems.Add(lineItem);
                            }
                        }
                        fieldConfidences["LineItems"] = itemsField.Confidence ?? 0.0;
                    }
                }
            }

            invoiceData.FieldConfidences = fieldConfidences;

            // Calculate overall document confidence and flag if below threshold
            var documentConfidence = CalculateDocumentConfidence(fieldConfidences);
            invoiceData.IsFlaggedForReview = documentConfidence < CONFIDENCE_THRESHOLD;

            _logger.LogInformation(
                "Invoice extraction completed. Invoice Number: {InvoiceNumber}, Line Items: {ItemCount}, Confidence: {Confidence}, Flagged: {Flagged}",
                invoiceData.InvoiceNumber, invoiceData.LineItems.Count, documentConfidence, invoiceData.IsFlaggedForReview);

            return invoiceData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting Invoice data from URL: {BlobUrl}", blobUrl);
            throw;
        }
    }

    /// <summary>
    /// Extracts structured data from a Cost Summary document
    /// </summary>
    public async Task<CostSummaryData> ExtractCostSummaryAsync(string blobUrl, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Cost Summary extraction for URL: {BlobUrl}", blobUrl);

            // Use general document model for cost summaries (could be spreadsheets or PDFs)
            var operation = await _documentAnalysisClient.AnalyzeDocumentFromUriAsync(
                WaitUntil.Completed,
                "prebuilt-document",
                new Uri(blobUrl),
                cancellationToken: cancellationToken);

            var result = operation.Value;
            var costSummaryData = new CostSummaryData();
            var fieldConfidences = new Dictionary<string, double>();

            // Extract key-value pairs and tables
            if (result.KeyValuePairs.Count > 0)
            {
                foreach (var kvp in result.KeyValuePairs)
                {
                    var key = kvp.Key.Content?.ToLower() ?? "";
                    var value = kvp.Value.Content ?? "";
                    var confidence = kvp.Confidence;

                    if (key.Contains("campaign") && key.Contains("name"))
                    {
                        costSummaryData.CampaignName = value;
                        fieldConfidences["CampaignName"] = confidence;
                    }
                    else if (key.Contains("state"))
                    {
                        costSummaryData.State = value;
                        fieldConfidences["State"] = confidence;
                    }
                    else if (key.Contains("start") && key.Contains("date"))
                    {
                        if (DateTime.TryParse(value, out var startDate))
                        {
                            costSummaryData.CampaignStartDate = startDate;
                            fieldConfidences["CampaignStartDate"] = confidence;
                        }
                    }
                    else if (key.Contains("end") && key.Contains("date"))
                    {
                        if (DateTime.TryParse(value, out var endDate))
                        {
                            costSummaryData.CampaignEndDate = endDate;
                            fieldConfidences["CampaignEndDate"] = confidence;
                        }
                    }
                    else if (key.Contains("total") && key.Contains("cost"))
                    {
                        var cleanValue = value.Replace("$", "").Replace(",", "").Trim();
                        if (decimal.TryParse(cleanValue, out var totalCost))
                        {
                            costSummaryData.TotalCost = totalCost;
                            fieldConfidences["TotalCost"] = confidence;
                        }
                    }
                }
            }

            // Extract cost breakdowns from tables
            if (result.Tables.Count > 0)
            {
                var table = result.Tables[0]; // Use first table
                
                // Find category and amount columns
                int categoryCol = -1;
                int amountCol = -1;

                for (int i = 0; i < table.ColumnCount; i++)
                {
                    var headerCell = table.Cells.FirstOrDefault(c => c.RowIndex == 0 && c.ColumnIndex == i);
                    if (headerCell != null)
                    {
                        var headerText = headerCell.Content.ToLower();
                        if (headerText.Contains("category") || headerText.Contains("item"))
                            categoryCol = i;
                        else if (headerText.Contains("amount") || headerText.Contains("cost"))
                            amountCol = i;
                    }
                }

                if (categoryCol >= 0 && amountCol >= 0)
                {
                    for (int row = 1; row < table.RowCount; row++)
                    {
                        var categoryCell = table.Cells.FirstOrDefault(c => c.RowIndex == row && c.ColumnIndex == categoryCol);
                        var amountCell = table.Cells.FirstOrDefault(c => c.RowIndex == row && c.ColumnIndex == amountCol);

                        if (categoryCell != null && amountCell != null)
                        {
                            var category = categoryCell.Content;
                            var amountStr = amountCell.Content.Replace("$", "").Replace(",", "").Trim();
                            
                            if (decimal.TryParse(amountStr, out var amount))
                            {
                                costSummaryData.CostBreakdowns.Add(new CostBreakdown
                                {
                                    Category = category,
                                    Amount = amount
                                });
                            }
                        }
                    }
                    fieldConfidences["CostBreakdowns"] = 0.85; // Table extraction confidence
                }
            }

            costSummaryData.FieldConfidences = fieldConfidences;

            // Calculate overall document confidence and flag if below threshold
            var documentConfidence = CalculateDocumentConfidence(fieldConfidences);
            costSummaryData.IsFlaggedForReview = documentConfidence < CONFIDENCE_THRESHOLD;

            _logger.LogInformation(
                "Cost Summary extraction completed. Campaign: {Campaign}, Cost Breakdowns: {BreakdownCount}, Confidence: {Confidence}, Flagged: {Flagged}",
                costSummaryData.CampaignName, costSummaryData.CostBreakdowns.Count, documentConfidence, costSummaryData.IsFlaggedForReview);

            return costSummaryData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting Cost Summary data from URL: {BlobUrl}", blobUrl);
            throw;
        }
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
}
