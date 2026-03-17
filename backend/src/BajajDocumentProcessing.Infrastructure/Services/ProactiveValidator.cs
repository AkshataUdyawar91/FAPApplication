using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Runs proactive (on-upload) field presence validation on a single document.
/// Loads the document by ID, deserializes ExtractedDataJson, and checks required fields.
/// Does NOT run cross-document or SAP validation.
/// </summary>
public class ProactiveValidator : IProactiveValidator
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<ProactiveValidator> _logger;
    private readonly ICorrelationIdService _correlationIdService;

    public ProactiveValidator(
        IApplicationDbContext context,
        ILogger<ProactiveValidator> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _logger = logger;
        _correlationIdService = correlationIdService;
    }

    /// <inheritdoc />
    public async Task<ProactiveValidationResult> ValidateDocumentOnUploadAsync(
        Guid documentId,
        DocumentType documentType,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting proactive validation for document {DocumentId}, type {DocumentType}. CorrelationId: {CorrelationId}",
            documentId, documentType, correlationId);

        var result = new ProactiveValidationResult
        {
            DocumentType = documentType,
            ValidatedAt = DateTime.UtcNow
        };

        try
        {
            var extractedJson = await LoadExtractedDataAsync(documentId, documentType, cancellationToken);

            if (string.IsNullOrEmpty(extractedJson))
            {
                result.Warnings.Add("Document extraction not yet complete or no data extracted.");
                result.Passed = true;
                return result;
            }

            var missingFields = documentType switch
            {
                DocumentType.Invoice => ValidateInvoiceFields(extractedJson),
                DocumentType.CostSummary => ValidateCostSummaryFields(extractedJson),
                DocumentType.ActivitySummary => ValidateActivityFields(extractedJson),
                DocumentType.EnquiryDocument => ValidateEnquiryFields(extractedJson),
                DocumentType.TeamPhoto => ValidatePhotoFields(extractedJson),
                _ => new List<string>()
            };

            result.MissingFields = missingFields;
            result.Passed = missingFields.Count == 0;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex,
                "Proactive validation failed for document {DocumentId}. Returning pass with warning.",
                documentId);
            result.Warnings.Add("Validation could not be completed. Please verify document contents.");
            result.Passed = true;
        }

        _logger.LogInformation(
            "Proactive validation completed for {DocumentId}. Passed: {Passed}, MissingFields: {Count}. CorrelationId: {CorrelationId}",
            documentId, result.Passed, result.MissingFields.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Loads the ExtractedDataJson for a document from the appropriate table.
    /// </summary>
    private async Task<string?> LoadExtractedDataAsync(
        Guid documentId, DocumentType documentType, CancellationToken cancellationToken)
    {
        return documentType switch
        {
            DocumentType.Invoice => (await _context.Invoices.AsNoTracking()
                .FirstOrDefaultAsync(i => i.Id == documentId, cancellationToken))?.ExtractedDataJson,
            DocumentType.CostSummary => (await _context.CostSummaries.AsNoTracking()
                .FirstOrDefaultAsync(c => c.Id == documentId, cancellationToken))?.ExtractedDataJson,
            DocumentType.ActivitySummary => (await _context.ActivitySummaries.AsNoTracking()
                .FirstOrDefaultAsync(a => a.Id == documentId, cancellationToken))?.ExtractedDataJson,
            DocumentType.EnquiryDocument => (await _context.EnquiryDocuments.AsNoTracking()
                .FirstOrDefaultAsync(e => e.Id == documentId, cancellationToken))?.ExtractedDataJson,
            DocumentType.TeamPhoto => (await _context.TeamPhotos.AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == documentId, cancellationToken))?.ExtractedMetadataJson,
            _ => null
        };
    }

    /// <summary>
    /// Validates invoice required fields from extracted JSON.
    /// Mirrors the field checks in ValidationAgent.ValidateInvoiceFieldPresence.
    /// </summary>
    private static List<string> ValidateInvoiceFields(string json)
    {
        var data = JsonSerializer.Deserialize<InvoiceData>(json);
        if (data == null) return new List<string> { "Failed to parse invoice data" };

        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(data.AgencyName)) missing.Add("Agency Name");
        if (string.IsNullOrWhiteSpace(data.AgencyAddress)) missing.Add("Agency Address");
        if (string.IsNullOrWhiteSpace(data.BillingName)) missing.Add("Billing Name");
        if (string.IsNullOrWhiteSpace(data.BillingAddress)) missing.Add("Billing Address");
        if (string.IsNullOrWhiteSpace(data.StateName) && string.IsNullOrWhiteSpace(data.StateCode))
            missing.Add("State Name/Code");
        if (string.IsNullOrWhiteSpace(data.InvoiceNumber)) missing.Add("Invoice Number");
        if (data.InvoiceDate == default) missing.Add("Invoice Date");
        if (string.IsNullOrWhiteSpace(data.VendorCode)) missing.Add("Vendor Code");
        if (string.IsNullOrWhiteSpace(data.GSTNumber)) missing.Add("GST Number");
        if (data.GSTPercentage <= 0) missing.Add("GST Percentage");
        if (string.IsNullOrWhiteSpace(data.HSNSACCode)) missing.Add("HSN/SAC Code");
        if (data.TotalAmount <= 0) missing.Add("Invoice Amount");
        if (string.IsNullOrWhiteSpace(data.PONumber)) missing.Add("PO Number");
        return missing;
    }

    /// <summary>
    /// Validates cost summary required fields from extracted JSON.
    /// Mirrors the field checks in ValidationAgent.ValidateCostSummaryFieldPresence.
    /// </summary>
    private static List<string> ValidateCostSummaryFields(string json)
    {
        var data = JsonSerializer.Deserialize<CostSummaryData>(json);
        if (data == null) return new List<string> { "Failed to parse cost summary data" };

        var missing = new List<string>();
        if (string.IsNullOrWhiteSpace(data.PlaceOfSupply) && string.IsNullOrWhiteSpace(data.State))
            missing.Add("Place of Supply / State");
        if (data.CostBreakdowns == null || !data.CostBreakdowns.Any())
            missing.Add("Element wise Cost");
        if (!data.NumberOfDays.HasValue || data.NumberOfDays.Value <= 0)
            missing.Add("Number of Days");
        if (!data.NumberOfActivations.HasValue || data.NumberOfActivations.Value <= 0)
            missing.Add("Number of Activations");
        if (!data.NumberOfTeams.HasValue || data.NumberOfTeams.Value <= 0)
            missing.Add("Number of Teams");
        if (data.TotalCost <= 0)
            missing.Add("Total Cost");
        return missing;
    }

    /// <summary>
    /// Validates activity summary required fields from extracted JSON.
    /// Mirrors the field checks in ValidationAgent.ValidateActivityFieldPresence.
    /// </summary>
    private static List<string> ValidateActivityFields(string json)
    {
        var data = JsonSerializer.Deserialize<ActivityData>(json);
        if (data == null) return new List<string> { "Failed to parse activity data" };

        var missing = new List<string>();
        if (data.Rows == null || !data.Rows.Any())
        {
            missing.Add("Activity Rows");
            return missing;
        }

        if (!data.Rows.Any(r => !string.IsNullOrWhiteSpace(r.DealerName)))
            missing.Add("Dealer Name");

        var rowsWithoutLocation = data.Rows.Count(r => string.IsNullOrWhiteSpace(r.Location));
        if (rowsWithoutLocation > 0)
            missing.Add($"Location missing for {rowsWithoutLocation} row(s)");

        if (data.Rows.All(r => r.Day <= 0))
            missing.Add("Number of days");

        return missing;
    }

    /// <summary>
    /// Validates enquiry dump required fields from extracted JSON.
    /// Mirrors the field checks in ValidationAgent.ValidateEnquiryDumpFieldPresence.
    /// </summary>
    private static List<string> ValidateEnquiryFields(string json)
    {
        var data = JsonSerializer.Deserialize<EnquiryDumpData>(json);
        if (data == null) return new List<string> { "Failed to parse enquiry data" };

        var missing = new List<string>();
        if (data.Records == null || !data.Records.Any())
        {
            missing.Add("No enquiry records found");
            return missing;
        }

        int total = data.Records.Count;
        int threshold = total / 2;

        if (data.Records.Count(r => !string.IsNullOrWhiteSpace(r.State)) <= threshold)
            missing.Add("State");
        if (data.Records.Count(r => r.Date.HasValue) <= threshold)
            missing.Add("Date");
        if (data.Records.Count(r => !string.IsNullOrWhiteSpace(r.DealerCode)) <= threshold)
            missing.Add("Dealer Code");
        if (data.Records.Count(r => !string.IsNullOrWhiteSpace(r.DealerName)) <= threshold)
            missing.Add("Dealer Name");
        if (data.Records.Count(r => !string.IsNullOrWhiteSpace(r.CustomerName)) <= threshold)
            missing.Add("Customer Name");
        if (data.Records.Count(r => !string.IsNullOrWhiteSpace(r.CustomerNumber)) <= threshold)
            missing.Add("Customer Number");

        return missing;
    }

    /// <summary>
    /// Validates photo metadata fields from extracted JSON.
    /// Photos are validated for EXIF date and GPS location presence.
    /// </summary>
    private static List<string> ValidatePhotoFields(string json)
    {
        var data = JsonSerializer.Deserialize<PhotoMetadata>(json);
        if (data == null) return new List<string> { "Failed to parse photo metadata" };

        var missing = new List<string>();
        if (!data.Timestamp.HasValue)
            missing.Add("Photo Date (EXIF)");
        if (!data.Latitude.HasValue || !data.Longitude.HasValue)
            missing.Add("GPS Location (EXIF)");
        return missing;
    }
}
