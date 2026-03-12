using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using BajajDocumentProcessing.Domain.Entities;

namespace BajajDocumentProcessing.Infrastructure.Persistence.Configurations;

/// <summary>
/// Entity configuration for ASM (Area Sales Manager)
/// </summary>
public class ASMConfiguration : IEntityTypeConfiguration<ASM>
{
    public void Configure(EntityTypeBuilder<ASM> builder)
    {
        builder.ToTable("ASMs");

        builder.HasKey(a => a.Id);

        builder.Property(a => a.Name)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(a => a.Location)
            .IsRequired()
            .HasMaxLength(256);

        builder.Property(a => a.UserId)
            .IsRequired(false); // Nullable - ASM may not have a user account

        builder.Property(a => a.IsDeleted)
            .IsRequired()
            .HasDefaultValue(false);

        // Indexes
        builder.HasIndex(a => a.UserId);
        
        builder.HasIndex(a => a.Location);
        
        builder.HasIndex(a => a.IsDeleted);

        // Optional relationship with User (ASM may not have a user account)
        builder.HasOne(a => a.User)
            .WithMany()
            .HasForeignKey(a => a.UserId)
            .OnDelete(DeleteBehavior.Restrict)
            .IsRequired(false);
    }
}
