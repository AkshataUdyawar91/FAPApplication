using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration for EnquiryDocument entity
/// </summary>
public class EnquiryDocumentConfiguration : IEntityTypeConfiguration<EnquiryDocument>
{
    public void Configure(EntityTypeBuilder<EnquiryDocument> builder)
    {
        // Table name
        builder.ToTable("EnquiryDocuments");

        // Primary key
        builder.HasKey(e => e.Id);

        // Properties
        builder.Property(e => e.PackageId)
            .IsRequired();

        builder.Property(e => e.FileName)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(e => e.BlobUrl)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(e => e.FileSizeBytes)
            .IsRequired();

        builder.Property(e => e.ContentType)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(e => e.ExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(e => e.ExtractionConfidence)
            .HasPrecision(5, 4);

        builder.Property(e => e.IsFlaggedForReview)
            .IsRequired()
            .HasDefaultValue(false);

        builder.Property(e => e.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Indexes
        // Unique index on PackageId to enforce one-to-one relationship
        builder.HasIndex(e => e.PackageId)
            .IsUnique()
            .HasDatabaseName("IX_EnquiryDocuments_PackageId");

        builder.HasIndex(e => e.VersionNumber)
            .HasDatabaseName("IX_EnquiryDocuments_VersionNumber");

        builder.HasIndex(e => e.IsDeleted)
            .HasDatabaseName("IX_EnquiryDocuments_IsDeleted");

        // Relationships
        // One-to-one with DocumentPackage (configured in DocumentPackageConfiguration)
        // builder.HasOne(e => e.DocumentPackage)... is NOT needed here

        // ValidationResult is polymorphic (DocumentType + DocumentId) - ignore navigation to prevent shadow FK
        builder.Ignore(e => e.ValidationResult);
    }
}
