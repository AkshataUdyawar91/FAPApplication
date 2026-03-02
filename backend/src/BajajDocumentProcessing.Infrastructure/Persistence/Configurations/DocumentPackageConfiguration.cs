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

        builder.Property(p => p.State)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(p => p.ReviewNotes)
            .HasMaxLength(2000);

        builder.HasIndex(p => p.SubmittedByUserId);
        builder.HasIndex(p => p.ReviewedByUserId);
        builder.HasIndex(p => p.State);
        builder.HasIndex(p => p.CreatedAt);

        // Relationships
        builder.HasMany(p => p.Documents)
            .WithOne(d => d.Package)
            .HasForeignKey(d => d.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(p => p.ValidationResult)
            .WithOne(v => v.Package)
            .HasForeignKey<ValidationResult>(v => v.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

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
    }
}
