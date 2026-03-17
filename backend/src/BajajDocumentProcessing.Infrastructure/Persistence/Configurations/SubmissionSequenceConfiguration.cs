using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity Framework Core configuration for the SubmissionSequence entity.
/// Simple table with Year as PK for thread-safe submission number generation.
/// </summary>
public class SubmissionSequenceConfiguration : IEntityTypeConfiguration<SubmissionSequence>
{
    public void Configure(EntityTypeBuilder<SubmissionSequence> builder)
    {
        builder.ToTable("SubmissionSequences");

        builder.HasKey(s => s.Year);

        builder.Property(s => s.Year)
            .ValueGeneratedNever();

        builder.Property(s => s.LastNumber)
            .IsRequired()
            .HasDefaultValue(0);
    }
}
