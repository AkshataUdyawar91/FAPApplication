using BajajDocumentProcessing.Domain.Entities;
using BajajDocumentProcessing.Domain.Enums;
using BajajDocumentProcessing.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BajajDocumentProcessing.Tests.Domain;

/// <summary>
/// Unit tests for new and modified entities introduced in the database redesign.
/// Validates entity creation, relationships, enum values, and persistence.
/// </summary>
public class DatabaseRedesignEntityTests
{
    private ApplicationDbContext CreateInMemoryContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        return new ApplicationDbContext(options);
    }

    #region Enum Tests

    [Fact]
    public void UserRole_HasExpectedValues()
    {
        Assert.Equal(1, (int)UserRole.Agency);
        Assert.Equal(2, (int)UserRole.ASM);
        Assert.Equal(3, (int)UserRole.RA);
        Assert.Equal(4, (int)UserRole.Admin);
        Assert.Equal(4, Enum.GetValues<UserRole>().Length);
    }

    [Fact]
    public void PackageState_HasExpectedValues()
    {
        Assert.Equal(1, (int)PackageState.Uploaded);
        Assert.Equal(2, (int)PackageState.Extracting);
        Assert.Equal(3, (int)PackageState.Validating);
        Assert.Equal(4, (int)PackageState.PendingASM);
        Assert.Equal(5, (int)PackageState.ASMRejected);
        Assert.Equal(6, (int)PackageState.PendingRA);
        Assert.Equal(7, (int)PackageState.RARejected);
        Assert.Equal(0, (int)PackageState.Draft);
        Assert.Equal(8, (int)PackageState.Approved);
        Assert.Equal(9, Enum.GetValues<PackageState>().Length);
    }

    [Fact]
    public void ApprovalAction_HasExpectedValues()
    {
        Assert.Equal(1, (int)ApprovalAction.Submitted);
        Assert.Equal(2, (int)ApprovalAction.Approved);
        Assert.Equal(3, (int)ApprovalAction.Rejected);
        Assert.Equal(4, (int)ApprovalAction.Resubmitted);
        Assert.Equal(4, Enum.GetValues<ApprovalAction>().Length);
    }

    [Fact]
    public void DocumentType_HasExpectedValues()
    {
        Assert.Equal(1, (int)DocumentType.PO);
        Assert.Equal(2, (int)DocumentType.Invoice);
        Assert.Equal(3, (int)DocumentType.CostSummary);
        Assert.Equal(4, (int)DocumentType.ActivitySummary);
        Assert.Equal(5, (int)DocumentType.EnquiryDocument);
        Assert.Equal(6, (int)DocumentType.TeamPhoto);
        Assert.Equal(6, Enum.GetValues<DocumentType>().Length);
    }

    #endregion

    #region Agency Entity Tests

    [Fact]
    public async Task Agency_CanBeCreatedAndPersisted()
    {
        await using var context = CreateInMemoryContext();

        var agency = new Agency
        {
            Id = Guid.NewGuid(),
            SupplierCode = "SUP001",
            SupplierName = "Test Agency",
            CreatedAt = DateTime.UtcNow
        };

        await context.Agencies.AddAsync(agency);
        await context.SaveChangesAsync();

        var saved = await context.Agencies.FindAsync(agency.Id);
        Assert.NotNull(saved);
        Assert.Equal("SUP001", saved.SupplierCode);
        Assert.Equal("Test Agency", saved.SupplierName);
    }

    [Fact]
    public async Task Agency_HasUsersNavigation()
    {
        await using var context = CreateInMemoryContext();
        var agencyId = Guid.NewGuid();

        var agency = new Agency
        {
            Id = agencyId,
            SupplierCode = "SUP002",
            SupplierName = "Agency With Users",
            CreatedAt = DateTime.UtcNow
        };

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = "agent@test.com",
            PasswordHash = "hash",
            FullName = "Agent User",
            Role = UserRole.Agency,
            AgencyId = agencyId,
            CreatedAt = DateTime.UtcNow
        };

        await context.Agencies.AddAsync(agency);
        await context.Users.AddAsync(user);
        await context.SaveChangesAsync();

        var saved = await context.Agencies
            .Include(a => a.Users)
            .FirstAsync(a => a.Id == agencyId);

        Assert.Single(saved.Users);
        Assert.Equal(agencyId, saved.Users.First().AgencyId);
    }

    #endregion

    #region ASM Entity Tests

    [Fact]
    public async Task ASM_CanBeCreatedWithoutUser()
    {
        await using var context = CreateInMemoryContext();

        var asm = new ASM
        {
            Id = Guid.NewGuid(),
            Name = "Test ASM",
            Location = "North Region",
            UserId = null,
            CreatedAt = DateTime.UtcNow
        };

        await context.ASMs.AddAsync(asm);
        await context.SaveChangesAsync();

        var saved = await context.ASMs.FindAsync(asm.Id);
        Assert.NotNull(saved);
        Assert.Equal("Test ASM", saved.Name);
        Assert.Equal("North Region", saved.Location);
        Assert.Null(saved.UserId);
    }

    [Fact]
    public async Task ASM_CanBeLinkedToUser()
    {
        await using var context = CreateInMemoryContext();
        var userId = Guid.NewGuid();

        var user = new User
        {
            Id = userId,
            Email = "asm@test.com",
            PasswordHash = "hash",
            FullName = "ASM User",
            Role = UserRole.ASM,
            CreatedAt = DateTime.UtcNow
        };

        var asm = new ASM
        {
            Id = Guid.NewGuid(),
            Name = "Linked ASM",
            Location = "South Region",
            UserId = userId,
            CreatedAt = DateTime.UtcNow
        };

        await context.Users.AddAsync(user);
        await context.ASMs.AddAsync(asm);
        await context.SaveChangesAsync();

        var saved = await context.ASMs
            .Include(a => a.User)
            .FirstAsync(a => a.Id == asm.Id);

        Assert.NotNull(saved.User);
        Assert.Equal(userId, saved.UserId);
    }

    #endregion

    #region RequestApprovalHistory Tests

    [Fact]
    public async Task RequestApprovalHistory_CanBeCreated()
    {
        await using var context = CreateInMemoryContext();
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();

        var user = new User
        {
            Id = userId,
            Email = "approver@test.com",
            PasswordHash = "hash",
            FullName = "Approver",
            Role = UserRole.ASM,
            CreatedAt = DateTime.UtcNow
        };

        var package = new DocumentPackage
        {
            Id = packageId,
            SubmittedByUserId = userId,
            State = PackageState.PendingASM,
            CreatedAt = DateTime.UtcNow
        };

        var history = new RequestApprovalHistory
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            ApproverId = userId,
            ApproverRole = UserRole.ASM,
            Action = ApprovalAction.Approved,
            Comments = "Looks good",
            ActionDate = DateTime.UtcNow,
            VersionNumber = 1,
            CreatedAt = DateTime.UtcNow
        };

        await context.Users.AddAsync(user);
        await context.DocumentPackages.AddAsync(package);
        await context.RequestApprovalHistories.AddAsync(history);
        await context.SaveChangesAsync();

        var saved = await context.RequestApprovalHistories
            .Include(h => h.Approver)
            .Include(h => h.DocumentPackage)
            .FirstAsync(h => h.Id == history.Id);

        Assert.Equal(ApprovalAction.Approved, saved.Action);
        Assert.Equal(UserRole.ASM, saved.ApproverRole);
        Assert.Equal("Looks good", saved.Comments);
        Assert.Equal(1, saved.VersionNumber);
        Assert.NotNull(saved.Approver);
        Assert.NotNull(saved.DocumentPackage);
    }

    [Theory]
    [InlineData(ApprovalAction.Submitted, UserRole.Agency)]
    [InlineData(ApprovalAction.Approved, UserRole.ASM)]
    [InlineData(ApprovalAction.Rejected, UserRole.ASM)]
    [InlineData(ApprovalAction.Approved, UserRole.RA)]
    [InlineData(ApprovalAction.Rejected, UserRole.RA)]
    [InlineData(ApprovalAction.Resubmitted, UserRole.Agency)]
    public async Task RequestApprovalHistory_SupportsAllActionRoleCombinations(
        ApprovalAction action, UserRole role)
    {
        await using var context = CreateInMemoryContext();
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();

        await context.Users.AddAsync(new User
        {
            Id = userId, Email = $"{userId}@test.com", PasswordHash = "hash",
            FullName = "User", Role = role, CreatedAt = DateTime.UtcNow
        });
        await context.DocumentPackages.AddAsync(new DocumentPackage
        {
            Id = packageId, SubmittedByUserId = userId,
            State = PackageState.Uploaded, CreatedAt = DateTime.UtcNow
        });

        var history = new RequestApprovalHistory
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            ApproverId = userId,
            ApproverRole = role,
            Action = action,
            ActionDate = DateTime.UtcNow,
            VersionNumber = 1,
            CreatedAt = DateTime.UtcNow
        };

        await context.RequestApprovalHistories.AddAsync(history);
        await context.SaveChangesAsync();

        var saved = await context.RequestApprovalHistories.FindAsync(history.Id);
        Assert.NotNull(saved);
        Assert.Equal(action, saved.Action);
        Assert.Equal(role, saved.ApproverRole);
    }

    #endregion

    #region RequestComments Tests

    [Fact]
    public async Task RequestComments_CanBeCreatedWithVersioning()
    {
        await using var context = CreateInMemoryContext();
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();

        await context.Users.AddAsync(new User
        {
            Id = userId, Email = "commenter@test.com", PasswordHash = "hash",
            FullName = "Commenter", Role = UserRole.ASM, CreatedAt = DateTime.UtcNow
        });
        await context.DocumentPackages.AddAsync(new DocumentPackage
        {
            Id = packageId, SubmittedByUserId = userId,
            State = PackageState.PendingASM, CreatedAt = DateTime.UtcNow
        });

        var comment = new RequestComments
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            UserId = userId,
            UserRole = UserRole.ASM,
            CommentText = "Please fix the invoice amount",
            CommentDate = DateTime.UtcNow,
            VersionNumber = 1,
            CreatedAt = DateTime.UtcNow
        };

        await context.RequestComments.AddAsync(comment);
        await context.SaveChangesAsync();

        var saved = await context.RequestComments
            .Include(c => c.User)
            .Include(c => c.DocumentPackage)
            .FirstAsync(c => c.Id == comment.Id);

        Assert.Equal("Please fix the invoice amount", saved.CommentText);
        Assert.Equal(UserRole.ASM, saved.UserRole);
        Assert.Equal(1, saved.VersionNumber);
        Assert.NotNull(saved.User);
        Assert.NotNull(saved.DocumentPackage);
    }

    #endregion

    #region AdditionalDocument Tests

    [Fact]
    public async Task AdditionalDocument_CanBeCreated()
    {
        await using var context = CreateInMemoryContext();
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();

        await context.Users.AddAsync(new User
        {
            Id = userId, Email = "user@test.com", PasswordHash = "hash",
            FullName = "User", Role = UserRole.Agency, CreatedAt = DateTime.UtcNow
        });
        await context.DocumentPackages.AddAsync(new DocumentPackage
        {
            Id = packageId, SubmittedByUserId = userId,
            State = PackageState.Uploaded, CreatedAt = DateTime.UtcNow
        });

        var doc = new AdditionalDocument
        {
            Id = Guid.NewGuid(),
            PackageId = packageId,
            DocumentType = "Supporting Contract",
            Description = "Vendor agreement",
            FileName = "contract.pdf",
            BlobUrl = "https://blob.com/contract.pdf",
            FileSizeBytes = 5000,
            ContentType = "application/pdf",
            VersionNumber = 1,
            CreatedAt = DateTime.UtcNow
        };

        await context.AdditionalDocuments.AddAsync(doc);
        await context.SaveChangesAsync();

        var saved = await context.AdditionalDocuments.FindAsync(doc.Id);
        Assert.NotNull(saved);
        Assert.Equal("Supporting Contract", saved.DocumentType);
        Assert.Equal("Vendor agreement", saved.Description);
        Assert.Equal(1, saved.VersionNumber);
    }

    [Fact]
    public async Task AdditionalDocument_MultiplePerPackage()
    {
        await using var context = CreateInMemoryContext();
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();

        await context.Users.AddAsync(new User
        {
            Id = userId, Email = "user2@test.com", PasswordHash = "hash",
            FullName = "User", Role = UserRole.Agency, CreatedAt = DateTime.UtcNow
        });
        await context.DocumentPackages.AddAsync(new DocumentPackage
        {
            Id = packageId, SubmittedByUserId = userId,
            State = PackageState.Uploaded, CreatedAt = DateTime.UtcNow
        });

        for (int i = 0; i < 3; i++)
        {
            await context.AdditionalDocuments.AddAsync(new AdditionalDocument
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                DocumentType = $"Type{i}",
                FileName = $"doc{i}.pdf",
                BlobUrl = $"https://blob.com/doc{i}.pdf",
                FileSizeBytes = 1000,
                ContentType = "application/pdf",
                VersionNumber = 1,
                CreatedAt = DateTime.UtcNow
            });
        }

        await context.SaveChangesAsync();

        var saved = await context.DocumentPackages
            .Include(p => p.AdditionalDocuments)
            .FirstAsync(p => p.Id == packageId);

        Assert.Equal(3, saved.AdditionalDocuments.Count);
    }

    #endregion

    #region DocumentPackage Relationship Tests

    [Fact]
    public async Task DocumentPackage_HasAgencyRelationship()
    {
        await using var context = CreateInMemoryContext();
        var agencyId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();

        await context.Agencies.AddAsync(new Agency
        {
            Id = agencyId, SupplierCode = "SUP100",
            SupplierName = "Test Agency", CreatedAt = DateTime.UtcNow
        });
        await context.Users.AddAsync(new User
        {
            Id = userId, Email = "pkg@test.com", PasswordHash = "hash",
            FullName = "User", Role = UserRole.Agency,
            AgencyId = agencyId, CreatedAt = DateTime.UtcNow
        });
        await context.DocumentPackages.AddAsync(new DocumentPackage
        {
            Id = packageId, AgencyId = agencyId,
            SubmittedByUserId = userId, State = PackageState.Uploaded,
            CreatedAt = DateTime.UtcNow
        });
        await context.SaveChangesAsync();

        var saved = await context.DocumentPackages
            .Include(p => p.Agency)
            .FirstAsync(p => p.Id == packageId);

        Assert.NotNull(saved.Agency);
        Assert.Equal("SUP100", saved.Agency.SupplierCode);
    }

    [Fact]
    public async Task DocumentPackage_HasVersionNumber_DefaultsToOne()
    {
        var package = new DocumentPackage();
        Assert.Equal(1, package.VersionNumber);
    }

    [Fact]
    public async Task DocumentPackage_SupportsApprovalHistoryCollection()
    {
        await using var context = CreateInMemoryContext();
        var userId = Guid.NewGuid();
        var packageId = Guid.NewGuid();

        await context.Users.AddAsync(new User
        {
            Id = userId, Email = "hist@test.com", PasswordHash = "hash",
            FullName = "User", Role = UserRole.Agency, CreatedAt = DateTime.UtcNow
        });
        await context.DocumentPackages.AddAsync(new DocumentPackage
        {
            Id = packageId, SubmittedByUserId = userId,
            State = PackageState.Uploaded, CreatedAt = DateTime.UtcNow
        });

        // Add multiple approval history entries simulating a workflow
        var actions = new[]
        {
            (ApprovalAction.Submitted, UserRole.Agency, 1),
            (ApprovalAction.Rejected, UserRole.ASM, 1),
            (ApprovalAction.Resubmitted, UserRole.Agency, 2),
            (ApprovalAction.Approved, UserRole.ASM, 2),
        };

        foreach (var (action, role, version) in actions)
        {
            await context.RequestApprovalHistories.AddAsync(new RequestApprovalHistory
            {
                Id = Guid.NewGuid(),
                PackageId = packageId,
                ApproverId = userId,
                ApproverRole = role,
                Action = action,
                ActionDate = DateTime.UtcNow,
                VersionNumber = version,
                CreatedAt = DateTime.UtcNow
            });
        }

        await context.SaveChangesAsync();

        var saved = await context.DocumentPackages
            .Include(p => p.RequestApprovalHistory)
            .FirstAsync(p => p.Id == packageId);

        Assert.Equal(4, saved.RequestApprovalHistory.Count);
    }

    #endregion

    #region ValidationResult Polymorphic Tests

    [Theory]
    [InlineData(DocumentType.PO)]
    [InlineData(DocumentType.Invoice)]
    [InlineData(DocumentType.CostSummary)]
    [InlineData(DocumentType.ActivitySummary)]
    [InlineData(DocumentType.EnquiryDocument)]
    [InlineData(DocumentType.TeamPhoto)]
    public async Task ValidationResult_SupportsAllDocumentTypes(DocumentType docType)
    {
        await using var context = CreateInMemoryContext();
        var documentId = Guid.NewGuid();

        var result = new ValidationResult
        {
            Id = Guid.NewGuid(),
            DocumentType = docType,
            DocumentId = documentId,
            AllValidationsPassed = true,
            SapVerificationPassed = true,
            AmountConsistencyPassed = true,
            LineItemMatchingPassed = true,
            CompletenessCheckPassed = true,
            DateValidationPassed = true,
            VendorMatchingPassed = true,
            CreatedAt = DateTime.UtcNow
        };

        await context.ValidationResults.AddAsync(result);
        await context.SaveChangesAsync();

        var saved = await context.ValidationResults.FindAsync(result.Id);
        Assert.NotNull(saved);
        Assert.Equal(docType, saved.DocumentType);
        Assert.Equal(documentId, saved.DocumentId);
    }

    #endregion
}
