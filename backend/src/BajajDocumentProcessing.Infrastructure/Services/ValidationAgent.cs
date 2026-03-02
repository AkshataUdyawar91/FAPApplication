using BajajDocumentProcessing.Application.Common.Interfaces;
using BajajDocumentProcessing.Application.DTOs.Documents;
using BajajDocumentProcessing.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Polly;
using Polly.CircuitBreaker;
using System.Net.Http.Json;
using System.Text.Json;

namespace BajajDocumentProcessing.Infrastructure.Services;

/// <summary>
/// Validation Agent implementation with SAP integration
/// </summary>
public class ValidationAgent : IValidationAgent
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<ValidationAgent> _logger;
    private readonly HttpClient _sapHttpClient;
    private readonly AsyncCircuitBreakerPolicy _circuitBreakerPolicy;
    private readonly IAsyncPolicy _retryPolicy;

    public ValidationAgent(
        IApplicationDbContext context,
        ILogger<ValidationAgent> logger,
        IHttpClientFactory httpClientFactory)
    {
        _context = context;
        _logger = logger;
        _sapHttpClient = httpClientFactory.CreateClient("SAP");

        // Circuit breaker: Open after 5 failures, stay open for 60 seconds, close after 2 successes
        _circuitBreakerPolicy = Policy
            .Handle<HttpRequestException>()
            .Or<TaskCanceledException>()
            .CircuitBreakerAsync(
                exceptionsAllowedBeforeBreaking: 5,
                durationOfBreak: TimeSpan.FromSeconds(60),
                onBreak: (exception, duration) =>
                {
                    _logger.LogWarning(
                        "SAP circuit breaker opened for {Duration}s due to: {Exception}",
                        duration.TotalSeconds,
                        exception.Message);
                },
                onReset: () =>
                {
                    _logger.LogInformation("SAP circuit breaker reset");
                },
                onHalfOpen: () =>
                {
                    _logger.LogInformation("SAP circuit breaker half-open, testing connection");
                });

        // Retry policy: 3 total attempts (1 initial + 2 retries) with exponential backoff (1s, 2s)
        _retryPolicy = Policy
            .Handle<HttpRequestException>()
            .Or<TaskCanceledException>()
            .WaitAndRetryAsync(
                retryCount: 2,
                sleepDurationProvider: retryAttempt => TimeSpan.FromSeconds(Math.Pow(2, retryAttempt - 1)),
                onRetry: (exception, timeSpan, retryCount, context) =>
                {
                    _logger.LogWarning(
                        "SAP request retry {RetryCount}/2 after {Delay}s due to: {Exception}",
                        retryCount,
                        timeSpan.TotalSeconds,
                        exception.Message);
                });
    }

    public async Task<PackageValidationResult> ValidatePackageAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Starting validation for package {PackageId}", packageId);

        var result = new PackageValidationResult
        {
            PackageId = packageId,
            ValidatedAt = DateTime.UtcNow
        };

        try
        {
            // Load package with documents
            var package = await _context.DocumentPackages
                .Include(p => p.Documents)
                .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

            if (package == null)
            {
                _logger.LogError("Package {PackageId} not found", packageId);
                result.AllPassed = false;
                result.Issues.Add(new ValidationIssue
                {
                    Field = "Package",
                    Issue = "Package not found",
                    Severity = "Error"
                });
                return result;
            }

            // Extract document data
            var poDoc = package.Documents.FirstOrDefault(d => d.Type == DocumentType.PO);
            var invoiceDoc = package.Documents.FirstOrDefault(d => d.Type == DocumentType.Invoice);
            var costSummaryDoc = package.Documents.FirstOrDefault(d => d.Type == DocumentType.CostSummary);

            POData? poData = null;
            InvoiceData? invoiceData = null;
            CostSummaryData? costSummaryData = null;

            if (poDoc?.ExtractedDataJson != null)
            {
                poData = JsonSerializer.Deserialize<POData>(poDoc.ExtractedDataJson);
            }

            if (invoiceDoc?.ExtractedDataJson != null)
            {
                invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceDoc.ExtractedDataJson);
            }

            if (costSummaryDoc?.ExtractedDataJson != null)
            {
                costSummaryData = JsonSerializer.Deserialize<CostSummaryData>(costSummaryDoc.ExtractedDataJson);
            }

            // 1. SAP Verification
            if (poData != null)
            {
                result.SAPVerification = await VerifySAPPOAsync(poData.PONumber, cancellationToken);
                if (!result.SAPVerification.IsVerified && !result.SAPVerification.SAPConnectionFailed)
                {
                    result.Issues.AddRange(result.SAPVerification.Discrepancies.Select(d => new ValidationIssue
                    {
                        Field = "SAP",
                        Issue = d,
                        Severity = "Error"
                    }));
                }
            }

            // 2. Amount Consistency
            if (invoiceData != null && costSummaryData != null)
            {
                result.AmountConsistency = ValidateAmountConsistencyDetailed(
                    invoiceData.TotalAmount,
                    costSummaryData.TotalCost);

                if (!result.AmountConsistency.IsConsistent)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "Amount",
                        Issue = $"Invoice total and Cost Summary total differ by {result.AmountConsistency.PercentageDifference:F2}% (tolerance: ±2%)",
                        ExpectedValue = costSummaryData.TotalCost.ToString("F2"),
                        ActualValue = invoiceData.TotalAmount.ToString("F2"),
                        Severity = "Error"
                    });
                }
            }

            // 3. Line Item Matching
            if (poData != null && invoiceData != null)
            {
                result.LineItemMatching = ValidateLineItemsDetailed(poData.LineItems, invoiceData.LineItems);

                if (!result.LineItemMatching.AllItemsMatched)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "LineItems",
                        Issue = $"Missing {result.LineItemMatching.MissingItemCodes.Count} PO line items in Invoice: {string.Join(", ", result.LineItemMatching.MissingItemCodes)}",
                        Severity = "Error"
                    });
                }
            }

            // 4. Completeness Check
            result.Completeness = await ValidateCompletenessAsync(packageId, cancellationToken);
            if (!result.Completeness.IsComplete)
            {
                result.Issues.Add(new ValidationIssue
                {
                    Field = "Completeness",
                    Issue = $"Missing {result.Completeness.MissingItems.Count} required items: {string.Join(", ", result.Completeness.MissingItems)}",
                    Severity = "Error"
                });
            }

            // 5. Date Validation
            if (poData != null && invoiceData != null)
            {
                result.DateValidation = ValidateDates(poData.PODate, invoiceData.InvoiceDate, package.CreatedAt);
                if (!result.DateValidation.IsValid)
                {
                    result.Issues.AddRange(result.DateValidation.DateIssues.Select(issue => new ValidationIssue
                    {
                        Field = "Date",
                        Issue = issue,
                        Severity = "Error"
                    }));
                }
            }

            // 6. Vendor Matching
            if (poData != null && invoiceData != null)
            {
                result.VendorMatching = ValidateVendorMatching(
                    poData.VendorName,
                    invoiceData.VendorName,
                    result.SAPVerification?.VendorFromSAP);

                if (!result.VendorMatching.IsMatched)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "Vendor",
                        Issue = "Vendor names do not match across documents",
                        ExpectedValue = poData.VendorName,
                        ActualValue = invoiceData.VendorName,
                        Severity = "Error"
                    });
                }
            }

            // Determine overall result
            result.AllPassed = result.Issues.Count == 0 &&
                              (result.SAPVerification == null || result.SAPVerification.IsVerified || result.SAPVerification.SAPConnectionFailed) &&
                              (result.AmountConsistency == null || result.AmountConsistency.IsConsistent) &&
                              (result.LineItemMatching == null || result.LineItemMatching.AllItemsMatched) &&
                              (result.Completeness == null || result.Completeness.IsComplete) &&
                              (result.DateValidation == null || result.DateValidation.IsValid) &&
                              (result.VendorMatching == null || result.VendorMatching.IsMatched);

            _logger.LogInformation(
                "Validation completed for package {PackageId}. Result: {Result}, Issues: {IssueCount}",
                packageId,
                result.AllPassed ? "PASSED" : "FAILED",
                result.Issues.Count);

            // Persist validation result to database
            await SaveValidationResultAsync(result, cancellationToken);

            // Update package state
            if (result.AllPassed)
            {
                package.State = Domain.Enums.PackageState.Validated;
            }
            else
            {
                package.State = Domain.Enums.PackageState.ValidationFailed;
            }

            await _context.SaveChangesAsync(cancellationToken);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error validating package {PackageId}", packageId);
            result.AllPassed = false;
            result.Issues.Add(new ValidationIssue
            {
                Field = "System",
                Issue = $"Validation error: {ex.Message}",
                Severity = "Error"
            });
            return result;
        }
    }

    public async Task<SAPVerificationResult> VerifySAPPOAsync(string poNumber, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Verifying PO {PONumber} with SAP", poNumber);

        var result = new SAPVerificationResult
        {
            PONumber = poNumber
        };

        try
        {
            // Combine circuit breaker and retry policies
            var combinedPolicy = Policy.WrapAsync(_retryPolicy, _circuitBreakerPolicy);

            var sapResponse = await combinedPolicy.ExecuteAsync(async () =>
            {
                // Call SAP OData API
                var response = await _sapHttpClient.GetAsync(
                    $"/sap/opu/odata/sap/API_PURCHASEORDER_PROCESS_SRV/A_PurchaseOrder('{poNumber}')",
                    cancellationToken);

                response.EnsureSuccessStatusCode();
                return await response.Content.ReadFromJsonAsync<SAPPOResponse>(cancellationToken: cancellationToken);
            });

            if (sapResponse != null)
            {
                result.IsVerified = true;
                result.VendorFromSAP = sapResponse.Supplier;
                result.AmountFromSAP = sapResponse.TotalNetAmount;
                result.DateFromSAP = sapResponse.PurchaseOrderDate;

                _logger.LogInformation(
                    "SAP verification successful for PO {PONumber}. Vendor: {Vendor}, Amount: {Amount}",
                    poNumber,
                    sapResponse.Supplier,
                    sapResponse.TotalNetAmount);
            }
            else
            {
                result.IsVerified = false;
                result.Discrepancies.Add($"PO {poNumber} not found in SAP");
                _logger.LogWarning("PO {PONumber} not found in SAP", poNumber);
            }
        }
        catch (BrokenCircuitException ex)
        {
            _logger.LogWarning(ex, "SAP circuit breaker is open, marking validation as pending");
            result.SAPConnectionFailed = true;
            result.IsVerified = false;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "SAP connection failed for PO {PONumber}", poNumber);
            result.SAPConnectionFailed = true;
            result.IsVerified = false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error verifying PO {PONumber} with SAP", poNumber);
            result.SAPConnectionFailed = true;
            result.IsVerified = false;
        }

        return result;
    }

    public bool ValidateAmountConsistency(decimal invoiceTotal, decimal costSummaryTotal)
    {
        var result = ValidateAmountConsistencyDetailed(invoiceTotal, costSummaryTotal);
        return result.IsConsistent;
    }

    private AmountConsistencyResult ValidateAmountConsistencyDetailed(decimal invoiceTotal, decimal costSummaryTotal)
    {
        var difference = Math.Abs(invoiceTotal - costSummaryTotal);
        var percentageDifference = invoiceTotal > 0 ? (difference / invoiceTotal) * 100 : 0;

        return new AmountConsistencyResult
        {
            IsConsistent = percentageDifference <= 2.0m,
            InvoiceTotal = invoiceTotal,
            CostSummaryTotal = costSummaryTotal,
            Difference = difference,
            PercentageDifference = percentageDifference,
            TolerancePercentage = 2.0m
        };
    }

    public bool ValidateLineItems(List<POLineItem> poItems, List<InvoiceLineItem> invoiceItems)
    {
        var result = ValidateLineItemsDetailed(poItems, invoiceItems);
        return result.AllItemsMatched;
    }

    private LineItemMatchingResult ValidateLineItemsDetailed(List<POLineItem> poItems, List<InvoiceLineItem> invoiceItems)
    {
        var invoiceItemCodes = invoiceItems.Select(i => i.ItemCode).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var missingItemCodes = new List<string>();
        var matchedCount = 0;

        foreach (var poItem in poItems)
        {
            if (invoiceItemCodes.Contains(poItem.ItemCode))
            {
                matchedCount++;
            }
            else
            {
                missingItemCodes.Add(poItem.ItemCode);
            }
        }

        return new LineItemMatchingResult
        {
            AllItemsMatched = missingItemCodes.Count == 0,
            MissingItemCodes = missingItemCodes,
            POItemCount = poItems.Count,
            InvoiceItemCount = invoiceItems.Count,
            MatchedItemCount = matchedCount
        };
    }

    public async Task<CompletenessResult> ValidateCompletenessAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.Documents)
            .FirstOrDefaultAsync(p => p.Id == packageId, cancellationToken);

        if (package == null)
        {
            return new CompletenessResult
            {
                IsComplete = false,
                PresentItemCount = 0,
                MissingItems = new List<string> { "Package not found" }
            };
        }

        var requiredDocTypes = new List<DocumentType>
        {
            DocumentType.PO,
            DocumentType.Invoice,
            DocumentType.CostSummary
        };

        var presentDocTypes = package.Documents.Select(d => d.Type).Distinct().ToList();
        var missingItems = new List<string>();

        foreach (var requiredType in requiredDocTypes)
        {
            if (!presentDocTypes.Contains(requiredType))
            {
                missingItems.Add(requiredType.ToString());
            }
        }

        // Check for photos (at least 1 required)
        var photoCount = package.Documents.Count(d => d.Type == DocumentType.Photo);
        if (photoCount == 0)
        {
            missingItems.Add("Photos (at least 1 required)");
        }

        // Note: The 11 required items include:
        // 1. PO, 2. Invoice, 3. Cost Summary, 4-11. Various activity records and photos
        // For now, we're checking the core documents. Additional checks can be added based on business rules.

        var presentItemCount = requiredDocTypes.Count(t => presentDocTypes.Contains(t)) + (photoCount > 0 ? 1 : 0);

        return new CompletenessResult
        {
            IsComplete = missingItems.Count == 0,
            RequiredItemCount = 11,
            PresentItemCount = presentItemCount,
            MissingItems = missingItems
        };
    }

    private DateValidationResult ValidateDates(DateTime poDate, DateTime invoiceDate, DateTime submissionDate)
    {
        var result = new DateValidationResult
        {
            PODate = poDate,
            InvoiceDate = invoiceDate,
            SubmissionDate = submissionDate,
            IsValid = true
        };

        // Invoice date should be >= PO date
        if (invoiceDate < poDate)
        {
            result.IsValid = false;
            result.DateIssues.Add($"Invoice date ({invoiceDate:yyyy-MM-dd}) is before PO date ({poDate:yyyy-MM-dd})");
        }

        // Invoice date should be <= Submission date
        if (invoiceDate > submissionDate)
        {
            result.IsValid = false;
            result.DateIssues.Add($"Invoice date ({invoiceDate:yyyy-MM-dd}) is after submission date ({submissionDate:yyyy-MM-dd})");
        }

        return result;
    }

    private VendorMatchingResult ValidateVendorMatching(string poVendor, string invoiceVendor, string? sapVendor)
    {
        var result = new VendorMatchingResult
        {
            POVendor = poVendor,
            InvoiceVendor = invoiceVendor,
            SAPVendor = sapVendor
        };

        // Normalize vendor names for comparison (case-insensitive, trim whitespace)
        var normalizedPOVendor = poVendor?.Trim().ToLowerInvariant();
        var normalizedInvoiceVendor = invoiceVendor?.Trim().ToLowerInvariant();
        var normalizedSAPVendor = sapVendor?.Trim().ToLowerInvariant();

        // Check if PO and Invoice vendors match
        result.IsMatched = normalizedPOVendor == normalizedInvoiceVendor;

        // If SAP vendor is available, also check against it
        if (!string.IsNullOrEmpty(normalizedSAPVendor))
        {
            result.IsMatched = result.IsMatched &&
                              (normalizedPOVendor == normalizedSAPVendor || normalizedInvoiceVendor == normalizedSAPVendor);
        }

        return result;
    }

    /// <summary>
    /// Saves validation result to database
    /// </summary>
    private async Task SaveValidationResultAsync(PackageValidationResult result, CancellationToken cancellationToken)
    {
        try
        {
            // Check if validation result already exists
            var existingResult = await _context.ValidationResults
                .FirstOrDefaultAsync(v => v.PackageId == result.PackageId, cancellationToken);

            var validationEntity = existingResult ?? new Domain.Entities.ValidationResult
            {
                Id = Guid.NewGuid(),
                PackageId = result.PackageId,
                CreatedAt = DateTime.UtcNow
            };

            // Update validation flags
            validationEntity.SapVerificationPassed = result.SAPVerification?.IsVerified ?? false;
            validationEntity.AmountConsistencyPassed = result.AmountConsistency?.IsConsistent ?? false;
            validationEntity.LineItemMatchingPassed = result.LineItemMatching?.AllItemsMatched ?? false;
            validationEntity.CompletenessCheckPassed = result.Completeness?.IsComplete ?? false;
            validationEntity.DateValidationPassed = result.DateValidation?.IsValid ?? false;
            validationEntity.VendorMatchingPassed = result.VendorMatching?.IsMatched ?? false;
            validationEntity.AllValidationsPassed = result.AllPassed;

            // Store detailed validation results as JSON
            validationEntity.ValidationDetailsJson = JsonSerializer.Serialize(new
            {
                SAPVerification = result.SAPVerification,
                AmountConsistency = result.AmountConsistency,
                LineItemMatching = result.LineItemMatching,
                Completeness = result.Completeness,
                DateValidation = result.DateValidation,
                VendorMatching = result.VendorMatching,
                Issues = result.Issues
            });

            // Store failure reasons
            if (!result.AllPassed && result.Issues.Any())
            {
                validationEntity.FailureReason = string.Join("; ", result.Issues.Select(i => $"{i.Field}: {i.Issue}"));
            }

            validationEntity.UpdatedAt = DateTime.UtcNow;

            if (existingResult == null)
            {
                _context.ValidationResults.Add(validationEntity);
            }

            await _context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Validation result saved for package {PackageId}",
                result.PackageId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error saving validation result for package {PackageId}", result.PackageId);
            // Don't throw - validation result saving failure shouldn't break the validation process
        }
    }
}

/// <summary>
/// SAP OData API response model for Purchase Order
/// </summary>
internal class SAPPOResponse
{
    public string PurchaseOrder { get; set; } = string.Empty;
    public string Supplier { get; set; } = string.Empty;
    public decimal TotalNetAmount { get; set; }
    public DateTime PurchaseOrderDate { get; set; }
}
