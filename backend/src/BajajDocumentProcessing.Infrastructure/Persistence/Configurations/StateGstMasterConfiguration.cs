using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for StateGstMaster
/// </summary>
public class StateGstMasterConfiguration : IEntityTypeConfiguration<StateGstMaster>
{
    public void Configure(EntityTypeBuilder<StateGstMaster> builder)
    {
        builder.ToTable("StateGstMasters");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.GstPercentage).HasColumnType("decimal(5,2)");
        builder.Property(e => e.StateCode).IsRequired().HasMaxLength(10);
        builder.Property(e => e.StateName).IsRequired().HasMaxLength(100);
    }
}
