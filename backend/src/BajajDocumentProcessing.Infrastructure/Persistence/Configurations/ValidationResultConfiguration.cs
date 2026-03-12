using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for ValidationResult
/// </summary>
public class ValidationResultConfiguration : IEntityTypeConfiguration<ValidationResult>
{
    public void Configure(EntityTypeBuilder<ValidationResult> builder)
    {
        builder.ToTable("ValidationResults");

        builder.HasKey(v => v.Id);

        builder.Property(v => v.DocumentType)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(v => v.DocumentId)
            .IsRequired();

        builder.Property(v => v.ValidationDetailsJson)
            .HasColumnType("nvarchar(max)");

        builder.Property(v => v.FailureReason)
            .HasMaxLength(2000);

        builder.HasIndex(v => new { v.DocumentType, v.DocumentId })
            .IsUnique();
    }
}
