using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for CostMaster
/// </summary>
public class CostMasterConfiguration : IEntityTypeConfiguration<CostMaster>
{
    public void Configure(EntityTypeBuilder<CostMaster> builder)
    {
        builder.ToTable("CostMasters");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.ElementName).IsRequired().HasMaxLength(200);
        builder.Property(e => e.ExpenseNature).IsRequired().HasMaxLength(50);

        builder.HasIndex(e => e.ElementName).IsUnique();
    }
}
