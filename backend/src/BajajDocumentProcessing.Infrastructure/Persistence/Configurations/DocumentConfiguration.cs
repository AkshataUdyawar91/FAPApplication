using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for Document
/// </summary>
public class DocumentConfiguration : IEntityTypeConfiguration<Document>
{
    public void Configure(EntityTypeBuilder<Document> builder)
    {
        builder.ToTable("Documents");

        builder.HasKey(d => d.Id);

        builder.Property(d => d.Type)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(d => d.FileName)
            .IsRequired()
            .HasMaxLength(512);

        builder.Property(d => d.BlobUrl)
            .IsRequired()
            .HasMaxLength(2048);

        builder.Property(d => d.ContentType)
            .IsRequired()
            .HasMaxLength(128);

        builder.Property(d => d.ExtractedDataJson)
            .HasColumnType("nvarchar(max)");

        builder.HasIndex(d => d.PackageId);
        builder.HasIndex(d => d.Type);
    }
}
