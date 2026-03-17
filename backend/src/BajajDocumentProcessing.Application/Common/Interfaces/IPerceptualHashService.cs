namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Service for computing perceptual hashes of images and comparing them for duplicate detection.
/// Uses average hash (aHash) algorithm for fast, approximate image similarity comparison.
/// </summary>
public interface IPerceptualHashService
{
    /// <summary>
    /// Computes a perceptual hash for the given image stream using average hash (aHash) algorithm.
    /// </summary>
    /// <param name="imageStream">The image data stream</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A hex string representing the 64-bit perceptual hash, or null if computation fails</returns>
    Task<string?> ComputeHashAsync(Stream imageStream, CancellationToken cancellationToken = default);

    /// <summary>
    /// Computes the similarity between two perceptual hashes using normalized Hamming distance.
    /// </summary>
    /// <param name="hash1">First perceptual hash (hex string)</param>
    /// <param name="hash2">Second perceptual hash (hex string)</param>
    /// <returns>Similarity score: 0.0 = completely different, 1.0 = identical</returns>
    double ComputeSimilarity(string hash1, string hash2);
}
