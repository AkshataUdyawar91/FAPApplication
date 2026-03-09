using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Document Agent interface for document classification and extraction
/// </summary>
public interface IDocumentAgent
{
    /// <summary>
    /// Classifies a document using Azure OpenAI GPT-4 Vision
    /// </summary>
    /// <param name="blobUrl">URL of the document in blob storage</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Classification result with document type and confidence score</returns>
    Task<DocumentClassification> ClassifyAsync(string blobUrl, CancellationToken cancellationToken = default);

    /// <summary>
    /// Extracts structured data from a Purchase Order document
    /// </summary>
    /// <param name="blobUrl">URL of the PO document in blob storage</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Extracted PO data with field-level confidence scores</returns>
    Task<POData> ExtractPOAsync(string blobUrl, CancellationToken cancellationToken = default);

    /// <summary>
    /// Extracts structured data from an Invoice document
    /// </summary>
    /// <param name="blobUrl">URL of the Invoice document in blob storage</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Extracted Invoice data with field-level confidence scores</returns>
    Task<InvoiceData> ExtractInvoiceAsync(string blobUrl, CancellationToken cancellationToken = default);

    /// <summary>
    /// Extracts structured data from a Cost Summary document
    /// </summary>
    /// <param name="blobUrl">URL of the Cost Summary document in blob storage</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Extracted Cost Summary data with field-level confidence scores</returns>
    Task<CostSummaryData> ExtractCostSummaryAsync(string blobUrl, CancellationToken cancellationToken = default);

    /// <summary>
    /// Extracts EXIF metadata from a photo
    /// </summary>
    /// <param name="blobUrl">URL of the photo in blob storage</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Extracted photo metadata including timestamp and location</returns>
    Task<PhotoMetadata> ExtractPhotoMetadataAsync(string blobUrl, CancellationToken cancellationToken = default);

    // CHANGE: Added ExtractActivityAsync for Activity Summary extraction
    /// <summary>
    /// Extracts structured data from an Activity Summary document
    /// </summary>
    /// <param name="blobUrl">URL of the Activity Summary document in blob storage</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Extracted Activity data with dealer/location details and number of days</returns>
    Task<ActivityData> ExtractActivityAsync(string blobUrl, CancellationToken cancellationToken = default);

    // CHANGE: Added ExtractEnquiryDumpAsync for Enquiry Dump Excel extraction
    /// <summary>
    /// Extracts structured data from an Enquiry Dump Excel file
    /// </summary>
    /// <param name="blobUrl">URL of the Enquiry Dump Excel file in blob storage</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Extracted Enquiry Dump data with customer records</returns>
    Task<EnquiryDumpData> ExtractEnquiryDumpAsync(string blobUrl, CancellationToken cancellationToken = default);
}

/// <summary>
/// Result of document classification
/// </summary>
public class DocumentClassification
{
    public DocumentType Type { get; set; }
    public double Confidence { get; set; }
    public bool IsFlaggedForReview { get; set; }
}
