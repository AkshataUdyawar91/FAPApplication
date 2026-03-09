using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration for CampaignInvoice entity
/// </summary>
public class CampaignInvoiceConfiguration : IEntityTypeConfiguration<CampaignInvoice>
{
    public void Configure(EntityTypeBuilder<CampaignInvoice> builder)
    {
        builder.ToTable("CampaignInvoices");

        builder.HasKey(ci => ci.Id);

        builder.Property(ci => ci.InvoiceNumber)
            .HasMaxLength(100);

        builder.Property(ci => ci.VendorName)
            .HasMaxLength(500);

        builder.Property(ci => ci.GSTNumber)
            .HasMaxLength(50);

        builder.Property(ci => ci.SubTotal)
            .HasPrecision(18, 2);

        builder.Property(ci => ci.TaxAmount)
            .HasPrecision(18, 2);

        builder.Property(ci => ci.TotalAmount)
            .HasPrecision(18, 2);

        builder.Property(ci => ci.FileName)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(ci => ci.BlobUrl)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(ci => ci.ContentType)
            .IsRequired()
            .HasMaxLength(100);

        // Relationship: CampaignInvoice belongs to Campaign
        builder.HasOne(ci => ci.Campaign)
            .WithMany(c => c.Invoices)
            .HasForeignKey(ci => ci.CampaignId)
            .OnDelete(DeleteBehavior.Restrict);

        // Relationship: CampaignInvoice belongs to Package (for easier querying)
        builder.HasOne(ci => ci.Package)
            .WithMany(p => p.CampaignInvoices)
            .HasForeignKey(ci => ci.PackageId)
            .OnDelete(DeleteBehavior.Restrict);

        // Indexes
        builder.HasIndex(ci => ci.CampaignId);
        builder.HasIndex(ci => ci.PackageId);
        builder.HasIndex(ci => ci.InvoiceNumber);
    }
}
