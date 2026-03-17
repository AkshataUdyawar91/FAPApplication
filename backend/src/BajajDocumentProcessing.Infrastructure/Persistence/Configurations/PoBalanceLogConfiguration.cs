using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for PoBalanceLog — audit trail for every /api/po-balance call.
/// </summary>
public class PoBalanceLogConfiguration : IEntityTypeConfiguration<PoBalanceLog>
{
    public void Configure(EntityTypeBuilder<PoBalanceLog> builder)
    {
        builder.ToTable("POBalanceLogs");

        builder.HasKey(l => l.Id);

        builder.Property(l => l.Id)
            .HasDefaultValueSql("NEWID()");

        builder.Property(l => l.PoNum)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(l => l.CompanyCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(l => l.RequestedBy)
            .HasMaxLength(450);

        builder.Property(l => l.SapRequestBody)
            .HasColumnType("nvarchar(max)");

        builder.Property(l => l.SapResponseBody)
            .HasMaxLength(4000);

        builder.Property(l => l.Balance)
            .HasColumnType("decimal(18,2)");

        builder.Property(l => l.Currency)
            .HasMaxLength(10);

        builder.Property(l => l.ErrorMessage)
            .HasColumnType("nvarchar(max)");

        builder.Property(l => l.CorrelationId)
            .HasMaxLength(100);

        builder.HasIndex(l => l.PoNum)
            .HasDatabaseName("IX_POBalanceLogs_PoNum");

        builder.HasIndex(l => l.RequestedAt)
            .HasDatabaseName("IX_POBalanceLogs_RequestedAt")
            .IsDescending();

        builder.HasIndex(l => l.IsSuccess)
            .HasDatabaseName("IX_POBalanceLogs_IsSuccess");
    }
}
