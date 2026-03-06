using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Service for calculating confidence scores for document packages
/// </summary>
public class ConfidenceScoreService : IConfidenceScoreService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<ConfidenceScoreService> _logger;

    // Confidence score weights as per requirements
    private const double PO_WEIGHT = 0.30;
    private const double INVOICE_WEIGHT = 0.30;
    private const double COST_SUMMARY_WEIGHT = 0.20;
    private const double ACTIVITY_WEIGHT = 0.10;
    private const double PHOTOS_WEIGHT = 0.10;
    private const double LOW_CONFIDENCE_THRESHOLD = 70.0;

    public ConfidenceScoreService(
        IApplicationDbContext context,
        ILogger<ConfidenceScoreService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<ConfidenceScore> CalculateConfidenceScoreAsync(
        Guid packageId,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Calculating confidence score for package {PackageId}", packageId);

        try
        {
            // Load package with documents
            var package = await _context.DocumentPackages
                .Include(p => p.Documents)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                throw new InvalidOperationException($"Package {packageId} not found");
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
                "Confidence score calculated for package {PackageId}: Overall={Overall:F2}, Flagged={Flagged}",
                packageId,
                overallConfidence,
                isFlaggedForReview);

            return confidenceScore;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error calculating confidence score for package {PackageId}", packageId);
            throw;
        }
    }

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
    /// Gets the confidence score for a specific document type
    /// </summary>
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
    /// Gets the average confidence score for all photos
    /// </summary>
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
