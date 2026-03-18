using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the CostSummary entity.
/// </summary>
public class CostSummaryConfiguration : IEntityTypeConfiguration<CostSummary>
{
    public void Configure(EntityTypeBuilder<CostSummary> builder)
    {
        builder.ToTable("CostSummaries");

        // Primary Key
        builder.HasKey(c => c.Id);

        // Properties
        builder.Property(c => c.PackageId)
            .IsRequired();

        builder.Property(c => c.TotalCost)
            .HasColumnType("decimal(18,2)");

        builder.Property(c => c.PlaceOfSupply)
            .HasMaxLength(500);

        builder.Property(c => c.NumberOfDays);

        builder.Property(c => c.NumberOfActivations);

        builder.Property(c => c.NumberOfTeams);

        builder.Property(c => c.ElementWiseCostsJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(c => c.ElementWiseQuantityJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(c => c.CostBreakdownJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(c => c.FileName)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(c => c.BlobUrl)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(c => c.FileSizeBytes)
            .IsRequired();

        builder.Property(c => c.ContentType)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(c => c.ExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(c => c.ExtractionConfidence);

        builder.Property(c => c.IsFlaggedForReview)
            .IsRequired()
            .HasDefaultValue(false);

        builder.Property(c => c.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Relationships

        // One-to-one with DocumentPackage (configured in DocumentPackageConfiguration)
        // Do NOT define here to avoid duplicate/shadow FK

        // ValidationResult is polymorphic (DocumentType + DocumentId) - ignore navigation to prevent shadow FK
        builder.Ignore(c => c.ValidationResult);

        // Indexes

        // Unique index on PackageId (enforces one-to-one relationship)
        builder.HasIndex(c => c.PackageId)
            .IsUnique()
            .HasDatabaseName("IX_CostSummaries_PackageId");

        // Index on VersionNumber for version-based queries
        builder.HasIndex(c => c.VersionNumber)
            .HasDatabaseName("IX_CostSummaries_VersionNumber");

        // Index on IsDeleted for soft delete filtering
        builder.HasIndex(c => c.IsDeleted)
            .HasDatabaseName("IX_CostSummaries_IsDeleted");

        // Global query filter for soft deletes
        builder.HasQueryFilter(c => !c.IsDeleted);
    }
}
