using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the StateMapping entity.
/// Maps Indian states/UTs to Circle Head and RA users for approval routing.
/// Dealer data has been moved to the Dealers table.
/// </summary>
public class StateMappingConfiguration : IEntityTypeConfiguration<StateMapping>
{
    public void Configure(EntityTypeBuilder<StateMapping> builder)
    {
        builder.ToTable("StateMappings");

        builder.HasKey(s => s.Id);

        builder.Property(s => s.State)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(s => s.CircleHeadUserId);

        builder.Property(s => s.RAUserId);

        builder.Property(s => s.IsActive)
            .IsRequired()
            .HasDefaultValue(true);

        builder.Property(s => s.IsDeleted)
            .IsRequired()
            .HasDefaultValue(false);

        builder.HasQueryFilter(s => !s.IsDeleted);

        // One active mapping per state
        builder.HasIndex(s => s.State)
            .IsUnique()
            .HasDatabaseName("IX_StateMappings_State");

        builder.HasIndex(s => new { s.State, s.IsActive })
            .HasDatabaseName("IX_StateMappings_State_IsActive");

        builder.HasIndex(s => s.CircleHeadUserId)
            .IsUnique()
            .HasFilter("[CircleHeadUserId] IS NOT NULL")
            .HasDatabaseName("IX_StateMappings_CircleHeadUserId");

        builder.HasIndex(s => s.RAUserId)
            .HasDatabaseName("IX_StateMappings_RAUserId");
    }
}
