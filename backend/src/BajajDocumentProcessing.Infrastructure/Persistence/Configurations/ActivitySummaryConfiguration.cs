using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the ActivitySummary entity.
/// </summary>
public class ActivitySummaryConfiguration : IEntityTypeConfiguration<ActivitySummary>
{
    public void Configure(EntityTypeBuilder<ActivitySummary> builder)
    {
        builder.ToTable("ActivitySummaries");

        // Primary Key
        builder.HasKey(a => a.Id);

        // Properties
        builder.Property(a => a.PackageId)
            .IsRequired();

        builder.Property(a => a.ActivityDescription)
            .HasMaxLength(2000);

        builder.Property(a => a.FileName)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(a => a.BlobUrl)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(a => a.FileSizeBytes)
            .IsRequired();

        builder.Property(a => a.ContentType)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(a => a.ExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(a => a.ExtractionConfidence);

        builder.Property(a => a.IsFlaggedForReview)
            .IsRequired()
            .HasDefaultValue(false);

        builder.Property(a => a.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Relationships

        // One-to-one with DocumentPackage (configured in DocumentPackageConfiguration)
        // Do NOT define here to avoid duplicate/shadow FK

        // ValidationResult is polymorphic (DocumentType + DocumentId) - ignore navigation to prevent shadow FK
        builder.Ignore(a => a.ValidationResult);

        // Indexes

        // Unique index on PackageId (enforces one-to-one relationship)
        builder.HasIndex(a => a.PackageId)
            .IsUnique()
            .HasDatabaseName("IX_ActivitySummaries_PackageId");

        // Index on VersionNumber for version-based queries
        builder.HasIndex(a => a.VersionNumber)
            .HasDatabaseName("IX_ActivitySummaries_VersionNumber");

        // Index on IsDeleted for soft delete filtering
        builder.HasIndex(a => a.IsDeleted)
            .HasDatabaseName("IX_ActivitySummaries_IsDeleted");

        // Global query filter for soft deletes
        builder.HasQueryFilter(a => !a.IsDeleted);
    }
}
