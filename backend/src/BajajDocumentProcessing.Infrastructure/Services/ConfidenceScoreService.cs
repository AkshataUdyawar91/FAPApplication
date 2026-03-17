using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
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
            // Load package with dedicated document navigations
            var package = await _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.CostSummary)
                .Include(p => p.ActivitySummary)
                .Include(p => p.Teams)
                    .ThenInclude(t => t.Photos)
                .AsSplitQuery()
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                throw new Domain.Exceptions.NotFoundException($"Package {packageId} not found");
            }

            // Extract individual document confidences from dedicated entities
            var poConfidence = GetPoConfidence(package);
            var invoiceConfidence = GetInvoiceConfidence(package);
            var costSummaryConfidence = GetCostSummaryConfidence(package);
            var activityConfidence = GetActivityConfidence(package);
            var photosConfidence = GetAveragePhotoConfidence(package);

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
    /// Gets the PO extraction confidence from the dedicated PO entity.
    /// Returns 0 if no PO is present.
    /// </summary>
    private double GetPoConfidence(DocumentPackage package)
    {
        if (package.PO == null)
        {
            _logger.LogWarning("PO not found for package {PackageId}, using confidence 0", package.Id);
            return 0.0;
        }

        return package.PO.ExtractionConfidence ?? 0.0;
    }

    /// <summary>
    /// Gets the Invoice extraction confidence from the first dedicated Invoice entity.
    /// Returns 0 if no Invoice is present.
    /// </summary>
    private double GetInvoiceConfidence(DocumentPackage package)
    {
        var invoice = package.Invoices.FirstOrDefault();
        if (invoice == null)
        {
            _logger.LogWarning("Invoice not found for package {PackageId}, using confidence 0", package.Id);
            return 0.0;
        }

        return invoice.ExtractionConfidence ?? 0.0;
    }

    /// <summary>
    /// Gets the CostSummary extraction confidence from the dedicated CostSummary entity.
    /// Returns 0 if no CostSummary is present.
    /// </summary>
    private double GetCostSummaryConfidence(DocumentPackage package)
    {
        if (package.CostSummary == null)
        {
            _logger.LogWarning("CostSummary not found for package {PackageId}, using confidence 0", package.Id);
            return 0.0;
        }

        return package.CostSummary.ExtractionConfidence ?? 0.0;
    }

    /// <summary>
    /// Gets the ActivitySummary extraction confidence from the dedicated ActivitySummary entity.
    /// Returns 0 if no ActivitySummary is present.
    /// </summary>
    private double GetActivityConfidence(DocumentPackage package)
    {
        if (package.ActivitySummary == null)
        {
            _logger.LogWarning("ActivitySummary not found for package {PackageId}, using confidence 0", package.Id);
            return 0.0;
        }

        return package.ActivitySummary.ExtractionConfidence ?? 0.0;
    }

    /// <summary>
    /// Gets the average extraction confidence across all TeamPhotos in the package.
    /// Returns 0 if no photos are found.
    /// </summary>
    private double GetAveragePhotoConfidence(DocumentPackage package)
    {
        var photos = package.Teams.SelectMany(t => t.Photos).ToList();

        if (!photos.Any())
        {
            _logger.LogWarning("No photos found for package {PackageId}, using confidence 0", package.Id);
            return 0.0;
        }

        return photos.Average(p => p.ExtractionConfidence ?? 0.0);
    }
}
