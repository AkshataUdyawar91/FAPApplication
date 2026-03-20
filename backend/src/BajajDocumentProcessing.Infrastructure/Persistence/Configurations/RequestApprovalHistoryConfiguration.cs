using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration for RequestApprovalHistory entity.
/// Configures relationships, indexes, and constraints for approval workflow tracking.
/// </summary>
public class RequestApprovalHistoryConfiguration : IEntityTypeConfiguration<RequestApprovalHistory>
{
    public void Configure(EntityTypeBuilder<RequestApprovalHistory> builder)
    {
        // Table name
        builder.ToTable("RequestApprovalHistory");

        // Primary key
        builder.HasKey(r => r.Id);

        // Properties
        builder.Property(r => r.PackageId)
            .IsRequired();

        builder.Property(r => r.ApproverId)
            .IsRequired();

        builder.Property(r => r.ApproverRole)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(r => r.Action)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(r => r.Comments)
            .HasMaxLength(2000);

        builder.Property(r => r.ActionDate)
            .IsRequired();

        builder.Property(r => r.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        builder.Property(r => r.Channel)
            .HasMaxLength(50);

        // Relationships

        // Many-to-one with DocumentPackage
        builder.HasOne(r => r.DocumentPackage)
            .WithMany(p => p.RequestApprovalHistory)
            .HasForeignKey(r => r.PackageId)
            .OnDelete(DeleteBehavior.Restrict);

        // Many-to-one with User (Approver)
        builder.HasOne(r => r.Approver)
            .WithMany()
            .HasForeignKey(r => r.ApproverId)
            .OnDelete(DeleteBehavior.Restrict);

        // Indexes

        // Index on PackageId for querying approval history by package
        builder.HasIndex(r => r.PackageId)
            .HasDatabaseName("IX_RequestApprovalHistory_PackageId");

        // Index on ApproverId for querying actions by approver
        builder.HasIndex(r => r.ApproverId)
            .HasDatabaseName("IX_RequestApprovalHistory_ApproverId");

        // Index on ApproverRole for filtering by role
        builder.HasIndex(r => r.ApproverRole)
            .HasDatabaseName("IX_RequestApprovalHistory_ApproverRole");

        // Index on ActionDate for chronological queries
        builder.HasIndex(r => r.ActionDate)
            .HasDatabaseName("IX_RequestApprovalHistory_ActionDate");

        // Composite index on (PackageId, VersionNumber) for version-specific history
        builder.HasIndex(r => new { r.PackageId, r.VersionNumber })
            .HasDatabaseName("IX_RequestApprovalHistory_PackageId_VersionNumber");

        // Composite index on (PackageId, ActionDate) for chronological package history
        builder.HasIndex(r => new { r.PackageId, r.ActionDate })
            .HasDatabaseName("IX_RequestApprovalHistory_PackageId_ActionDate");

        // Global query filter for soft delete
        builder.HasQueryFilter(r => !r.IsDeleted);
    }
}
