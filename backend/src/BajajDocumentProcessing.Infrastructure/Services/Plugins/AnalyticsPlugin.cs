using BajajDocumentProcessing.Application.Common.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.SemanticKernel;
using System.ComponentModel;
using System.Text.Json;

namespace BajajDocumentProcessing.Infrastructure.Services.Plugins;

public class AnalyticsPlugin
{
    private readonly IApplicationDbContext _context;
    private readonly IVectorSearchService _vectorSearchService;
    private readonly IEmbeddingService _embeddingService;
    private Guid? _currentUserId;

    public AnalyticsPlugin(
        IApplicationDbContext context,
        IVectorSearchService vectorSearchService,
        IEmbeddingService embeddingService)
    {
        _context = context;
        _vectorSearchService = vectorSearchService;
        _embeddingService = embeddingService;
    }

    /// <summary>
    /// Sets the current user context so queries are scoped to this user's submissions.
    /// </summary>
    public void SetCurrentUser(Guid userId)
    {
        _currentUserId = userId;
    }

    [KernelFunction, Description("Search analytics data semantically using natural language queries")]
    public async Task<string> SearchAnalytics(
        [Description("The natural language query to search for")] string query,
        [Description("Optional state filter")] string? state = null,
        [Description("Optional time range filter")] string? timeRange = null)
    {
        try
        {
            // Generate embedding for the query
            var queryEmbedding = await _embeddingService.GenerateEmbeddingAsync(query);

            // Create filter
            var filter = new VectorSearchFilter
            {
                State = state,
                TimeRange = timeRange
            };

            // Search vector database
            var results = await _vectorSearchService.SearchAsync(queryEmbedding, topK: 5, filter: filter);

            if (!results.Any())
            {
                return "No relevant analytics data found for your query.";
            }

            // Format results
            var formattedResults = results.Select((r, i) => 
                $"{i + 1}. {r.Content} (Relevance: {r.Score:F2})").ToList();

            return string.Join("\n\n", formattedResults);
        }
        catch (Exception ex)
        {
            return $"Error searching analytics: {ex.Message}";
        }
    }

