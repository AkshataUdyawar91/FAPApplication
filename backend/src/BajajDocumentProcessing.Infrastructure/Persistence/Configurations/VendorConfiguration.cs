using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Vendor
/// </summary>
public class VendorConfiguration : IEntityTypeConfiguration<Vendor>
{
    public void Configure(EntityTypeBuilder<Vendor> builder)
    {
        builder.ToTable("Vendors");

        builder.HasKey(v => v.Id);

        builder.Property(v => v.VendorCode)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(v => v.VendorName)
            .IsRequired()
            .HasMaxLength(500);

        // 1:many — one vendor has many contacts
        builder.HasMany(v => v.Contacts)
            .WithOne(c => c.Vendor)
            .HasForeignKey(c => c.VendorId)
            .OnDelete(DeleteBehavior.Cascade);

        // Indexes
        builder.HasIndex(v => v.VendorCode).IsUnique();
        builder.HasIndex(v => v.VendorName);
    }
}
