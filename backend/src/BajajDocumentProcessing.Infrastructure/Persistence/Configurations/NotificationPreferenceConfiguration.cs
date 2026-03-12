using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for NotificationPreference with unique constraints
/// and indexes for efficient user preference lookups
/// </summary>
public class NotificationPreferenceConfiguration : IEntityTypeConfiguration<NotificationPreference>
{
    public void Configure(EntityTypeBuilder<NotificationPreference> builder)
    {
        builder.ToTable("NotificationPreferences");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.UserId)
            .IsRequired();

        builder.Property(p => p.NotificationType)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(p => p.IsPushEnabled)
            .IsRequired()
            .HasDefaultValue(true);

        builder.Property(p => p.IsEmailEnabled)
            .IsRequired()
            .HasDefaultValue(true);

        // Unique constraint: one preference per user-notification type combination
        builder.HasIndex(p => new { p.UserId, p.NotificationType })
            .IsUnique()
            .HasDatabaseName("IX_NotificationPreferences_UserId_NotificationType");

        // Index for efficient lookups by user
        builder.HasIndex(p => p.UserId)
            .HasDatabaseName("IX_NotificationPreferences_UserId");

        // Foreign key: UserId -> Users(Id), restrict delete (soft delete only)
        builder.HasOne(p => p.User)
            .WithMany(u => u.NotificationPreferences)
            .HasForeignKey(p => p.UserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
