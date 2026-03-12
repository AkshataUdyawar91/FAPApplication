using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for VendorContact
/// </summary>
public class VendorContactConfiguration : IEntityTypeConfiguration<VendorContact>
{
    public void Configure(EntityTypeBuilder<VendorContact> builder)
    {
        builder.ToTable("VendorContacts");

        builder.HasKey(vc => vc.Id);

        builder.Property(vc => vc.ContactName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(vc => vc.Email)
            .IsRequired()
            .HasMaxLength(320);

        // Index on VendorId for fast lookups
        builder.HasIndex(vc => vc.VendorId);
        builder.HasIndex(vc => vc.Email);
    }
}
