using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for DocumentPackage
/// </summary>
public class DocumentPackageConfiguration : IEntityTypeConfiguration<DocumentPackage>
{
    public void Configure(EntityTypeBuilder<DocumentPackage> builder)
    {
        builder.ToTable("DocumentPackages");

        builder.HasKey(p => p.Id);

        // Required properties
        builder.Property(p => p.AgencyId)
            .IsRequired();

        builder.Property(p => p.SubmittedByUserId)
            .IsRequired();

        builder.Property(p => p.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        builder.Property(p => p.State)
            .IsRequired()
            .HasConversion<int>();

        // Deprecated properties (commented out for future removal)
        // builder.Property(p => p.ReviewNotes)
        //     .HasMaxLength(2000);

        // Indexes
        builder.HasIndex(p => p.AgencyId)
            .HasDatabaseName("IX_DocumentPackages_AgencyId");

        builder.HasIndex(p => p.SubmittedByUserId)
            .HasDatabaseName("IX_DocumentPackages_SubmittedByUserId");

        builder.HasIndex(p => p.State)
            .HasDatabaseName("IX_DocumentPackages_State");

        builder.HasIndex(p => p.VersionNumber)
            .HasDatabaseName("IX_DocumentPackages_VersionNumber");

        builder.HasIndex(p => p.CreatedAt)
            .HasDatabaseName("IX_DocumentPackages_CreatedAt");

        // Composite indexes for common query patterns
        builder.HasIndex(p => new { p.AgencyId, p.State })
            .HasDatabaseName("IX_DocumentPackages_AgencyId_State");

        builder.HasIndex(p => new { p.SubmittedByUserId, p.CreatedAt })
            .HasDatabaseName("IX_DocumentPackages_SubmittedByUserId_CreatedAt");

        // Relationships
        
        // Many-to-one with Agency
        builder.HasOne(p => p.Agency)
            .WithMany(a => a.DocumentPackages)
            .HasForeignKey(p => p.AgencyId)
            .OnDelete(DeleteBehavior.Restrict);

        // Many-to-one with User (submitter)
        // NOTE: The inverse navigation (User.SubmittedPackages) is configured in UserConfiguration
        builder.HasOne(p => p.SubmittedBy)
            .WithMany(u => u.SubmittedPackages)
            .HasForeignKey(p => p.SubmittedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        // One-to-one with PO
        builder.HasOne(p => p.PO)
            .WithOne(po => po.DocumentPackage)
            .HasForeignKey<PO>(po => po.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        // One-to-one with CostSummary
        builder.HasOne(p => p.CostSummary)
            .WithOne(cs => cs.DocumentPackage)
            .HasForeignKey<CostSummary>(cs => cs.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        // One-to-one with ActivitySummary
        builder.HasOne(p => p.ActivitySummary)
            .WithOne(a => a.DocumentPackage)
            .HasForeignKey<ActivitySummary>(a => a.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        // One-to-one with EnquiryDocument
        builder.HasOne(p => p.EnquiryDocument)
            .WithOne(e => e.DocumentPackage)
            .HasForeignKey<EnquiryDocument>(e => e.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        // One-to-many with AdditionalDocuments
        builder.HasMany(p => p.AdditionalDocuments)
            .WithOne(ad => ad.DocumentPackage)
            .HasForeignKey(ad => ad.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        // NOTE: RequestApprovalHistory relationship is configured in RequestApprovalHistoryConfiguration
        // NOTE: RequestComments relationship is configured in RequestCommentsConfiguration

        // ValidationResult relationship (polymorphic - no direct FK relationship)
        // ValidationResult uses DocumentType and DocumentId for polymorphic relationships
        // Ignore the navigation property to prevent EF from creating shadow FKs
        builder.Ignore(p => p.ValidationResult);

        builder.HasOne(p => p.ConfidenceScore)
            .WithOne(c => c.Package)
            .HasForeignKey<ConfidenceScore>(c => c.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(p => p.Recommendation)
            .WithOne(r => r.Package)
            .HasForeignKey<Recommendation>(r => r.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.Notifications)
            .WithOne(n => n.RelatedPackage)
            .HasForeignKey(n => n.RelatedEntityId)
            .OnDelete(DeleteBehavior.SetNull);

        builder.HasMany(p => p.Invoices)
            .WithOne(i => i.Package)
            .HasForeignKey(i => i.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.Teams)
            .WithOne(c => c.Package)
            .HasForeignKey(c => c.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.TeamPhotos)
            .WithOne(cp => cp.Package)
            .HasForeignKey(cp => cp.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(p => p.CampaignInvoices)
            .WithOne(ci => ci.Package)
            .HasForeignKey(ci => ci.PackageId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
