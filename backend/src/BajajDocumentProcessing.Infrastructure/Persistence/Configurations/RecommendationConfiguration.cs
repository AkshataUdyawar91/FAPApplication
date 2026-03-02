using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Recommendation
/// </summary>
public class RecommendationConfiguration : IEntityTypeConfiguration<Recommendation>
{
    public void Configure(EntityTypeBuilder<Recommendation> builder)
    {
        builder.ToTable("Recommendations");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.Type)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(r => r.Evidence)
            .IsRequired()
            .HasMaxLength(4000);

        builder.Property(r => r.ValidationIssuesJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(r => r.ConfidenceScore)
            .IsRequired()
            .HasPrecision(5, 2);

        builder.HasIndex(r => r.PackageId)
            .IsUnique();

        builder.HasIndex(r => r.Type);
    }
}
