using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Agency
/// </summary>
public class AgencyConfiguration : IEntityTypeConfiguration<Agency>
{
    public void Configure(EntityTypeBuilder<Agency> builder)
    {
        builder.ToTable("Agencies");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.SupplierCode)
            .IsRequired()
            .HasMaxLength(100);

        builder.HasIndex(a => a.SupplierCode)
            .IsUnique();

        builder.Property(a => a.SupplierName)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(a => a.IsDeleted)
            .IsRequired()
            .HasDefaultValue(false);

        builder.HasIndex(a => a.IsDeleted);

        // TODO: Uncomment relationships when corresponding entities are updated
        // Relationships will be enabled in:
        // - Task 3.1: User.Agency navigation property
        // - Task 3.2: DocumentPackage.Agency navigation property
        // - Task 1.3: PO.Agency navigation property
        
        // builder.HasMany(a => a.Users)
        //     .WithOne(u => u.Agency)
        //     .HasForeignKey(u => u.AgencyId)
        //     .OnDelete(DeleteBehavior.Restrict);

        // builder.HasMany(a => a.DocumentPackages)
        //     .WithOne(p => p.Agency)
        //     .HasForeignKey(p => p.AgencyId)
        //     .OnDelete(DeleteBehavior.Restrict);

        // builder.HasMany(a => a.POs)
        //     .WithOne(p => p.Agency)
        //     .HasForeignKey(p => p.AgencyId)
        //     .OnDelete(DeleteBehavior.Restrict);
    }
}
