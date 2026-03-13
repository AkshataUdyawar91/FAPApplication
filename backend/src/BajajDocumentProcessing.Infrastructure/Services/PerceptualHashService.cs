using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.Extensions.Logging;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Implements perceptual hashing using average hash (aHash) algorithm.
/// Resizes image to 8×8 grayscale, computes mean pixel value, generates 64-bit hash.
/// Uses Hamming distance for similarity comparison.
/// </summary>
public class PerceptualHashService : IPerceptualHashService
{
    private readonly ILogger<PerceptualHashService> _logger;
    private const int HashSize = 8;

    public PerceptualHashService(ILogger<PerceptualHashService> logger)
    {
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task<string?> ComputeHashAsync(Stream imageStream, CancellationToken cancellationToken = default)
    {
        try
        {
            using var image = await Image.LoadAsync<Rgba32>(imageStream, cancellationToken);

            // Resize to 8×8 and convert to grayscale
            image.Mutate(ctx => ctx
                .Resize(HashSize, HashSize)
                .Grayscale());

            // Compute mean pixel value
            double totalBrightness = 0;
            for (int y = 0; y < HashSize; y++)
            {
                for (int x = 0; x < HashSize; x++)
                {
                    totalBrightness += image[x, y].R; // Grayscale so R=G=B
                }
            }
            var mean = totalBrightness / (HashSize * HashSize);

            // Generate 64-bit hash: each bit = 1 if pixel >= mean, 0 otherwise
            ulong hash = 0;
            for (int y = 0; y < HashSize; y++)
            {
                for (int x = 0; x < HashSize; x++)
                {
                    hash <<= 1;
                    if (image[x, y].R >= mean)
                    {
                        hash |= 1;
                    }
                }
            }

            return hash.ToString("X16");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to compute perceptual hash for image");
            return null;
        }
    }

    /// <inheritdoc />
    public double ComputeSimilarity(string hash1, string hash2)
    {
        if (string.IsNullOrEmpty(hash1) || string.IsNullOrEmpty(hash2))
            return 0.0;

        if (!ulong.TryParse(hash1, System.Globalization.NumberStyles.HexNumber, null, out var h1) ||
            !ulong.TryParse(hash2, System.Globalization.NumberStyles.HexNumber, null, out var h2))
        {
            _logger.LogWarning("Invalid hash format: {Hash1}, {Hash2}", hash1, hash2);
            return 0.0;
        }

        // Hamming distance: count differing bits
        var xor = h1 ^ h2;
        var distance = CountBits(xor);

        // Normalize: 0 distance = 1.0 similarity, 64 distance = 0.0 similarity
        return 1.0 - (distance / 64.0);
    }

    /// <summary>
    /// Counts the number of set bits (1s) in a 64-bit integer using Brian Kernighan's algorithm.
    /// </summary>
    private static int CountBits(ulong value)
    {
        int count = 0;
        while (value != 0)
        {
            value &= value - 1;
            count++;
        }
        return count;
    }
}
