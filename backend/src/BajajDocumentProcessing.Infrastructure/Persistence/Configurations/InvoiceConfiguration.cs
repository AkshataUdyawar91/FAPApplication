using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Invoice
/// </summary>
public class InvoiceConfiguration : IEntityTypeConfiguration<Invoice>
{
    public void Configure(EntityTypeBuilder<Invoice> builder)
    {
        builder.ToTable("Invoices");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.InvoiceNumber)
            .HasMaxLength(100);

        builder.Property(i => i.VendorName)
            .HasMaxLength(500);

        builder.Property(i => i.GSTNumber)
            .HasMaxLength(50);

        builder.Property(i => i.SubTotal)
            .HasColumnType("decimal(18,2)");

        builder.Property(i => i.TaxAmount)
            .HasColumnType("decimal(18,2)");

        builder.Property(i => i.TotalAmount)
            .HasColumnType("decimal(18,2)");

        builder.Property(i => i.FileName)
            .IsRequired()
            .HasMaxLength(512);

        builder.Property(i => i.BlobUrl)
            .IsRequired()
            .HasMaxLength(2048);

        builder.Property(i => i.ContentType)
            .IsRequired()
            .HasMaxLength(128);

        builder.Property(i => i.ExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(i => i.VersionNumber)
            .IsRequired()
            .HasDefaultValue(1);

        // Relationships
        builder.HasOne(i => i.Package)
            .WithMany(p => p.Invoices)
            .HasForeignKey(i => i.PackageId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.PO)
            .WithMany(po => po.Invoices)
            .HasForeignKey(i => i.POId)
            .OnDelete(DeleteBehavior.Restrict);

        // DEPRECATED: PODocumentId relationship - to be removed in future migration
        // builder.HasOne(i => i.PODocument)
        //     .WithMany(d => d.LinkedInvoices)
        //     .HasForeignKey(i => i.PODocumentId)
        //     .OnDelete(DeleteBehavior.Restrict);

        // One-to-one relationship with ValidationResult (polymorphic)
        // ValidationResult now uses DocumentType and DocumentId for polymorphic relationships
        // Ignore navigation to prevent shadow FK
        builder.Ignore(i => i.ValidationResult);

        // Indexes
        builder.HasIndex(i => i.PackageId);
        builder.HasIndex(i => i.POId);
        builder.HasIndex(i => i.InvoiceNumber);
        builder.HasIndex(i => i.VersionNumber);
    }
}
