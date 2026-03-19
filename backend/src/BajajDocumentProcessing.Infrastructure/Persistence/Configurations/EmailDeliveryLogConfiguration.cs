using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// EF Core configuration for EmailDeliveryLog.
/// No FK constraint to DocumentPackages — PackageId is a plain column for audit purposes.
/// </summary>
public class EmailDeliveryLogConfiguration : IEntityTypeConfiguration<EmailDeliveryLog>
{
    public void Configure(EntityTypeBuilder<EmailDeliveryLog> builder)
    {
        builder.ToTable("EmailDeliveryLogs");

        builder.HasKey(e => e.Id);

        builder.Property(e => e.PackageId)
            .IsRequired();

        builder.Property(e => e.TemplateName)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(e => e.RecipientEmail)
            .IsRequired()
            .HasMaxLength(2000);

        builder.Property(e => e.Subject)
            .IsRequired()
            .HasMaxLength(500);

        builder.Property(e => e.Success)
            .IsRequired();

        builder.Property(e => e.MessageId)
            .HasMaxLength(200);

        builder.Property(e => e.ErrorMessage)
            .HasMaxLength(2000);

        builder.Property(e => e.AttemptsCount)
            .IsRequired();

        builder.Property(e => e.SentAt)
            .IsRequired();

        // Ignore the navigation property — no FK constraint
        builder.Ignore(e => e.Package);

        // Index for querying logs by package
        builder.HasIndex(e => e.PackageId)
            .HasDatabaseName("IX_EmailDeliveryLogs_PackageId");

        // Index for querying by template name
        builder.HasIndex(e => e.TemplateName)
            .HasDatabaseName("IX_EmailDeliveryLogs_TemplateName");
    }
}
