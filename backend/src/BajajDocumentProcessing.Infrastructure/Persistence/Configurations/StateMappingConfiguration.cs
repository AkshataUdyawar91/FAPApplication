using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration for StateMapping entity.
/// </summary>
public class StateMappingConfiguration : IEntityTypeConfiguration<StateMapping>
{
    public void Configure(EntityTypeBuilder<StateMapping> builder)
    {
        builder.ToTable("StateMappings");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.State)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.CircleHeadUserId);

        builder.Property(e => e.RAUserId);

        builder.Property(e => e.IsActive)
            .HasDefaultValue(true);

        builder.Property(e => e.IsDeleted)
            .HasDefaultValue(false);

        // One Circle Head per state (unique, nullable filtered)
        builder.HasIndex(e => e.CircleHeadUserId)
            .IsUnique()
            .HasDatabaseName("IX_StateMappings_CircleHeadUserId")
            .HasFilter("[CircleHeadUserId] IS NOT NULL");

        builder.HasIndex(e => e.RAUserId)
            .HasDatabaseName("IX_StateMappings_RAUserId");

        // One mapping per state
        builder.HasIndex(e => e.State)
            .IsUnique()
            .HasDatabaseName("IX_StateMappings_State");

        builder.HasIndex(e => new { e.State, e.IsActive })
            .HasDatabaseName("IX_StateMappings_State_IsActive");
    }
}
