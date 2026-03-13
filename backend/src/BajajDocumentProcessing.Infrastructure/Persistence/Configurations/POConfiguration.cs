using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the PO entity.
/// </summary>
public class POConfiguration : IEntityTypeConfiguration<PO>
{
    public void Configure(EntityTypeBuilder<PO> builder)
    {
        builder.ToTable("POs");

        // Primary Key
        builder.HasKey(p => p.Id);

        // Properties
        builder.Property(p => p.PackageId)
            .IsRequired();

        builder.Property(p => p.AgencyId)
            .IsRequired();

        builder.Property(p => p.PONumber)
            .HasMaxLength(100);

        builder.Property(p => p.PODate);

        builder.Property(p => p.VendorName)
            .HasMaxLength(500);

        builder.Property(p => p.TotalAmount)
            .HasColumnType("decimal(18,2)");

        builder.Property(p => p.FileName)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(p => p.BlobUrl)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(p => p.FileSizeBytes)
            .IsRequired();

        builder.Property(p => p.ContentType)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(p => p.ExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(p => p.ExtractionConfidence);

        builder.Property(p => p.IsFlaggedForReview)
            .IsRequired()
            .HasDefaultValue(false);

        // Conversational submission search/filter fields
        builder.Property(p => p.VendorCode)
            .HasMaxLength(50);

        builder.Property(p => p.POStatus)
            .HasMaxLength(50);

        builder.Property(p => p.RemainingBalance)
            .HasColumnType("decimal(18,2)");

        builder.Property(p => p.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Relationships

        // One-to-one with DocumentPackage (configured in DocumentPackageConfiguration)
        // builder.HasOne(p => p.DocumentPackage)... is NOT needed here

        // Many-to-one with Agency
        builder.HasOne(p => p.Agency)
            .WithMany()
            .HasForeignKey(p => p.AgencyId)
            .OnDelete(DeleteBehavior.Restrict);

        // ValidationResult is polymorphic (DocumentType + DocumentId) - ignore navigation to prevent shadow FK
        builder.Ignore(p => p.ValidationResult);

        // Indexes

        // Unique index on PackageId (enforces one-to-one relationship)
        builder.HasIndex(p => p.PackageId)
            .IsUnique()
            .HasDatabaseName("IX_POs_PackageId");

        // Index on AgencyId for filtering by agency
        builder.HasIndex(p => p.AgencyId)
            .HasDatabaseName("IX_POs_AgencyId");

        // Index on PONumber for searching by PO number
        builder.HasIndex(p => p.PONumber)
            .HasDatabaseName("IX_POs_PONumber");

        // Index on VersionNumber for version-based queries
        builder.HasIndex(p => p.VersionNumber)
            .HasDatabaseName("IX_POs_VersionNumber");

        // Index on IsDeleted for soft delete filtering
        builder.HasIndex(p => p.IsDeleted)
            .HasDatabaseName("IX_POs_IsDeleted");

        // Global query filter for soft deletes
        builder.HasQueryFilter(p => !p.IsDeleted);
    }
}
