using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for CostMasterStateRate
/// </summary>
public class CostMasterStateRateConfiguration : IEntityTypeConfiguration<CostMasterStateRate>
{
    public void Configure(EntityTypeBuilder<CostMasterStateRate> builder)
    {
        builder.ToTable("CostMasterStateRates");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.StateCode).IsRequired().HasMaxLength(50);
        builder.Property(e => e.ElementName).IsRequired().HasMaxLength(200);
        builder.Property(e => e.RateValue).HasColumnType("decimal(18,2)");
        builder.Property(e => e.RateType).IsRequired().HasMaxLength(20);

        builder.HasIndex(e => new { e.StateCode, e.ElementName }).IsUnique();
    }
}
