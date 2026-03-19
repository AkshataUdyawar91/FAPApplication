using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the StateCity master data entity.
/// </summary>
public class StateCityConfiguration : IEntityTypeConfiguration<StateCity>
{
    public void Configure(EntityTypeBuilder<StateCity> builder)
    {
        builder.ToTable("StateCities");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.State)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(s => s.City)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(s => s.IsActive)
            .IsRequired()
            .HasDefaultValue(true);

        builder.Property(s => s.IsDeleted)
            .IsRequired()
            .HasDefaultValue(false);

        builder.HasQueryFilter(s => !s.IsDeleted);

        // Unique: one city per state (no duplicate city entries for same state)
        builder.HasIndex(s => new { s.State, s.City })
            .IsUnique()
            .HasDatabaseName("IX_StateCities_State_City");

        builder.HasIndex(s => s.State)
            .HasDatabaseName("IX_StateCities_State");
    }
}
