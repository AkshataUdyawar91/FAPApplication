using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for NotificationLog with indexes for efficient
/// history queries and correlation tracing
/// </summary>
public class NotificationLogConfiguration : IEntityTypeConfiguration<NotificationLog>
{
    public void Configure(EntityTypeBuilder<NotificationLog> builder)
    {
        builder.ToTable("NotificationLogs");

        builder.HasKey(l => l.Id);

        builder.Property(l => l.UserId)
            .IsRequired();

        builder.Property(l => l.NotificationType)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(l => l.Channel)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(l => l.Platform)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(l => l.Status)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(l => l.ErrorMessage)
            .HasColumnType("nvarchar(max)");

        builder.Property(l => l.SentAt)
            .IsRequired();

        builder.Property(l => l.CorrelationId)
            .IsRequired()
            .HasMaxLength(100);

        // Index for history queries by user and sent date
        builder.HasIndex(l => new { l.UserId, l.SentAt })
            .HasDatabaseName("IX_NotificationLogs_UserId_SentAt");

        // Index for correlation tracing
        builder.HasIndex(l => l.CorrelationId)
            .HasDatabaseName("IX_NotificationLogs_CorrelationId");

        // Foreign key: UserId -> Users(Id), restrict delete (soft delete only)
        builder.HasOne(l => l.User)
            .WithMany(u => u.NotificationLogs)
            .HasForeignKey(l => l.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        // Foreign key: DeviceTokenId -> DeviceTokens(Id), set null on delete
        builder.HasOne(l => l.DeviceToken)
            .WithMany()
            .HasForeignKey(l => l.DeviceTokenId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
