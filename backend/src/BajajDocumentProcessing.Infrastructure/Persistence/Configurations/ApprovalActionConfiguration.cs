using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for ApprovalAction audit trail records
/// </summary>
public class ApprovalActionConfiguration : IEntityTypeConfiguration<ApprovalAction>
{
    public void Configure(EntityTypeBuilder<ApprovalAction> builder)
    {
        builder.ToTable("ApprovalActions");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.ActionType)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(a => a.PreviousState)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(a => a.NewState)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(a => a.Comment)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(a => a.ActionTimestamp)
            .IsRequired();

        // Indexes
        builder.HasIndex(a => a.PackageId);
        builder.HasIndex(a => new { a.PackageId, a.ActionTimestamp });

        // Relationships
        builder.HasOne(a => a.Package)
            .WithMany(p => p.ApprovalActions)
            .HasForeignKey(a => a.PackageId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(a => a.ActorUser)
            .WithMany()
            .HasForeignKey(a => a.ActorUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
