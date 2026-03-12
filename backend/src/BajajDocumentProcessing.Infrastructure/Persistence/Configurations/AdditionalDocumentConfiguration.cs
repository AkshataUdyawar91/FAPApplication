using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration for AdditionalDocument entity
/// </summary>
public class AdditionalDocumentConfiguration : IEntityTypeConfiguration<AdditionalDocument>
{
    public void Configure(EntityTypeBuilder<AdditionalDocument> builder)
    {
        builder.ToTable("AdditionalDocuments");

        // Primary key
        builder.HasKey(a => a.Id);

        // Required properties
        builder.Property(a => a.PackageId)
            .IsRequired();

        builder.Property(a => a.DocumentType)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(a => a.Description)
            .HasMaxLength(500);

        builder.Property(a => a.FileName)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(a => a.BlobUrl)
            .IsRequired()
            .HasMaxLength(1000);

        builder.Property(a => a.FileSizeBytes)
            .IsRequired();

        builder.Property(a => a.ContentType)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(a => a.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Indexes
        builder.HasIndex(a => a.PackageId)
            .HasDatabaseName("IX_AdditionalDocuments_PackageId");

        builder.HasIndex(a => a.VersionNumber)
            .HasDatabaseName("IX_AdditionalDocuments_VersionNumber");

        builder.HasIndex(a => a.IsDeleted)
            .HasDatabaseName("IX_AdditionalDocuments_IsDeleted");

        // Relationships
        builder.HasOne(a => a.DocumentPackage)
            .WithMany(p => p.AdditionalDocuments)
            .HasForeignKey(a => a.PackageId)
            .OnDelete(DeleteBehavior.Restrict);

        // Global query filter for soft delete
        builder.HasQueryFilter(a => !a.IsDeleted);
    }
}
