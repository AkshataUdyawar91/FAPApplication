using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Notification
/// </summary>
public class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        builder.ToTable("Notifications");

        builder.HasKey(n => n.Id);

        builder.Property(n => n.Type)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(n => n.Title)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(n => n.Message)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(n => n.IsRead)
            .IsRequired()
            .HasDefaultValue(false);

        // Multi-channel delivery tracking fields
        builder.Property(n => n.Channel)
            .IsRequired()
            .HasConversion<int>()
            .HasDefaultValue(NotificationChannel.InApp);

        builder.Property(n => n.DeliveryStatus)
            .IsRequired()
            .HasConversion<int>()
            .HasDefaultValue(NotificationDeliveryStatus.Sent);

        builder.Property(n => n.RetryCount)
            .IsRequired()
            .HasDefaultValue(0);

        builder.Property(n => n.SentAt)
            .HasColumnType("datetime2");

        builder.Property(n => n.ExternalMessageId)
            .HasMaxLength(500);

        builder.Property(n => n.FailureReason)
            .HasMaxLength(2000);

        // Existing indexes
        builder.HasIndex(n => n.UserId);
        builder.HasIndex(n => n.IsRead);
        builder.HasIndex(n => n.CreatedAt);

        // Composite indexes for multi-channel notification queries
        builder.HasIndex(n => new { n.UserId, n.Channel, n.DeliveryStatus })
            .HasDatabaseName("IX_Notifications_UserId_Channel_DeliveryStatus");

        builder.HasIndex(n => new { n.RelatedEntityId, n.Channel })
            .HasDatabaseName("IX_Notifications_RelatedEntityId_Channel");
    }
}
