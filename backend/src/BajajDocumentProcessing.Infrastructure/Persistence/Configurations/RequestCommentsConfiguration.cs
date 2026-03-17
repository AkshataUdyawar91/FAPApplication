using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration for RequestComments entity.
/// Configures relationships, indexes, and constraints for comment tracking with versioning support.
/// </summary>
public class RequestCommentsConfiguration : IEntityTypeConfiguration<RequestComments>
{
    public void Configure(EntityTypeBuilder<RequestComments> builder)
    {
        // Table name
        builder.ToTable("RequestComments");

        // Primary key
        builder.HasKey(r => r.Id);

        // Properties
        builder.Property(r => r.PackageId)
            .IsRequired();

        builder.Property(r => r.UserId)
            .IsRequired();

        builder.Property(r => r.UserRole)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(r => r.CommentText)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(r => r.CommentDate)
            .IsRequired();

        builder.Property(r => r.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Relationships

        // Many-to-one with DocumentPackage
        builder.HasOne(r => r.DocumentPackage)
            .WithMany(p => p.RequestComments)
            .HasForeignKey(r => r.PackageId)
            .OnDelete(DeleteBehavior.Restrict);

        // Many-to-one with User
        builder.HasOne(r => r.User)
            .WithMany()
            .HasForeignKey(r => r.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        // Indexes

        // Index on PackageId for querying comments by package
        builder.HasIndex(r => r.PackageId)
            .HasDatabaseName("IX_RequestComments_PackageId");

        // Index on UserId for querying comments by user
        builder.HasIndex(r => r.UserId)
            .HasDatabaseName("IX_RequestComments_UserId");

        // Index on CommentDate for chronological queries
        builder.HasIndex(r => r.CommentDate)
            .HasDatabaseName("IX_RequestComments_CommentDate");

        // Composite index on (PackageId, VersionNumber) for version-specific comments
        builder.HasIndex(r => new { r.PackageId, r.VersionNumber })
            .HasDatabaseName("IX_RequestComments_PackageId_VersionNumber");

        // Global query filter for soft delete
        builder.HasQueryFilter(r => !r.IsDeleted);
    }
}
