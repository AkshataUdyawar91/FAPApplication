using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Campaign
/// </summary>
public class CampaignConfiguration : IEntityTypeConfiguration<Campaign>
{
    public void Configure(EntityTypeBuilder<Campaign> builder)
    {
        builder.ToTable("Campaigns");

        builder.HasKey(c => c.Id);

        builder.Property(c => c.CampaignName)
            .HasMaxLength(500);

        builder.Property(c => c.DealershipName)
            .HasMaxLength(500);

        builder.Property(c => c.DealershipAddress)
            .HasMaxLength(1000);

        builder.Property(c => c.GPSLocation)
            .HasMaxLength(100);

        builder.Property(c => c.State)
            .HasMaxLength(100);

        builder.Property(c => c.TotalCost)
            .HasColumnType("decimal(18,2)");

        builder.Property(c => c.CostBreakdownJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(c => c.TeamsJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(c => c.CostSummaryFileName)
            .HasMaxLength(512);

        builder.Property(c => c.CostSummaryBlobUrl)
            .HasMaxLength(2048);

        builder.Property(c => c.CostSummaryExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        // Relationships
        builder.HasOne(c => c.Invoice)
            .WithMany(i => i.Campaigns)
            .HasForeignKey(c => c.InvoiceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(c => c.Package)
            .WithMany(p => p.Campaigns)
            .HasForeignKey(c => c.PackageId)
            .OnDelete(DeleteBehavior.Restrict);

        // Indexes
        builder.HasIndex(c => c.InvoiceId);
        builder.HasIndex(c => c.PackageId);
        builder.HasIndex(c => c.State);
        builder.HasIndex(c => c.CampaignName);
    }
}
