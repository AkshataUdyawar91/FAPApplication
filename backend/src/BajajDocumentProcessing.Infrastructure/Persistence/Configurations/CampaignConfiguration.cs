using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Campaign (Team)
/// Campaign belongs directly to Package (not Invoice)
/// </summary>
public class CampaignConfiguration : IEntityTypeConfiguration<Campaign>
{
    public void Configure(EntityTypeBuilder<Campaign> builder)
    {
        builder.ToTable("Campaigns");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.CampaignName)
            .HasMaxLength(500);

        builder.Property(c => c.TeamCode)
            .HasMaxLength(100);

        builder.Property(c => c.DealershipName)
            .HasMaxLength(500);

        builder.Property(c => c.DealershipAddress)
            .HasMaxLength(1000);

        builder.Property(c => c.GPSLocation)
            .HasMaxLength(100);

        builder.Property(c => c.State)
            .HasMaxLength(100);

        builder.Property(c => c.TeamsJson)
            .HasColumnType("nvarchar(max)");

        // Cost Summary fields (1 per Campaign)
        builder.Property(c => c.TotalCost)
            .HasColumnType("decimal(18,2)");

        builder.Property(c => c.CostBreakdownJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(c => c.CostSummaryFileName)
            .HasMaxLength(512);

        builder.Property(c => c.CostSummaryBlobUrl)
            .HasMaxLength(2048);

        builder.Property(c => c.CostSummaryContentType)
            .HasMaxLength(100);

        builder.Property(c => c.CostSummaryExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        // Activity Summary fields (1 per Campaign)
        builder.Property(c => c.ActivitySummaryFileName)
            .HasMaxLength(512);

        builder.Property(c => c.ActivitySummaryBlobUrl)
            .HasMaxLength(2048);

        builder.Property(c => c.ActivitySummaryContentType)
            .HasMaxLength(100);

        builder.Property(c => c.ActivitySummaryExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        // Relationships - Campaign belongs directly to Package (not Invoice)
        builder.HasOne(c => c.Package)
            .WithMany(p => p.Campaigns)
            .HasForeignKey(c => c.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        // Indexes
        builder.HasIndex(c => c.PackageId);
        builder.HasIndex(c => c.State);
        builder.HasIndex(c => c.CampaignName);
        builder.HasIndex(c => c.TeamCode);
    }
}
