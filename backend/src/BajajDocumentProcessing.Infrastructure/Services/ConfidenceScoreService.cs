using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for calculating confidence scores for document packages.
/// Implements weighted scoring based on document type importance:
/// PO (30%), Invoice (30%), Cost Summary (20%), Activity (10%), Photos (10%).
/// </summary>
public class ConfidenceScoreService : IConfidenceScoreService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<ConfidenceScoreService> _logger;
    private readonly ICorrelationIdService _correlationIdService;

    // Confidence score weights as per requirements
    private const double PO_WEIGHT = 0.30;
    private const double INVOICE_WEIGHT = 0.30;
    private const double COST_SUMMARY_WEIGHT = 0.20;
    private const double ACTIVITY_WEIGHT = 0.10;
    private const double PHOTOS_WEIGHT = 0.10;
    private const double LOW_CONFIDENCE_THRESHOLD = 70.0;

    /// <summary>
    /// Initializes a new instance of the ConfidenceScoreService class.
    /// </summary>
    /// <param name="context">Database context for accessing document packages and confidence scores</param>
    /// <param name="logger">Logger for diagnostic information</param>
    /// <param name="correlationIdService">Service for accessing correlation ID</param>
    public ConfidenceScoreService(
        IApplicationDbContext context,
        ILogger<ConfidenceScoreService> logger,
        ICorrelationIdService correlationIdService)
    {
        _context = context;
        _logger = logger;
        _correlationIdService = correlationIdService;
    }

    /// <summary>
    /// Calculates the overall confidence score for a document package.
    /// Applies weighted scoring based on document type importance and flags packages below 70% confidence.
    /// Creates a new confidence score or updates an existing one.
    /// </summary>
    /// <param name="packageId">The unique identifier of the package to score</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>A ConfidenceScore entity with individual and overall confidence scores</returns>
    /// <exception cref="InvalidOperationException">Thrown when the package is not found</exception>
    public async Task<ConfidenceScore> CalculateConfidenceScoreAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Calculating confidence score for package {PackageId}. CorrelationId: {CorrelationId}",
            packageId, correlationId);

        try
        {
            // Load package with documents
            var package = await _context.DocumentPackages
                .Include(p => p.Documents)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                throw new Domain.Exceptions.NotFoundException($"Package {packageId} not found");
            }

            // Extract individual document confidences
            var poConfidence = GetDocumentConfidence(package.Documents, DocumentType.PO);
            var invoiceConfidence = GetDocumentConfidence(package.Documents, DocumentType.Invoice);
            var costSummaryConfidence = GetDocumentConfidence(package.Documents, DocumentType.CostSummary);
            var activityConfidence = GetDocumentConfidence(package.Documents, DocumentType.AdditionalDocument);
            var photosConfidence = GetAveragePhotoConfidence(package.Documents);

            // Calculate weighted overall confidence
            var overallConfidence = CalculateWeightedScore(
                poConfidence,
                invoiceConfidence,
                costSummaryConfidence,
                activityConfidence,
                photosConfidence);

            // Determine if flagged for review
            var isFlaggedForReview = overallConfidence < LOW_CONFIDENCE_THRESHOLD;

            // Check if confidence score already exists (WITH tracking to enable proper updates)
            var existingScore = await _context.ConfidenceScores
                .FirstOrDefaultAsync(cs => cs.PackageId == packageId, cancellationToken);

            ConfidenceScore confidenceScore;

            if (existingScore != null)
            {
                _logger.LogInformation("Updating existing confidence score {ScoreId} for package {PackageId}", existingScore.Id, packageId);
                
                // Update existing tracked entity - EF Core will generate UPDATE statement
                existingScore.PoConfidence = poConfidence;
                existingScore.InvoiceConfidence = invoiceConfidence;
                existingScore.CostSummaryConfidence = costSummaryConfidence;
                existingScore.ActivityConfidence = activityConfidence;
                existingScore.PhotosConfidence = photosConfidence;
                existingScore.OverallConfidence = overallConfidence;
                existingScore.IsFlaggedForReview = isFlaggedForReview;
                existingScore.UpdatedAt = DateTime.UtcNow;
                // CreatedAt is preserved automatically

                confidenceScore = existingScore;
            }
            else
            {
                _logger.LogInformation("Creating new confidence score for package {PackageId}", packageId);
                
                // Create new score
                confidenceScore = new ConfidenceScore
                {
                    Id = Guid.NewGuid(),
                    PackageId = packageId,
                    PoConfidence = poConfidence,
                    InvoiceConfidence = invoiceConfidence,
                    CostSummaryConfidence = costSummaryConfidence,
                    ActivityConfidence = activityConfidence,
                    PhotosConfidence = photosConfidence,
                    OverallConfidence = overallConfidence,
                    IsFlaggedForReview = isFlaggedForReview,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                _context.ConfidenceScores.Add(confidenceScore);
            }

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Confidence score calculated for package {PackageId}: Overall={Overall:F2}, Flagged={Flagged}. CorrelationId: {CorrelationId}",
                packageId,
                overallConfidence,
                isFlaggedForReview,
                correlationId);

            return confidenceScore;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error calculating confidence score for package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
            throw;
        }
    }

    /// <summary>
    /// Calculates the weighted overall confidence score from individual document confidences.
    /// Uses predefined weights: PO (30%), Invoice (30%), Cost Summary (20%), Activity (10%), Photos (10%).
    /// </summary>
    /// <param name="poConfidence">Confidence score for Purchase Order (0-100)</param>
    /// <param name="invoiceConfidence">Confidence score for Invoice (0-100)</param>
    /// <param name="costSummaryConfidence">Confidence score for Cost Summary (0-100)</param>
    /// <param name="activityConfidence">Confidence score for Activity Summary (0-100)</param>
    /// <param name="photosConfidence">Average confidence score for Photos (0-100)</param>
    /// <returns>Weighted overall confidence score (0-100)</returns>
    public double CalculateWeightedScore(
        double poConfidence,
        double invoiceConfidence,
        double costSummaryConfidence,
        double activityConfidence,
        double photosConfidence)
    {
        // Calculate weighted average
        var weightedScore = (poConfidence * PO_WEIGHT) +
                           (invoiceConfidence * INVOICE_WEIGHT) +
                           (costSummaryConfidence * COST_SUMMARY_WEIGHT) +
                           (activityConfidence * ACTIVITY_WEIGHT) +
                           (photosConfidence * PHOTOS_WEIGHT);

        // Ensure score is between 0 and 100
        weightedScore = Math.Max(0, Math.Min(100, weightedScore));

        return weightedScore;
    }

    /// <summary>
    /// Gets the confidence score for a specific document type from the package.
    /// Returns 0 if the document type is not found.
    /// </summary>
    /// <param name="documents">Collection of documents in the package</param>
    /// <param name="documentType">The type of document to get confidence for</param>
    /// <returns>The extraction confidence score (0-100), or 0 if document not found</returns>
    private double GetDocumentConfidence(ICollection<Document> documents, DocumentType documentType)
    {
        var document = documents.FirstOrDefault(d => d.Type == documentType);

        if (document == null)
        {
            _logger.LogWarning("Document type {DocumentType} not found, using confidence 0", documentType);
            return 0.0;
        }

        // If document has a confidence score, use it; otherwise default to 0
        return document.ExtractionConfidence ?? 0.0;
    }

    /// <summary>
    /// Gets the average confidence score for all photos in the package.
    /// Returns 0 if no photos are found.
    /// </summary>
    /// <param name="documents">Collection of documents in the package</param>
    /// <returns>The average extraction confidence score across all photos (0-100), or 0 if no photos</returns>
    private double GetAveragePhotoConfidence(ICollection<Document> documents)
    {
        var photos = documents.Where(d => d.Type == DocumentType.Photo).ToList();

        if (!photos.Any())
        {
            _logger.LogWarning("No photos found, using confidence 0");
            return 0.0;
        }

        // Calculate average confidence across all photos
        var totalConfidence = photos.Sum(p => p.ExtractionConfidence ?? 0.0);
        var averageConfidence = totalConfidence / photos.Count;

        return averageConfidence;
    }
}
