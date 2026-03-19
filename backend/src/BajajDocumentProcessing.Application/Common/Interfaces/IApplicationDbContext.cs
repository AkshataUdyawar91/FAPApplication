using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;

// Type aliases for backward compatibility
using Campaign = BajajDocumentProcessing.Domain.Entities.Teams;
using CampaignPhoto = BajajDocumentProcessing.Domain.Entities.TeamPhotos;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Database context interface for application layer
/// </summary>
public interface IApplicationDbContext
{
    DbSet<User> Users { get; }
    DbSet<DocumentPackage> DocumentPackages { get; }
    DbSet<Domain.Entities.ValidationResult> ValidationResults { get; }
    DbSet<ConfidenceScore> ConfidenceScores { get; }
    DbSet<Recommendation> Recommendations { get; }
    DbSet<Notification> Notifications { get; }
    DbSet<AuditLog> AuditLogs { get; }
    DbSet<Conversation> Conversations { get; }
    DbSet<ConversationMessage> ConversationMessages { get; }
    
    // Agency management
    DbSet<Agency> Agencies { get; }

    // Document entities
    DbSet<PO> POs { get; }
    DbSet<Invoice> Invoices { get; }
    DbSet<CostSummary> CostSummaries { get; }
    DbSet<ActivitySummary> ActivitySummaries { get; }
    DbSet<EnquiryDocument> EnquiryDocuments { get; }
    DbSet<AdditionalDocument> AdditionalDocuments { get; }

    // Hierarchical structure: Package -> Teams -> Photos
    DbSet<Teams> Teams { get; }
    DbSet<Campaign> Campaigns { get; }  // Alias for Teams for backward compatibility
    DbSet<TeamPhotos> TeamPhotos { get; }
    DbSet<CampaignPhoto> CampaignPhotos { get; }  // Alias for TeamPhotos for backward compatibility

    // Approval workflow
    DbSet<RequestApprovalHistory> RequestApprovalHistories { get; }
    DbSet<RequestComments> RequestComments { get; }

    // Conversational submission
    DbSet<StateMapping> StateMappings { get; }
    DbSet<SubmissionSequence> SubmissionSequences { get; }

    // Reference data
    DbSet<StateGstMaster> StateGstMasters { get; }
    DbSet<HsnMaster> HsnMasters { get; }
    DbSet<CostMaster> CostMasters { get; }
    DbSet<CostMasterStateRate> CostMasterStateRates { get; }

    // Audit logs
    DbSet<PoBalanceLog> POBalanceLogs { get; }
    DbSet<POSyncLog> POSyncLogs { get; }

    // Email delivery audit
    DbSet<EmailDeliveryLog> EmailDeliveryLogs { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
