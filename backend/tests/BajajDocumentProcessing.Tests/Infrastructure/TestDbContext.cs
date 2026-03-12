using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using DomainValidationResult = BajajDocumentProcessing.Domain.Entities.ValidationResult;

namespace BajajDocumentProcessing.Tests.Infrastructure;

/// <summary>
/// In-memory database context for unit testing services that depend on IApplicationDbContext
/// </summary>
public class TestDbContext : DbContext, IApplicationDbContext
{
    public TestDbContext(DbContextOptions<TestDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<DocumentPackage> DocumentPackages => Set<DocumentPackage>();
    public DbSet<Document> Documents => Set<Document>();
    public DbSet<DomainValidationResult> ValidationResults => Set<DomainValidationResult>();
    public DbSet<ConfidenceScore> ConfidenceScores => Set<ConfidenceScore>();
    public DbSet<Recommendation> Recommendations => Set<Recommendation>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationMessage> ConversationMessages => Set<ConversationMessage>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<Campaign> Campaigns => Set<Campaign>();
    public DbSet<CampaignInvoice> CampaignInvoices => Set<CampaignInvoice>();
    public DbSet<CampaignPhoto> CampaignPhotos => Set<CampaignPhoto>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
    public DbSet<NotificationPreference> NotificationPreferences => Set<NotificationPreference>();
    public DbSet<NotificationLog> NotificationLogs => Set<NotificationLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure entities without navigation properties to avoid InMemory issues
        modelBuilder.Entity<DeviceToken>(e =>
        {
            e.HasKey(d => d.Id);
            e.Ignore(d => d.User);
        });

        modelBuilder.Entity<NotificationPreference>(e =>
        {
            e.HasKey(p => p.Id);
            e.Ignore(p => p.User);
        });

        modelBuilder.Entity<NotificationLog>(e =>
        {
            e.HasKey(l => l.Id);
            e.Ignore(l => l.User);
            e.Ignore(l => l.DeviceToken);
        });

        // Ignore navigation properties on other entities to keep InMemory simple
        modelBuilder.Entity<User>(e =>
        {
            e.HasKey(u => u.Id);
            e.Ignore(u => u.ReviewedPackages);
        });
        modelBuilder.Entity<DocumentPackage>(e =>
        {
            e.HasKey(d => d.Id);
            e.Ignore(d => d.Documents);
            e.Ignore(d => d.Recommendation);
            e.Ignore(d => d.SubmittedBy);
            e.Ignore(d => d.ReviewedBy);
            e.Ignore(d => d.ASMReviewedBy);
            e.Ignore(d => d.HQReviewedBy);
            e.Ignore(d => d.ValidationResult);
            e.Ignore(d => d.ConfidenceScore);
            e.Ignore(d => d.Notifications);
            e.Ignore(d => d.Invoices);
            e.Ignore(d => d.Campaigns);
            e.Ignore(d => d.CampaignPhotos);
            e.Ignore(d => d.CampaignInvoices);
        });
        modelBuilder.Entity<Document>(e => e.HasKey(d => d.Id));
        modelBuilder.Entity<DomainValidationResult>(e => e.HasKey(v => v.Id));
        modelBuilder.Entity<ConfidenceScore>(e => e.HasKey(c => c.Id));
        modelBuilder.Entity<Recommendation>(e => e.HasKey(r => r.Id));
        modelBuilder.Entity<Notification>(e => e.HasKey(n => n.Id));
        modelBuilder.Entity<AuditLog>(e => e.HasKey(a => a.Id));
        modelBuilder.Entity<Conversation>(e =>
        {
            e.HasKey(c => c.Id);
            e.Ignore(c => c.Messages);
        });
        modelBuilder.Entity<ConversationMessage>(e => e.HasKey(m => m.Id));
        modelBuilder.Entity<Invoice>(e => e.HasKey(i => i.Id));
        modelBuilder.Entity<Campaign>(e =>
        {
            e.HasKey(c => c.Id);
            e.Ignore(c => c.Invoices);
            e.Ignore(c => c.Photos);
        });
        modelBuilder.Entity<CampaignInvoice>(e => e.HasKey(ci => ci.Id));
        modelBuilder.Entity<CampaignPhoto>(e => e.HasKey(cp => cp.Id));
    }
}
