using BajajDocumentProcessing.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace BajajDocumentProcessing.Application.Common.Interfaces;

/// <summary>
/// Database context interface for application layer
/// </summary>
public interface IApplicationDbContext
{
    DbSet<User> Users { get; }
    DbSet<DocumentPackage> DocumentPackages { get; }
    DbSet<Document> Documents { get; }
    DbSet<Domain.Entities.ValidationResult> ValidationResults { get; }
    DbSet<ConfidenceScore> ConfidenceScores { get; }
    DbSet<Recommendation> Recommendations { get; }
    DbSet<Notification> Notifications { get; }
    DbSet<AuditLog> AuditLogs { get; }
    DbSet<Conversation> Conversations { get; }
    DbSet<ConversationMessage> ConversationMessages { get; }
    
    // Hierarchical structure: FAP -> PO -> Campaigns (Teams) -> Invoices/Photos
    DbSet<Invoice> Invoices { get; }  // Legacy - kept for backward compatibility
    DbSet<Campaign> Campaigns { get; }
    DbSet<CampaignInvoice> CampaignInvoices { get; }
    DbSet<CampaignPhoto> CampaignPhotos { get; }
    
    // Vendor lookup for PO email notifications
    DbSet<Vendor> Vendors { get; }
    DbSet<VendorContact> VendorContacts { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
