using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for CampaignPhoto
/// </summary>
public class CampaignPhotoConfiguration : IEntityTypeConfiguration<CampaignPhoto>
{
    public void Configure(EntityTypeBuilder<CampaignPhoto> builder)
    {
        builder.ToTable("CampaignPhotos");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.FileName)
            .IsRequired()
            .HasMaxLength(512);

        builder.Property(p => p.BlobUrl)
            .IsRequired()
            .HasMaxLength(2048);

        builder.Property(p => p.ContentType)
            .IsRequired()
            .HasMaxLength(128);

        builder.Property(p => p.Caption)
            .HasMaxLength(1000);

        builder.Property(p => p.DeviceModel)
            .HasMaxLength(200);

        builder.Property(p => p.ExtractedMetadataJson)
            .HasColumnType("nvarchar(max)");

        // Relationships
        builder.HasOne(p => p.Campaign)
            .WithMany(c => c.Photos)
            .HasForeignKey(p => p.CampaignId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(p => p.Package)
            .WithMany(pkg => pkg.CampaignPhotos)
            .HasForeignKey(p => p.PackageId)
            .OnDelete(DeleteBehavior.Restrict);

        // Indexes
        builder.HasIndex(p => p.CampaignId);
        builder.HasIndex(p => p.PackageId);
        builder.HasIndex(p => p.PhotoTimestamp);
    }
}
