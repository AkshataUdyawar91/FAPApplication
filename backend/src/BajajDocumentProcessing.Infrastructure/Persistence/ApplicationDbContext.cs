using Microsoft.EntityFrameworkCore;
using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Domain.Entities;

// Type aliases for backward compatibility
using Campaign = BajajDocumentProcessing.Domain.Entities.Teams;
using CampaignPhoto = BajajDocumentProcessing.Domain.Entities.TeamPhotos;

namespace BajajDocumentProcessing.Infrastructure.Persistence;

/// <summary>
/// Application database context
/// </summary>
public class ApplicationDbContext : DbContext, IApplicationDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    // Core entities
    public DbSet<User> Users => Set<User>();
    public DbSet<Agency> Agencies => Set<Agency>();
    public DbSet<DocumentPackage> DocumentPackages => Set<DocumentPackage>();
    
    // Document entities
    public DbSet<PO> POs => Set<PO>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<CostSummary> CostSummaries => Set<CostSummary>();
    public DbSet<ActivitySummary> ActivitySummaries => Set<ActivitySummary>();
    public DbSet<EnquiryDocument> EnquiryDocuments => Set<EnquiryDocument>();
    public DbSet<AdditionalDocument> AdditionalDocuments => Set<AdditionalDocument>();
    
    // Team entities (renamed from Campaign)
    public DbSet<Teams> Teams => Set<Teams>();
    public DbSet<Campaign> Campaigns => Set<Teams>();  // Alias for backward compatibility
    public DbSet<TeamPhotos> TeamPhotos => Set<TeamPhotos>();
    public DbSet<CampaignPhoto> CampaignPhotos => Set<TeamPhotos>();  // Alias for backward compatibility
    
    // Validation and scoring
    public DbSet<ValidationResult> ValidationResults => Set<ValidationResult>();
    public DbSet<ConfidenceScore> ConfidenceScores => Set<ConfidenceScore>();
    public DbSet<Recommendation> Recommendations => Set<Recommendation>();
    
    // Approval workflow
    public DbSet<RequestApprovalHistory> RequestApprovalHistories => Set<RequestApprovalHistory>();
    public DbSet<RequestComments> RequestComments => Set<RequestComments>();
    
    // Notifications and audit
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();
    
    // Chat
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationMessage> ConversationMessages => Set<ConversationMessage>();

    // Conversational submission
    public DbSet<StateMapping> StateMappings => Set<StateMapping>();
    public DbSet<SubmissionSequence> SubmissionSequences => Set<SubmissionSequence>();

    // Reference data
    public DbSet<StateGstMaster> StateGstMasters => Set<StateGstMaster>();
    public DbSet<HsnMaster> HsnMasters => Set<HsnMaster>();
    public DbSet<CostMaster> CostMasters => Set<CostMaster>();
    public DbSet<CostMasterStateRate> CostMasterStateRates => Set<CostMasterStateRate>();

    // Audit logs
    public DbSet<PoBalanceLog> POBalanceLogs => Set<PoBalanceLog>();
    public DbSet<POSyncLog> POSyncLogs => Set<POSyncLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Apply all configurations from assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);

        // Global query filter for soft delete
        modelBuilder.Entity<User>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Agency>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<DocumentPackage>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<PO>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Invoice>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<CostSummary>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<ActivitySummary>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<EnquiryDocument>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<AdditionalDocument>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Teams>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<TeamPhotos>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<ValidationResult>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<ConfidenceScore>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Recommendation>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<RequestApprovalHistory>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<RequestComments>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Notification>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<AuditLog>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<Conversation>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<ConversationMessage>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<StateMapping>().HasQueryFilter(e => !e.IsDeleted);

        modelBuilder.Entity<POSyncLog>().HasQueryFilter(e => !e.IsDeleted);

        // Reference data soft-delete filters
        modelBuilder.Entity<StateGstMaster>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<HsnMaster>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<CostMaster>().HasQueryFilter(e => !e.IsDeleted);
        modelBuilder.Entity<CostMasterStateRate>().HasQueryFilter(e => !e.IsDeleted);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        // Set timestamps
        var entries = ChangeTracker.Entries()
            .Where(e => e.State == EntityState.Added || e.State == EntityState.Modified);

        foreach (var entry in entries)
        {
            if (entry.Entity is Domain.Common.BaseEntity entity)
            {
                if (entry.State == EntityState.Added)
                {
                    entity.CreatedAt = DateTime.UtcNow;
                }
                entity.UpdatedAt = DateTime.UtcNow;
            }
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
