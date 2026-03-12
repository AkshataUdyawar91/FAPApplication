using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for DeviceToken with unique constraints and indexes
/// for efficient push notification device token management
/// </summary>
public class DeviceTokenConfiguration : IEntityTypeConfiguration<DeviceToken>
{
    public void Configure(EntityTypeBuilder<DeviceToken> builder)
    {
        builder.ToTable("DeviceTokens");

        builder.HasKey(d => d.Id);

        builder.Property(d => d.UserId)
            .IsRequired();

        builder.Property(d => d.Platform)
            .IsRequired()
            .HasMaxLength(50);

        builder.Property(d => d.Token)
            .IsRequired();

        builder.Property(d => d.RegisteredAt)
            .IsRequired();

        builder.Property(d => d.LastUsedAt)
            .IsRequired();

        builder.Property(d => d.IsActive)
            .IsRequired()
            .HasDefaultValue(true);

        // Unique constraint: one token per user-platform-token combination
        builder.HasIndex(d => new { d.UserId, d.Platform, d.Token })
            .IsUnique()
            .HasDatabaseName("IX_DeviceTokens_UserId_Platform_Token");

        // Index for efficient lookups by user and platform
        builder.HasIndex(d => new { d.UserId, d.Platform })
            .HasDatabaseName("IX_DeviceTokens_UserId_Platform");

        // Index for filtering active tokens
        builder.HasIndex(d => d.IsActive)
            .HasDatabaseName("IX_DeviceTokens_IsActive");

        // Foreign key: UserId -> Users(Id), restrict delete (soft delete only)
        builder.HasOne(d => d.User)
            .WithMany(u => u.DeviceTokens)
            .HasForeignKey(d => d.UserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
