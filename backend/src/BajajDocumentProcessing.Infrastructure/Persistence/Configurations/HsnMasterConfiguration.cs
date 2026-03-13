using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for HsnMaster
/// </summary>
public class HsnMasterConfiguration : IEntityTypeConfiguration<HsnMaster>
{
    public void Configure(EntityTypeBuilder<HsnMaster> builder)
    {
        builder.ToTable("HsnMasters");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Code).IsRequired().HasMaxLength(20);
        builder.Property(e => e.Description).IsRequired().HasMaxLength(500);

        builder.HasIndex(e => e.Code).IsUnique();
    }
}
