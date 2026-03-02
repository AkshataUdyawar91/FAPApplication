using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for ConfidenceScore
/// </summary>
public class ConfidenceScoreConfiguration : IEntityTypeConfiguration<ConfidenceScore>
{
    public void Configure(EntityTypeBuilder<ConfidenceScore> builder)
    {
        builder.ToTable("ConfidenceScores");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.PoConfidence)
            .IsRequired()
            .HasPrecision(5, 2);

        builder.Property(c => c.InvoiceConfidence)
            .IsRequired()
            .HasPrecision(5, 2);

        builder.Property(c => c.CostSummaryConfidence)
            .IsRequired()
            .HasPrecision(5, 2);

        builder.Property(c => c.ActivityConfidence)
            .IsRequired()
            .HasPrecision(5, 2);

        builder.Property(c => c.PhotosConfidence)
            .IsRequired()
            .HasPrecision(5, 2);

        builder.Property(c => c.OverallConfidence)
            .IsRequired()
            .HasPrecision(5, 2);

        builder.HasIndex(c => c.PackageId)
            .IsUnique();

        builder.HasIndex(c => c.OverallConfidence);
    }
}
