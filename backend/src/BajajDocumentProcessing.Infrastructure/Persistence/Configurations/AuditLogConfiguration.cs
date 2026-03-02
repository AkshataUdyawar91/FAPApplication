using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for AuditLog
/// </summary>
public class AuditLogConfiguration : IEntityTypeConfiguration<AuditLog>
{
    public void Configure(EntityTypeBuilder<AuditLog> builder)
    {
        builder.ToTable("AuditLogs");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.Action)
            .IsRequired()
            .HasMaxLength(128);

        builder.Property(a => a.EntityType)
            .IsRequired()
            .HasMaxLength(128);

        builder.Property(a => a.OldValuesJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(a => a.NewValuesJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(a => a.IpAddress)
            .IsRequired()
            .HasMaxLength(45); // IPv6 max length

        builder.Property(a => a.UserAgent)
            .IsRequired()
            .HasMaxLength(512);

        builder.HasIndex(a => a.UserId);
        builder.HasIndex(a => a.EntityType);
        builder.HasIndex(a => a.EntityId);
        builder.HasIndex(a => a.CreatedAt);
    }
}