    [KernelFunction, Description("Get the status and details of a specific submission by its ID or FAP ID (e.g. FAP-28C9823C). Use this when a user asks about a specific submission.")]
    public async Task<string> GetSubmissionById(
        [Description("The submission ID or FAP ID (e.g. FAP-28C9823C or just 28C9823C)")] string submissionId)
    {
        try
        {
            // Strip FAP- prefix if present
            var cleanId = submissionId.Trim().ToUpper();
            if (cleanId.StartsWith("FAP-"))
                cleanId = cleanId.Substring(4);

            // Search by ID prefix match — include navigation properties
            var allPackages = _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.ConfidenceScore)
                .Where(p => !_currentUserId.HasValue || p.SubmittedByUserId == _currentUserId.Value)
                .ToList();
            var match = allPackages.FirstOrDefault(p => 
                p.Id.ToString().ToUpper().StartsWith(cleanId));

            if (match == null)
            {
                return $"No submission found matching ID '{submissionId}'.";
            }

            var result = new
            {
                FAP_ID = $"FAP-{match.Id.ToString().Substring(0, 8).ToUpper()}",
                FullId = match.Id.ToString(),
                Status = match.State.ToString(),
                SubmittedOn = match.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                LastUpdated = match.UpdatedAt?.ToString("yyyy-MM-dd HH:mm") ?? "N/A",
                DocumentCount = (match.PO != null ? 1 : 0) + match.Invoices.Count,
                Confidence = match.ConfidenceScore != null 
                    ? $"{(match.ConfidenceScore.OverallConfidence * 100):F0}%" 
                    : "N/A"
            };

            return JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception ex)
        {
            return $"Error retrieving submission: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get key performance indicators (KPIs) for a specific time period")]
    public async Task<string> GetKPIs(
        [Description("Start date in format YYYY-MM-DD")] string? startDate = null,
        [Description("End date in format YYYY-MM-DD")] string? endDate = null)
    {
        try
        {
            var start = string.IsNullOrEmpty(startDate) ? DateTime.UtcNow.AddMonths(-1) : DateTime.Parse(startDate);
            var end = string.IsNullOrEmpty(endDate) ? DateTime.UtcNow : DateTime.Parse(endDate);

            var packages = _context.DocumentPackages
                .Include(p => p.ConfidenceScore)
                .Where(p => p.CreatedAt >= start && p.CreatedAt <= end)
                .Where(p => !_currentUserId.HasValue || p.SubmittedByUserId == _currentUserId.Value)
                .ToList();

            var totalSubmissions = packages.Count;
            var approvedCount = packages.Count(p => p.State == Domain.Enums.PackageState.Approved);
            var rejectedCount = packages.Count(p => 
                p.State == Domain.Enums.PackageState.CHRejected || 
                p.State == Domain.Enums.PackageState.RARejected);
            var approvalRate = totalSubmissions > 0 ? (double)approvedCount / totalSubmissions * 100 : 0;

            var packagesWithUpdates = packages.Where(p => p.UpdatedAt.HasValue);
            var avgProcessingTime = packagesWithUpdates.Any()
                ? packagesWithUpdates.Average(p => (p.UpdatedAt!.Value - p.CreatedAt).TotalHours)
                : 0.0;

            var packagesWithScores = packages.Where(p => p.ConfidenceScore != null);
            var avgConfidence = packagesWithScores.Any()
                ? packagesWithScores.Average(p => p.ConfidenceScore!.OverallConfidence)
                : 0.0;

            var kpis = new
            {
                Period = $"{start:yyyy-MM-dd} to {end:yyyy-MM-dd}",
                TotalSubmissions = totalSubmissions,
                ApprovedCount = approvedCount,
                RejectedCount = rejectedCount,
                ApprovalRate = $"{approvalRate:F1}%",
                AvgProcessingTimeHours = $"{avgProcessingTime:F1}",
                AvgConfidenceScore = $"{avgConfidence:F1}"
            };

            return JsonSerializer.Serialize(kpis, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception ex)
        {
            return $"Error retrieving KPIs: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get state-level ROI and performance data")]
    public async Task<string> GetStateROI(
        [Description("Optional state name to filter by")] string? state = null)
    {
        try
        {
            // For now, return a placeholder since we don't have state field in DocumentPackage
            // In production, this would query actual state-level data
            var message = string.IsNullOrEmpty(state)
                ? "State-level ROI data is not yet available. The system needs to be enhanced with state/location tracking."
                : $"ROI data for {state} is not yet available. The system needs to be enhanced with state/location tracking.";

            return message;
        }
        catch (Exception ex)
        {
            return $"Error retrieving state ROI: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get campaign performance breakdown")]
    public async Task<string> GetCampaignData(
        [Description("Optional campaign name to filter by")] string? campaignName = null)
    {
        try
        {
            // For now, return a placeholder since we don't have campaign field in DocumentPackage
            // In production, this would query actual campaign data
            var message = string.IsNullOrEmpty(campaignName)
                ? "Campaign performance data is not yet available. The system needs to be enhanced with campaign tracking."
                : $"Performance data for campaign '{campaignName}' is not yet available. The system needs to be enhanced with campaign tracking.";

            return message;
        }
        catch (Exception ex)
        {
            return $"Error retrieving campaign data: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get list of pending submissions awaiting approval")]
    public async Task<string> GetPendingSubmissions(
        [Description("Optional filter: 'asm' for ASM pending, 'hq' for HQ pending, or null for all pending")] string? approvalLevel = null)
    {
        try
        {
            var query = _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.ConfidenceScore)
                .AsQueryable();

            // Scope to current user's submissions
            if (_currentUserId.HasValue)
            {
                query = query.Where(p => p.SubmittedByUserId == _currentUserId.Value);
            }

            if (approvalLevel?.ToLower() == "asm")
            {
                query = query.Where(p => p.State == Domain.Enums.PackageState.PendingCH);
            }
            else if (approvalLevel?.ToLower() == "hq")
            {
                query = query.Where(p => p.State == Domain.Enums.PackageState.PendingRA);
            }
            else
            {
                query = query.Where(p => 
                    p.State == Domain.Enums.PackageState.PendingCH || 
                    p.State == Domain.Enums.PackageState.PendingRA);
            }

            var submissions = query
                .OrderByDescending(p => p.CreatedAt)
                .Take(20)
                .ToList()
                .Select(p => new
                {
                    Id = p.Id,
                    State = p.State.ToString(),
                    CreatedAt = p.CreatedAt,
                    OverallConfidence = p.ConfidenceScore?.OverallConfidence ?? 0.0,
                    DocumentCount = (p.PO != null ? 1 : 0) + p.Invoices.Count
                })
                .ToList();

            if (!submissions.Any())
            {
                return approvalLevel != null 
                    ? $"No pending submissions found for {approvalLevel.ToUpper()} approval."
                    : "No pending submissions found.";
            }

            var result = new
            {
                TotalPending = submissions.Count,
                Submissions = submissions.Select(s => new
                {
                    FAP_ID = $"FAP-{s.Id.ToString().Substring(0, 8).ToUpper()}",
                    Status = s.State,
                    SubmittedOn = s.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                    Confidence = $"{(s.OverallConfidence * 100):F0}%",
                    Documents = s.DocumentCount
                })
            };

            return JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception ex)
        {
            return $"Error retrieving pending submissions: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get list of approved submissions")]
    public async Task<string> GetApprovedSubmissions(
        [Description("Number of recent approved submissions to retrieve (default 20)")] int count = 20)
    {
        try
        {
            var submissions = _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.ConfidenceScore)
                .Where(p => p.State == Domain.Enums.PackageState.Approved)
                .Where(p => !_currentUserId.HasValue || p.SubmittedByUserId == _currentUserId.Value)
                .OrderByDescending(p => p.UpdatedAt ?? p.CreatedAt)
                .Take(count)
                .ToList()
                .Select(p => new
                {
                    Id = p.Id,
                    CreatedAt = p.CreatedAt,
                    ApprovedAt = p.UpdatedAt,
                    OverallConfidence = p.ConfidenceScore?.OverallConfidence ?? 0.0,
                    DocumentCount = (p.PO != null ? 1 : 0) + p.Invoices.Count
                })
                .ToList();

            if (!submissions.Any())
            {
                return "No approved submissions found.";
            }

            var result = new
            {
                TotalApproved = submissions.Count,
                Submissions = submissions.Select(s => new
                {
                    FAP_ID = $"FAP-{s.Id.ToString().Substring(0, 8).ToUpper()}",
                    SubmittedOn = s.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                    ApprovedOn = s.ApprovedAt?.ToString("yyyy-MM-dd HH:mm") ?? "N/A",
                    Confidence = $"{(s.OverallConfidence * 100):F0}%",
                    Documents = s.DocumentCount
                })
            };

            return JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception ex)
        {
            return $"Error retrieving approved submissions: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get list of rejected submissions")]
    public async Task<string> GetRejectedSubmissions(
        [Description("Number of recent rejected submissions to retrieve (default 20)")] int count = 20)
    {
        try
        {
            var submissions = _context.DocumentPackages
                .Where(p => p.State == Domain.Enums.PackageState.CHRejected || 
                           p.State == Domain.Enums.PackageState.RARejected)
                .Where(p => !_currentUserId.HasValue || p.SubmittedByUserId == _currentUserId.Value)
                .OrderByDescending(p => p.UpdatedAt ?? p.CreatedAt)
                .Take(count)
                .ToList()
                .Select(p => new
                {
                    Id = p.Id,
                    State = p.State.ToString(),
                    CreatedAt = p.CreatedAt,
                    RejectedAt = p.UpdatedAt,
                    DocumentCount = 0
                })
                .ToList();

            if (!submissions.Any())
            {
                return "No rejected submissions found.";
            }

            var result = new
            {
                TotalRejected = submissions.Count,
                Submissions = submissions.Select(s => new
                {
                    FAP_ID = $"FAP-{s.Id.ToString().Substring(0, 8).ToUpper()}",
                    Status = s.State,
                    SubmittedOn = s.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                    RejectedOn = s.RejectedAt?.ToString("yyyy-MM-dd HH:mm") ?? "N/A",
                    Documents = s.DocumentCount
                })
            };

            return JsonSerializer.Serialize(result, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception ex)
        {
            return $"Error retrieving rejected submissions: {ex.Message}";
        }

        await Task.CompletedTask;
    }

    [KernelFunction, Description("Get summary of all submissions by status")]
    public async Task<string> GetSubmissionsSummary()
    {
        try
        {
            var allPackages = _context.DocumentPackages
                .Include(p => p.ConfidenceScore)
                .Where(p => !_currentUserId.HasValue || p.SubmittedByUserId == _currentUserId.Value)
                .ToList();

            var summary = new
            {
                Total = allPackages.Count,
                PendingCH = allPackages.Count(p => p.State == Domain.Enums.PackageState.PendingCH),
                PendingRA = allPackages.Count(p => p.State == Domain.Enums.PackageState.PendingRA),
                Approved = allPackages.Count(p => p.State == Domain.Enums.PackageState.Approved),
                CHRejected = allPackages.Count(p => p.State == Domain.Enums.PackageState.CHRejected),
                RARejected = allPackages.Count(p => p.State == Domain.Enums.PackageState.RARejected),
                Processing = allPackages.Count(p => 
                    p.State == Domain.Enums.PackageState.Uploaded ||
                    p.State == Domain.Enums.PackageState.Extracting ||
                    p.State == Domain.Enums.PackageState.Validating),
                AvgConfidence = allPackages.Where(p => p.ConfidenceScore != null).Any()
                    ? allPackages.Where(p => p.ConfidenceScore != null).Average(p => p.ConfidenceScore!.OverallConfidence) * 100
                    : 0.0
            };

            return JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true });
        }
        catch (Exception ex)
        {
            return $"Error retrieving submissions summary: {ex.Message}";
        }

        await Task.CompletedTask;
    }
}
