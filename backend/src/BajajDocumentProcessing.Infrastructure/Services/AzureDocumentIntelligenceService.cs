using Azure;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using BajajDocumentProcessing.Application.DTOs.Documents;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for extracting data from documents using Azure Document Intelligence
/// </summary>
public class AzureDocumentIntelligenceService
{
    private readonly DocumentAnalysisClient _client;
    private readonly ILogger<AzureDocumentIntelligenceService> _logger;

    public AzureDocumentIntelligenceService(
        IConfiguration configuration,
        ILogger<AzureDocumentIntelligenceService> logger)
    {
        _logger = logger;
        
        var endpoint = configuration["AzureDocumentIntelligence:Endpoint"];
        var apiKey = configuration["AzureDocumentIntelligence:ApiKey"];
        
        if (string.IsNullOrEmpty(endpoint) || string.IsNullOrEmpty(apiKey))
        {
            throw new InvalidOperationException("Azure Document Intelligence configuration is missing");
        }
        
        _client = new DocumentAnalysisClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
    }

    /// <summary>
    /// Extracts invoice data from a PDF using the prebuilt invoice model
    /// </summary>
    public async Task<InvoiceData> ExtractInvoiceAsync(Uri documentUri, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Document Intelligence invoice extraction for: {Uri}", documentUri);

            // Use the prebuilt invoice model
            var operation = await _client.AnalyzeDocumentFromUriAsync(
                WaitUntil.Completed,
                "prebuilt-invoice",
                documentUri,
                cancellationToken: cancellationToken);

            var result = operation.Value;
            
            if (result.Documents.Count == 0)
            {
                _logger.LogWarning("No invoice found in document");
                return CreateEmptyInvoiceData();
            }

            var invoice = result.Documents[0];
            var invoiceData = new InvoiceData
            {
                LineItems = new List<InvoiceLineItem>(),
                FieldConfidences = new Dictionary<string, double>()
            };

            // Extract invoice fields
            if (invoice.Fields.TryGetValue("InvoiceId", out var invoiceId))
            {
                invoiceData.InvoiceNumber = invoiceId.Content;
                invoiceData.FieldConfidences["InvoiceNumber"] = invoiceId.Confidence ?? 0.0;
            }

            if (invoice.Fields.TryGetValue("VendorName", out var vendorName))
            {
                invoiceData.VendorName = vendorName.Content;
                invoiceData.FieldConfidences["VendorName"] = vendorName.Confidence ?? 0.0;
            }

            if (invoice.Fields.TryGetValue("InvoiceDate", out var invoiceDate) && invoiceDate.Value != null)
            {
                invoiceData.InvoiceDate = invoiceDate.Value.AsDate().DateTime;
                invoiceData.FieldConfidences["InvoiceDate"] = invoiceDate.Confidence ?? 0.0;
            }

            if (invoice.Fields.TryGetValue("InvoiceTotal", out var total) && total.Value != null)
            {
                var currency = total.Value.AsCurrency();
                invoiceData.TotalAmount = (decimal)((double?)currency.Amount ?? 0.0);
                invoiceData.FieldConfidences["TotalAmount"] = total.Confidence ?? 0.0;
            }

            if (invoice.Fields.TryGetValue("TotalTax", out var tax) && tax.Value != null)
            {
                var taxCurrency = tax.Value.AsCurrency();
                invoiceData.TaxAmount = (decimal)((double?)taxCurrency.Amount ?? 0.0);
                invoiceData.FieldConfidences["TaxAmount"] = tax.Confidence ?? 0.0;
            }

            // Extract line items
            if (invoice.Fields.TryGetValue("Items", out var items) && items.Value != null)
            {
                var itemsList = items.Value.AsList();
                foreach (var item in itemsList)
                {
                    if (item.Value == null) continue;
                    
                    var itemFields = item.Value.AsDictionary();
                    var lineItem = new InvoiceLineItem();

                    if (itemFields.TryGetValue("ProductCode", out var code))
                        lineItem.ItemCode = code.Content;

                    if (itemFields.TryGetValue("Description", out var desc))
                        lineItem.Description = desc.Content;

                    if (itemFields.TryGetValue("Quantity", out var qty) && qty.Value != null)
                        lineItem.Quantity = (int)((double?)qty.Value.AsDouble() ?? 0.0);

                    if (itemFields.TryGetValue("UnitPrice", out var price) && price.Value != null)
                    {
                        var priceCurrency = price.Value.AsCurrency();
                        lineItem.UnitPrice = (decimal)((double?)priceCurrency.Amount ?? 0.0);
                    }

                    if (itemFields.TryGetValue("Amount", out var amount) && amount.Value != null)
                    {
                        var amountCurrency = amount.Value.AsCurrency();
                        lineItem.LineTotal = (decimal)((double?)amountCurrency.Amount ?? 0.0);
                    }

                    invoiceData.LineItems.Add(lineItem);
                }
            }

            // Calculate overall confidence
            var avgConfidence = invoiceData.FieldConfidences.Values.Any() 
                ? invoiceData.FieldConfidences.Values.Average() 
                : 0.0;
            invoiceData.FieldConfidences["Overall"] = avgConfidence;
            invoiceData.IsFlaggedForReview = avgConfidence < 0.70;

            _logger.LogInformation(
                "Invoice extraction completed. Invoice: {InvoiceNumber}, Total: {Total}, Confidence: {Confidence}",
                invoiceData.InvoiceNumber, invoiceData.TotalAmount, avgConfidence);

            return invoiceData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting invoice with Document Intelligence");
            throw;
        }
    }

    /// <summary>
    /// Extracts purchase order data from a PDF using the prebuilt invoice model
    /// (PO structure is similar to invoice)
    /// </summary>
    public async Task<POData> ExtractPOAsync(Uri documentUri, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Document Intelligence PO extraction for: {Uri}", documentUri);

            var operation = await _client.AnalyzeDocumentFromUriAsync(
                WaitUntil.Completed,
                "prebuilt-invoice",
                documentUri,
                cancellationToken: cancellationToken);

            var result = operation.Value;
            
            if (result.Documents.Count == 0)
            {
                _logger.LogWarning("No PO found in document");
                return CreateEmptyPOData();
            }

            var doc = result.Documents[0];
            var poData = new POData
            {
                LineItems = new List<POLineItem>(),
                FieldConfidences = new Dictionary<string, double>()
            };

            // Extract PO fields (using invoice fields as they're similar)
            if (doc.Fields.TryGetValue("InvoiceId", out var poNumber))
            {
                poData.PONumber = poNumber.Content;
                poData.FieldConfidences["PONumber"] = poNumber.Confidence ?? 0.0;
            }

            if (doc.Fields.TryGetValue("VendorName", out var vendorName))
            {
                poData.VendorName = vendorName.Content;
                poData.FieldConfidences["VendorName"] = vendorName.Confidence ?? 0.0;
            }

            if (doc.Fields.TryGetValue("InvoiceDate", out var poDate) && poDate.Value != null)
            {
                poData.PODate = poDate.Value.AsDate().DateTime;
                poData.FieldConfidences["PODate"] = poDate.Confidence ?? 0.0;
            }

            if (doc.Fields.TryGetValue("InvoiceTotal", out var total) && total.Value != null)
            {
                var totalCurrency = total.Value.AsCurrency();
                poData.TotalAmount = (decimal)((double?)totalCurrency.Amount ?? 0.0);
                poData.FieldConfidences["TotalAmount"] = total.Confidence ?? 0.0;
            }

            // Extract line items
            if (doc.Fields.TryGetValue("Items", out var items) && items.Value != null)
            {
                var itemsList = items.Value.AsList();
                foreach (var item in itemsList)
                {
                    if (item.Value == null) continue;
                    
                    var itemFields = item.Value.AsDictionary();
                    var lineItem = new POLineItem();

                    if (itemFields.TryGetValue("ProductCode", out var code))
                        lineItem.ItemCode = code.Content;

                    if (itemFields.TryGetValue("Description", out var desc))
                        lineItem.Description = desc.Content;

                    if (itemFields.TryGetValue("Quantity", out var qty) && qty.Value != null)
                        lineItem.Quantity = (int)((double?)qty.Value.AsDouble() ?? 0.0);

                    if (itemFields.TryGetValue("UnitPrice", out var price) && price.Value != null)
                    {
                        var priceCurrency = price.Value.AsCurrency();
                        lineItem.UnitPrice = (decimal)((double?)priceCurrency.Amount ?? 0.0);
                    }

                    if (itemFields.TryGetValue("Amount", out var amount) && amount.Value != null)
                    {
                        var amountCurrency = amount.Value.AsCurrency();
                        lineItem.LineTotal = (decimal)((double?)amountCurrency.Amount ?? 0.0);
                    }

                    poData.LineItems.Add(lineItem);
                }
            }

            var avgConfidence = poData.FieldConfidences.Values.Any() 
                ? poData.FieldConfidences.Values.Average() 
                : 0.0;
            poData.FieldConfidences["Overall"] = avgConfidence;
            poData.IsFlaggedForReview = avgConfidence < 0.70;

            _logger.LogInformation(
                "PO extraction completed. PO: {PONumber}, Total: {Total}, Confidence: {Confidence}",
                poData.PONumber, poData.TotalAmount, avgConfidence);

            return poData;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting PO with Document Intelligence");
            throw;
        }
    }

    private InvoiceData CreateEmptyInvoiceData()
    {
        return new InvoiceData
        {
            LineItems = new List<InvoiceLineItem>(),
            FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.0 },
            IsFlaggedForReview = true
        };
    }

    private POData CreateEmptyPOData()
    {
        return new POData
        {
            LineItems = new List<POLineItem>(),
            FieldConfidences = new Dictionary<string, double> { ["Overall"] = 0.0 },
            IsFlaggedForReview = true
        };
    }

    /// <summary>
    /// Extracts all text from a document using the prebuilt-read model
    /// </summary>
    public async Task<string> ExtractTextFromDocumentAsync(Uri documentUri, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Starting Document Intelligence text extraction for: {Uri}", documentUri);

            var operation = await _client.AnalyzeDocumentFromUriAsync(
                WaitUntil.Completed,
                "prebuilt-read",
                documentUri,
                cancellationToken: cancellationToken);

            var result = operation.Value;
            
            // Extract all text content
            var textBuilder = new System.Text.StringBuilder();
            foreach (var page in result.Pages)
            {
                foreach (var line in page.Lines)
                {
                    textBuilder.AppendLine(line.Content);
                }
            }

            var extractedText = textBuilder.ToString();
            _logger.LogInformation("Text extraction completed. Extracted {Length} characters", extractedText.Length);
            
            return extractedText;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error extracting text with Document Intelligence");
            throw;
        }
    }
}
