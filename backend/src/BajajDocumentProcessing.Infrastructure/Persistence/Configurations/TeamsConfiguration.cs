using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Teams (formerly Campaign)
/// Teams belongs directly to Package (not Invoice)
/// Cost Summary and Activity Summary are now separate entities
/// </summary>
public class TeamsConfiguration : IEntityTypeConfiguration<Teams>
{
    public void Configure(EntityTypeBuilder<Teams> builder)
    {
        builder.ToTable("Teams");

        builder.HasKey(t => t.Id);

        builder.Property(t => t.CampaignName)
            .HasMaxLength(500);

        builder.Property(t => t.TeamCode)
            .HasMaxLength(100);

        builder.Property(t => t.DealershipName)
            .HasMaxLength(500);

        builder.Property(t => t.DealershipAddress)
            .HasMaxLength(1000);

        builder.Property(t => t.GPSLocation)
            .HasMaxLength(100);

        builder.Property(t => t.State)
            .HasMaxLength(100);

        builder.Property(t => t.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Relationships - Teams belongs directly to Package
        builder.HasOne(t => t.Package)
            .WithMany(p => p.Teams)
            .HasForeignKey(t => t.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        // Indexes
        builder.HasIndex(t => t.PackageId);
        builder.HasIndex(t => t.State);
        builder.HasIndex(t => t.CampaignName);
        builder.HasIndex(t => t.TeamCode);
        builder.HasIndex(t => t.VersionNumber);
    }
}
