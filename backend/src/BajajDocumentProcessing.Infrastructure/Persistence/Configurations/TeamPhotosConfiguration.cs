using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for TeamPhotos (formerly CampaignPhoto)
/// Photos are linked to Teams and can have validation results
/// </summary>
public class TeamPhotosConfiguration : IEntityTypeConfiguration<TeamPhotos>
{
    public void Configure(EntityTypeBuilder<TeamPhotos> builder)
    {
        builder.ToTable("TeamPhotos");

        builder.HasKey(tp => tp.Id);

        builder.Property(tp => tp.FileName)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(tp => tp.BlobUrl)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(tp => tp.FileSizeBytes)
            .IsRequired();

        builder.Property(tp => tp.ContentType)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(tp => tp.Caption)
            .HasColumnType("nvarchar(max)");

        builder.Property(tp => tp.DeviceModel)
            .HasMaxLength(200);

        builder.Property(tp => tp.DateVisible);
        builder.Property(tp => tp.BlueTshirtPresent);
        builder.Property(tp => tp.ThreeWheelerPresent);

        builder.Property(tp => tp.PhotoDateOverlay)
            .HasMaxLength(100);

        builder.Property(tp => tp.ExtractedMetadataJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(tp => tp.ExtractionConfidence)
            .HasPrecision(5, 2);

        builder.Property(tp => tp.IsFlaggedForReview)
            .IsRequired()
            .HasDefaultValue(false);

        builder.Property(tp => tp.DisplayOrder)
            .IsRequired()
            .HasDefaultValue(0);

        builder.Property(tp => tp.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Relationships
        // Use Restrict (not Cascade) to avoid multiple cascade paths through DocumentPackages
        // TeamPhotos → Teams → DocumentPackages AND TeamPhotos → DocumentPackages
        builder.HasOne(tp => tp.Team)
            .WithMany(t => t.Photos)
            .HasForeignKey(tp => tp.TeamId)
            .OnDelete(DeleteBehavior.Restrict);

        // Package relationship is configured in DocumentPackageConfiguration
        // Do NOT define it here to avoid shadow FK columns

        // ValidationResult is polymorphic (DocumentType + DocumentId) - ignore navigation to prevent shadow FK
        builder.Ignore(tp => tp.ValidationResult);

        // Indexes
        builder.HasIndex(tp => tp.TeamId);
        builder.HasIndex(tp => tp.PackageId);
        builder.HasIndex(tp => tp.VersionNumber);
        builder.HasIndex(tp => tp.DisplayOrder);
    }
}
