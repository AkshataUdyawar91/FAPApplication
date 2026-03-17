using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the StateMapping entity.
/// Maps Indian states/UTs to dealers and CIRCLE HEAD users.
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

        builder.Property(s => s.DealerCode)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(s => s.DealerName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(s => s.City)
            .HasMaxLength(100);

        builder.Property(s => s.CircleHeadUserId);

        builder.Property(s => s.IsActive)
            .IsRequired()
            .HasDefaultValue(true);

        builder.Property(s => s.IsDeleted)
            .IsRequired()
            .HasDefaultValue(false);

        // Indexes
        builder.HasIndex(s => s.State)
            .HasDatabaseName("IX_StateMappings_State");

        builder.HasIndex(s => s.DealerCode)
            .HasDatabaseName("IX_StateMappings_DealerCode");

        builder.HasIndex(s => new { s.State, s.IsActive })
            .HasDatabaseName("IX_StateMappings_State_IsActive");
    }
}
