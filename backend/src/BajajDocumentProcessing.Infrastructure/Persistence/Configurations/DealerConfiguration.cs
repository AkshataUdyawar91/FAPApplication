using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the Dealer entity.
/// </summary>
public class DealerConfiguration : IEntityTypeConfiguration<Dealer>
{
    public void Configure(EntityTypeBuilder<Dealer> builder)
    {
        builder.ToTable("Dealers");

        builder.HasKey(d => d.Id);

        builder.Property(d => d.DealerCode)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(d => d.DealerName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(d => d.State)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(d => d.City)
            .HasMaxLength(100);

        builder.Property(d => d.IsActive)
            .IsRequired()
            .HasDefaultValue(true);

        builder.Property(d => d.IsDeleted)
            .IsRequired()
            .HasDefaultValue(false);

        builder.HasQueryFilter(d => !d.IsDeleted);

        builder.HasIndex(d => d.DealerCode)
            .IsUnique()
            .HasDatabaseName("IX_Dealers_DealerCode");

        builder.HasIndex(d => d.State)
            .HasDatabaseName("IX_Dealers_State");

        builder.HasIndex(d => new { d.State, d.IsActive })
            .HasDatabaseName("IX_Dealers_State_IsActive");
    }
}
