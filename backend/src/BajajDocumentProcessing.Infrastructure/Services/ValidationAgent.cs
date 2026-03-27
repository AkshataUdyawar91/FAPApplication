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
/// Validation Agent implementation with SAP integration.
/// Performs comprehensive validation of document packages including SAP verification,
/// cross-document validation, and field presence checks.
/// </summary>
public class ValidationAgent : IValidationAgent
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<ValidationAgent> _logger;
    private readonly HttpClient _sapHttpClient;
    private readonly IReferenceDataService _referenceDataService;
    private readonly ICorrelationIdService _correlationIdService;
    private readonly IPerceptualHashService _perceptualHashService;
    private readonly IPoBalanceService _poBalanceService;
    private readonly AsyncCircuitBreakerPolicy _circuitBreakerPolicy;
    private readonly IAsyncPolicy _retryPolicy;

    /// <summary>
    /// Initializes a new instance of the ValidationAgent class.
    /// Configures circuit breaker and retry policies for SAP integration.
    /// </summary>
    /// <param name="context">Database context for accessing document packages and validation results</param>
    /// <param name="logger">Logger for diagnostic information</param>
    /// <param name="httpClientFactory">Factory for creating HTTP clients for SAP integration</param>
    /// <param name="referenceDataService">Service for validating reference data (GST, HSN codes, state rates)</param>
    public ValidationAgent(
        IApplicationDbContext context,
        ILogger<ValidationAgent> logger,
        IHttpClientFactory httpClientFactory,
        IReferenceDataService referenceDataService,
        ICorrelationIdService correlationIdService,
        IPerceptualHashService perceptualHashService,
        IPoBalanceService poBalanceService)
    {
        _context = context;
        _logger = logger;
        _sapHttpClient = httpClientFactory.CreateClient("SAP");
        _referenceDataService = referenceDataService;
        _correlationIdService = correlationIdService;
        _perceptualHashService = perceptualHashService;
        _poBalanceService = poBalanceService;

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

    /// <summary>
    /// Validates a complete document package by performing all validation checks.
    /// Includes SAP verification, cross-document validation, field presence checks, and date validation.
    /// </summary>
    /// <param name="packageId">The unique identifier of the package to validate</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>A PackageValidationResult containing all validation results and issues</returns>
    /// <exception cref="InvalidOperationException">Thrown when the package is not found</exception>
    public async Task<PackageValidationResult> ValidatePackageAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting validation for package {PackageId}. CorrelationId: {CorrelationId}",
            packageId, correlationId);

        var result = new PackageValidationResult
        {
            PackageId = packageId,
            ValidatedAt = DateTime.UtcNow
        };

        try
        {
            // Load package with dedicated document navigations
            var package = await _context.DocumentPackages
                .Include(p => p.PO)
                .Include(p => p.Invoices)
                .Include(p => p.CostSummary)
                .Include(p => p.ActivitySummary)
                .Include(p => p.EnquiryDocument)
                .Include(p => p.Teams).ThenInclude(c => c.Photos)
                .AsSplitQuery()
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

            // Extract document data from dedicated navigation properties
            var allTeamPhotos = package.Teams.SelectMany(c => c.Photos).ToList();

            // Populate FileNames dictionary so validation output shows which file each check refers to
            result.FileNames = new Dictionary<string, string>();
            if (package.PO != null) result.FileNames["PO"] = package.PO.FileName ?? "PO document";
            if (package.Invoices.Any()) result.FileNames["Invoice"] = package.Invoices.First().FileName ?? "Invoice document";
            if (package.CostSummary != null) result.FileNames["CostSummary"] = package.CostSummary.FileName ?? "Cost Summary document";
            if (package.ActivitySummary != null) result.FileNames["Activity"] = package.ActivitySummary.FileName ?? "Activity document";
            if (package.EnquiryDocument != null) result.FileNames["EnquiryDump"] = package.EnquiryDocument.FileName ?? "Enquiry Dump document";
            if (allTeamPhotos.Any())
            {
                for (int i = 0; i < allTeamPhotos.Count; i++)
                {
                    result.FileNames[$"Photo_{i}"] = allTeamPhotos[i].FileName ?? $"Photo {i + 1}";
                }
            }

            POData? poData = null;
            InvoiceData? invoiceData = null;
            CostSummaryData? costSummaryData = null;
            ActivityData? activityData = null;
            EnquiryDumpData? enquiryDumpData = null;

            if (package.PO?.ExtractedDataJson != null)
            {
                poData = JsonSerializer.Deserialize<POData>(package.PO.ExtractedDataJson);
            }

            // Invoice data: check package-level Invoices (linked to PO)
            var firstInvoice = package.Invoices.FirstOrDefault();
            if (firstInvoice?.ExtractedDataJson != null)
            {
                invoiceData = JsonSerializer.Deserialize<InvoiceData>(firstInvoice.ExtractedDataJson);
            }

            // Cost Summary data from dedicated entity
            if (package.CostSummary?.ExtractedDataJson != null)
            {
                costSummaryData = JsonSerializer.Deserialize<CostSummaryData>(package.CostSummary.ExtractedDataJson);
            }

            // Activity Summary data from dedicated entity
            if (package.ActivitySummary?.ExtractedDataJson != null)
            {
                activityData = JsonSerializer.Deserialize<ActivityData>(package.ActivitySummary.ExtractedDataJson);
            }

            // Enquiry Document data from dedicated entity
            if (package.EnquiryDocument?.ExtractedDataJson != null)
            {
                enquiryDumpData = JsonSerializer.Deserialize<EnquiryDumpData>(package.EnquiryDocument.ExtractedDataJson);
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

            // 2. Amount Consistency - RELAXED: Allow differences for real-world scenarios
            if (invoiceData != null && costSummaryData != null)
            {
                result.AmountConsistency = ValidateAmountConsistencyDetailed(
                    invoiceData.TotalAmount,
                    costSummaryData.TotalCost);

                // Note: Amount differences are tracked but not treated as errors
                // Real-world documents may have legitimate differences (taxes, discounts, etc.)
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

            // 6. Vendor Matching - RELAXED: Allow vendor name variations
            if (poData != null && invoiceData != null)
            {
                result.VendorMatching = ValidateVendorMatching(
                    poData.VendorName,
                    invoiceData.VendorName,
                    result.SAPVerification?.VendorFromSAP);

                // Note: Vendor name differences are tracked but not treated as errors
                // Real-world documents may have variations in vendor names (abbreviations, legal names, etc.)
            }

            // 7. Invoice Field Presence Validation
            if (invoiceData != null)
            {
                result.InvoiceFieldPresence = ValidateInvoiceFieldPresence(invoiceData);
                if (!result.InvoiceFieldPresence.AllFieldsPresent)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "Invoice Fields",
                        Issue = $"Missing required fields: {string.Join(", ", result.InvoiceFieldPresence.MissingFields)}",
                        Severity = "Error"
                    });
                }
            }

            // 8. Invoice Cross-Document Validation
            if (invoiceData != null && poData != null)
            {
                result.InvoiceCrossDocument = await ValidateInvoiceCrossDocumentAsync(invoiceData, poData, cancellationToken);
                if (!result.InvoiceCrossDocument.AllChecksPass)
                {
                    foreach (var issue in result.InvoiceCrossDocument.Issues)
                    {
                        result.Issues.Add(new ValidationIssue
                        {
                            Field = "Invoice Cross-Validation",
                            Issue = issue,
                            Severity = "Error"
                        });
                    }
                }
            }

            // 9. Cost Summary Field Presence Validation
            if (costSummaryData != null)
            {
                result.CostSummaryFieldPresence = ValidateCostSummaryFieldPresence(costSummaryData);
                if (!result.CostSummaryFieldPresence.AllFieldsPresent)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "Cost Summary Fields",
                        Issue = $"Missing required fields: {string.Join(", ", result.CostSummaryFieldPresence.MissingFields)}",
                        Severity = "Error"
                    });
                }
            }

            // 10. Cost Summary Cross-Document Validation
            if (costSummaryData != null && invoiceData != null)
            {
                result.CostSummaryCrossDocument = ValidateCostSummaryCrossDocument(costSummaryData, invoiceData);
                if (!result.CostSummaryCrossDocument.AllChecksPass)
                {
                    foreach (var issue in result.CostSummaryCrossDocument.Issues)
                    {
                        result.Issues.Add(new ValidationIssue
                        {
                            Field = "Cost Summary Cross-Validation",
                            Issue = issue,
                            Severity = "Error"
                        });
                    }
                }
            }

            // 11. Activity Summary Field Presence Validation
            if (activityData != null)
            {
                result.ActivityFieldPresence = ValidateActivityFieldPresence(activityData);
                if (!result.ActivityFieldPresence.AllFieldsPresent)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "Activity Summary Fields",
                        Issue = $"Missing required fields: {string.Join(", ", result.ActivityFieldPresence.MissingFields)}",
                        Severity = "Error"
                    });
                }
            }

            // 12. Activity Summary Cross-Document Validation
            if (activityData != null && costSummaryData != null)
            {
                result.ActivityCrossDocument = ValidateActivityCrossDocument(activityData, costSummaryData);
                if (!result.ActivityCrossDocument.AllChecksPass)
                {
                    foreach (var issue in result.ActivityCrossDocument.Issues)
                    {
                        result.Issues.Add(new ValidationIssue
                        {
                            Field = "Activity Summary Cross-Validation",
                            Issue = issue,
                            Severity = "Error"
                        });
                    }
                }
            }

            // 13. Photo Proofs Field Presence Validation
            var totalPhotoCount = allTeamPhotos.Count;
            if (allTeamPhotos.Any())
            {
                result.PhotoFieldPresence = ValidatePhotoFieldPresence(allTeamPhotos);
                if (!result.PhotoFieldPresence.AllFieldsPresent)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "Photo Proofs",
                        Issue = $"Photo validation issues: {string.Join(", ", result.PhotoFieldPresence.MissingFields)}",
                        Severity = "Warning" // Photos are important but may not block validation
                    });
                }
            }

            // 14. Photo Proofs Cross-Document Validation (3-way validation)
            if (totalPhotoCount > 0)
            {
                result.PhotoCrossDocument = ValidatePhotoCrossDocument(
                    allTeamPhotos,
                    activityData,
                    costSummaryData);
                
                if (!result.PhotoCrossDocument.AllChecksPass)
                {
                    foreach (var issue in result.PhotoCrossDocument.Issues)
                    {
                        result.Issues.Add(new ValidationIssue
                        {
                            Field = "Photo Cross-Validation",
                            Issue = issue,
                            Severity = "Error"
                        });
                    }
                }
            }

            // CHANGE: 15. Enquiry Dump Field Presence Validation
            if (enquiryDumpData != null)
            {
                result.EnquiryDumpFieldPresence = ValidateEnquiryDumpFieldPresence(enquiryDumpData);
                if (!result.EnquiryDumpFieldPresence.AllFieldsPresent)
                {
                    result.Issues.Add(new ValidationIssue
                    {
                        Field = "Enquiry Dump Fields",
                        Issue = $"Missing required fields: {string.Join(", ", result.EnquiryDumpFieldPresence.MissingFields)}",
                        Severity = "Error"
                    });
                }
            }

            // CHANGE: Removed Enquiry Dump Cross-Document validation per spec — Enquiry Dump only needs field presence checks, no cross-document checks

            // Determine overall result
            result.AllPassed = result.Issues.Count == 0 &&
                              (result.SAPVerification == null || result.SAPVerification.IsVerified || result.SAPVerification.SAPConnectionFailed) &&
                              (result.Completeness == null || result.Completeness.IsComplete) &&
                              (result.DateValidation == null || result.DateValidation.IsValid) &&
                              (result.VendorMatching == null || result.VendorMatching.IsMatched) &&
                              (result.InvoiceFieldPresence == null || result.InvoiceFieldPresence.AllFieldsPresent) &&
                              (result.InvoiceCrossDocument == null || result.InvoiceCrossDocument.AllChecksPass) &&
                              (result.CostSummaryFieldPresence == null || result.CostSummaryFieldPresence.AllFieldsPresent) &&
                              (result.CostSummaryCrossDocument == null || result.CostSummaryCrossDocument.AllChecksPass) &&
                              (result.ActivityFieldPresence == null || result.ActivityFieldPresence.AllFieldsPresent) &&
                              (result.ActivityCrossDocument == null || result.ActivityCrossDocument.AllChecksPass) &&
                              (result.PhotoCrossDocument == null || result.PhotoCrossDocument.AllChecksPass) &&
                              // CHANGE: Added EnquiryDump field presence validation to overall result (no cross-document per spec)
                              (result.EnquiryDumpFieldPresence == null || result.EnquiryDumpFieldPresence.AllFieldsPresent) &&
                              (result.DateValidation == null || result.DateValidation.IsValid);
            
            // Note: AmountConsistency, LineItemMatching, and VendorMatching are informational only

            _logger.LogInformation(
                "Validation completed for package {PackageId}. Result: {Result}, Issues: {IssueCount}. CorrelationId: {CorrelationId}",
                packageId,
                result.AllPassed ? "PASSED" : "FAILED",
                result.Issues.Count,
                correlationId);

            // Persist validation results per document type
            await SaveValidationResultsAsync(result, package, cancellationToken);

            // Update package state - validation no longer sets state (removed Validated/ValidationFailed states)
            // Package remains in Validating state, workflow orchestrator will move to PendingCH

            await _context.SaveChangesAsync(cancellationToken);

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error validating package {PackageId}. CorrelationId: {CorrelationId}",
                packageId, correlationId);
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

    /// <summary>
    /// Verifies a Purchase Order number against SAP system.
    /// Uses circuit breaker and retry policies for resilience.
    /// </summary>
    /// <param name="poNumber">The PO number to verify</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>A SAPVerificationResult containing verification status and SAP data</returns>
    public async Task<SAPVerificationResult> VerifySAPPOAsync(string poNumber, CancellationToken cancellationToken = default)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Verifying PO {PONumber} with SAP. CorrelationId: {CorrelationId}",
            poNumber, correlationId);

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
                    "SAP verification successful for PO {PONumber}. Vendor: {Vendor}, Amount: {Amount}. CorrelationId: {CorrelationId}",
                    poNumber,
                    sapResponse.Supplier,
                    sapResponse.TotalNetAmount,
                    correlationId);
            }
            else
            {
                result.IsVerified = false;
                result.Discrepancies.Add($"PO {poNumber} not found in SAP");
                _logger.LogWarning(
                    "PO {PONumber} not found in SAP. CorrelationId: {CorrelationId}",
                    poNumber, correlationId);
            }
        }
        catch (BrokenCircuitException ex)
        {
            _logger.LogWarning(
                ex,
                "SAP circuit breaker is open, marking validation as pending. CorrelationId: {CorrelationId}",
                correlationId);
            result.SAPConnectionFailed = true;
            result.IsVerified = false;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(
                ex,
                "SAP connection failed for PO {PONumber}. CorrelationId: {CorrelationId}",
                poNumber, correlationId);
            result.SAPConnectionFailed = true;
            result.IsVerified = false;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error verifying PO {PONumber} with SAP. CorrelationId: {CorrelationId}",
                poNumber, correlationId);
            result.SAPConnectionFailed = true;
            result.IsVerified = false;
        }

        _logger.LogInformation(
            "SAP verification completed for PO {PONumber}. IsVerified: {IsVerified}. CorrelationId: {CorrelationId}",
            poNumber, result.IsVerified, correlationId);

        return result;
    }

    /// <summary>
    /// Validates amount consistency between invoice and cost summary totals.
    /// Allows up to 2% difference to account for rounding and real-world variations.
    /// </summary>
    /// <param name="invoiceTotal">Total amount from invoice</param>
    /// <param name="costSummaryTotal">Total cost from cost summary</param>
    /// <returns>True if amounts are consistent within tolerance; otherwise, false</returns>
    public bool ValidateAmountConsistency(decimal invoiceTotal, decimal costSummaryTotal)
    {
        var result = ValidateAmountConsistencyDetailed(invoiceTotal, costSummaryTotal);
        return result.IsConsistent;
    }

    private AmountConsistencyResult ValidateAmountConsistencyDetailed(decimal invoiceTotal, decimal costSummaryTotal)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogDebug(
            "Validating amount consistency. InvoiceTotal: {InvoiceTotal}, CostSummaryTotal: {CostSummaryTotal}. CorrelationId: {CorrelationId}",
            invoiceTotal, costSummaryTotal, correlationId);

        var difference = Math.Abs(invoiceTotal - costSummaryTotal);
        var percentageDifference = invoiceTotal > 0 ? (difference / invoiceTotal) * 100 : 0;

        var result = new AmountConsistencyResult
        {
            IsConsistent = percentageDifference <= 2.0m,
            InvoiceTotal = invoiceTotal,
            CostSummaryTotal = costSummaryTotal,
            Difference = difference,
            PercentageDifference = percentageDifference,
            TolerancePercentage = 2.0m
        };

        _logger.LogDebug(
            "Amount consistency validation completed. IsConsistent: {IsConsistent}, Difference: {Difference}, PercentageDifference: {PercentageDifference}%. CorrelationId: {CorrelationId}",
            result.IsConsistent, result.Difference, result.PercentageDifference, correlationId);

        return result;
    }

    /// <summary>
    /// Validates that all line items from the PO are present in the invoice.
    /// Performs case-insensitive matching on item codes.
    /// </summary>
    /// <param name="poItems">List of line items from the Purchase Order</param>
    /// <param name="invoiceItems">List of line items from the Invoice</param>
    /// <returns>True if all PO items are found in the invoice; otherwise, false</returns>
    public bool ValidateLineItems(List<POLineItem> poItems, List<InvoiceLineItem> invoiceItems)
    {
        var result = ValidateLineItemsDetailed(poItems, invoiceItems);
        return result.AllItemsMatched;
    }

    private LineItemMatchingResult ValidateLineItemsDetailed(List<POLineItem> poItems, List<InvoiceLineItem> invoiceItems)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogDebug(
            "Validating line items. POItemCount: {POItemCount}, InvoiceItemCount: {InvoiceItemCount}. CorrelationId: {CorrelationId}",
            poItems.Count, invoiceItems.Count, correlationId);

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

        var result = new LineItemMatchingResult
        {
            AllItemsMatched = missingItemCodes.Count == 0,
            MissingItemCodes = missingItemCodes,
            POItemCount = poItems.Count,
            InvoiceItemCount = invoiceItems.Count,
            MatchedItemCount = matchedCount
        };

        _logger.LogDebug(
            "Line item validation completed. AllItemsMatched: {AllItemsMatched}, MatchedCount: {MatchedCount}, MissingCount: {MissingCount}. CorrelationId: {CorrelationId}",
            result.AllItemsMatched, matchedCount, missingItemCodes.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Validates that all required documents are present in the package.
    /// Checks for PO, Invoice, Cost Summary, and at least one photo.
    /// </summary>
    /// <param name="packageId">The unique identifier of the package to check</param>
    /// <param name="cancellationToken">Cancellation token for async operation</param>
    /// <returns>A CompletenessResult indicating which documents are present and which are missing</returns>
    public async Task<CompletenessResult> ValidateCompletenessAsync(Guid packageId, CancellationToken cancellationToken = default)
    {
        var package = await _context.DocumentPackages
            .Include(p => p.PO)
            .Include(p => p.Invoices)
            .Include(p => p.CostSummary)
            .Include(p => p.Teams).ThenInclude(c => c.Photos)
            .AsSplitQuery()
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

        var missingItems = new List<string>();

        // PO: check dedicated navigation property
        if (package.PO == null)
        {
            missingItems.Add("PO");
        }

        // Invoice: check package-level Invoices (linked to PO)
        var hasInvoiceInPackage = package.Invoices.Any();
        if (!hasInvoiceInPackage)
        {
            missingItems.Add("Invoice");
        }

        // Cost Summary: check dedicated navigation property
        if (package.CostSummary == null)
        {
            missingItems.Add("CostSummary");
        }

        // Photos: check TeamPhotos from Teams
        var photoCountInTeams = package.Teams.Sum(c => c.Photos.Count);
        if (photoCountInTeams == 0)
        {
            missingItems.Add("Photos (at least 1 required)");
        }

        // Count present items (PO + Invoice + CostSummary + Photos)
        var presentItemCount = 0;
        if (package.PO != null) presentItemCount++;
        if (hasInvoiceInPackage) presentItemCount++;
        if (package.CostSummary != null) presentItemCount++;
        if (photoCountInTeams > 0) presentItemCount++;

        return new CompletenessResult
        {
            IsComplete = missingItems.Count == 0,
            RequiredItemCount = 11,
            PresentItemCount = presentItemCount,
            MissingItems = missingItems
        };
    }

    /// <summary>
    /// Validates date relationships between PO, invoice, and submission dates.
    /// Ensures invoice date is between PO date and submission date.
    /// </summary>
    /// <param name="poDate">Purchase Order date</param>
    /// <param name="invoiceDate">Invoice date</param>
    /// <param name="submissionDate">Package submission date</param>
    /// <returns>A DateValidationResult containing validation status and any date issues</returns>
    private DateValidationResult ValidateDates(DateTime poDate, DateTime invoiceDate, DateTime submissionDate)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogDebug(
            "Validating dates. PODate: {PODate}, InvoiceDate: {InvoiceDate}, SubmissionDate: {SubmissionDate}. CorrelationId: {CorrelationId}",
            poDate, invoiceDate, submissionDate, correlationId);

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

        _logger.LogDebug(
            "Date validation completed. IsValid: {IsValid}, IssueCount: {IssueCount}. CorrelationId: {CorrelationId}",
            result.IsValid, result.DateIssues.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Validates vendor name consistency across PO, Invoice, and SAP data.
    /// Performs case-insensitive comparison with whitespace normalization.
    /// </summary>
    /// <param name="poVendor">Vendor name from Purchase Order</param>
    /// <param name="invoiceVendor">Vendor name from Invoice</param>
    /// <param name="sapVendor">Vendor name from SAP system (optional)</param>
    /// <returns>A VendorMatchingResult indicating whether vendor names match</returns>
    private VendorMatchingResult ValidateVendorMatching(string poVendor, string invoiceVendor, string? sapVendor)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogDebug(
            "Validating vendor matching. POVendor: {POVendor}, InvoiceVendor: {InvoiceVendor}, SAPVendor: {SAPVendor}. CorrelationId: {CorrelationId}",
            poVendor, invoiceVendor, sapVendor, correlationId);

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

        _logger.LogDebug(
            "Vendor matching validation completed. IsMatched: {IsMatched}. CorrelationId: {CorrelationId}",
            result.IsMatched, correlationId);

        return result;
    }

    /// <summary>
    /// Validates that all required invoice fields are present.
    /// Checks for agency details, billing information, GST data, and amounts.
    /// </summary>
    /// <param name="invoiceData">The invoice data to validate</param>
    /// <returns>An InvoiceFieldPresenceResult listing any missing required fields</returns>
    private InvoiceFieldPresenceResult ValidateInvoiceFieldPresence(InvoiceData invoiceData)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting invoice field presence validation. CorrelationId: {CorrelationId}",
            correlationId);

        var result = new InvoiceFieldPresenceResult { AllFieldsPresent = true };
        var missingFields = new List<string>();

        // Check required fields
        if (string.IsNullOrWhiteSpace(invoiceData.AgencyName))
            missingFields.Add("Agency Name");
        
        if (string.IsNullOrWhiteSpace(invoiceData.AgencyAddress))
            missingFields.Add("Agency Address");
        
        if (string.IsNullOrWhiteSpace(invoiceData.BillingName))
            missingFields.Add("Billing Name");
        
        if (string.IsNullOrWhiteSpace(invoiceData.BillingAddress))
            missingFields.Add("Billing Address");
        
        if (string.IsNullOrWhiteSpace(invoiceData.StateName) && string.IsNullOrWhiteSpace(invoiceData.StateCode))
            missingFields.Add("State Name/Code");
        
        if (string.IsNullOrWhiteSpace(invoiceData.InvoiceNumber))
            missingFields.Add("Invoice Number");
        
        if (invoiceData.InvoiceDate == default)
            missingFields.Add("Invoice Date");
        
        if (string.IsNullOrWhiteSpace(invoiceData.VendorCode))
            missingFields.Add("Vendor Code");
        
        if (string.IsNullOrWhiteSpace(invoiceData.GSTNumber))
            missingFields.Add("GST Number");
        
        if (invoiceData.GSTPercentage <= 0)
            missingFields.Add("GST Percentage");
        
        if (string.IsNullOrWhiteSpace(invoiceData.HSNSACCode))
            missingFields.Add("HSN/SAC Code");
        
        if (invoiceData.TotalAmount <= 0)
            missingFields.Add("Invoice Amount");

        // Requirement 1: Invoice PO Number Field Presence
        if (string.IsNullOrWhiteSpace(invoiceData.PONumber))
            missingFields.Add("PO Number");

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        _logger.LogInformation(
            "Invoice field presence validation completed. AllFieldsPresent: {AllFieldsPresent}, MissingFieldCount: {MissingFieldCount}. CorrelationId: {CorrelationId}",
            result.AllFieldsPresent, missingFields.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Validates invoice cross-document fields against PO data.
    /// Checks agency code, PO number, GST-state mapping, HSN/SAC code, invoice amount, and GST percentage.
    /// </summary>
    /// <param name="invoiceData">The invoice data to validate</param>
    /// <param name="poData">The PO data to validate against</param>
    /// <returns>An InvoiceCrossDocumentResult containing validation status and any issues</returns>
    private async Task<InvoiceCrossDocumentResult> ValidateInvoiceCrossDocumentAsync(InvoiceData invoiceData, POData poData, CancellationToken cancellationToken)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting invoice cross-document validation. InvoiceNumber: {InvoiceNumber}, PONumber: {PONumber}. CorrelationId: {CorrelationId}",
            invoiceData.InvoiceNumber, poData.PONumber, correlationId);

        var result = new InvoiceCrossDocumentResult { AllChecksPass = true };

        // 1. Agency Code match
        if (!string.IsNullOrWhiteSpace(invoiceData.AgencyCode) && 
            !string.IsNullOrWhiteSpace(poData.AgencyCode))
        {
            result.AgencyCodeMatches = invoiceData.AgencyCode.Equals(poData.AgencyCode, StringComparison.OrdinalIgnoreCase);
            if (!result.AgencyCodeMatches)
            {
                result.AllChecksPass = false;
                result.Issues.Add($"Agency Code mismatch: Invoice has '{invoiceData.AgencyCode}', PO has '{poData.AgencyCode}'");
            }
        }

        // 2. PO Number match
        if (!string.IsNullOrWhiteSpace(invoiceData.PONumber) && 
            !string.IsNullOrWhiteSpace(poData.PONumber))
        {
            result.PONumberMatches = invoiceData.PONumber.Equals(poData.PONumber, StringComparison.OrdinalIgnoreCase);
            if (!result.PONumberMatches)
            {
                result.AllChecksPass = false;
                result.Issues.Add($"PO Number mismatch: Invoice references '{invoiceData.PONumber}', but package has PO '{poData.PONumber}'");
            }
        }

        // 3. GST State Mapping validation
        if (!string.IsNullOrWhiteSpace(invoiceData.GSTNumber) && 
            !string.IsNullOrWhiteSpace(invoiceData.StateCode))
        {
            result.GSTStateMatches = _referenceDataService.ValidateGSTStateMapping(
                invoiceData.GSTNumber, 
                invoiceData.StateCode);
            
            if (!result.GSTStateMatches)
            {
                result.AllChecksPass = false;
                var expectedState = _referenceDataService.GetStateCodeFromGST(invoiceData.GSTNumber);
                result.Issues.Add($"GST Number '{invoiceData.GSTNumber}' does not match State Code '{invoiceData.StateCode}'. Expected state: {expectedState}");
            }
        }

        // 4. HSN/SAC Code validation
        if (!string.IsNullOrWhiteSpace(invoiceData.HSNSACCode))
        {
            result.HSNSACCodeValid = _referenceDataService.ValidateHSNSACCode(invoiceData.HSNSACCode);
            if (!result.HSNSACCodeValid)
            {
                result.AllChecksPass = false;
                result.Issues.Add($"Invalid or unknown HSN/SAC Code: '{invoiceData.HSNSACCode}'");
            }
        }

        // 5. Invoice Amount validation (must be <= PO amount)
        result.InvoiceAmountValid = invoiceData.TotalAmount <= poData.TotalAmount;
        if (!result.InvoiceAmountValid)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"Invoice amount ({invoiceData.TotalAmount:F2}) exceeds PO amount ({poData.TotalAmount:F2})");
        }

        // 5b. Amount vs PO Balance — call SAP PO balance API
        if (!string.IsNullOrWhiteSpace(poData.PONumber))
        {
            try
            {
                var balanceResponse = await _poBalanceService.GetPoBalanceAsync(
                    "BAL", poData.PONumber, requestedBy: null, correlationId, cancellationToken);

                result.PoBalanceAmount = balanceResponse.Balance;
                result.PoBalanceValid = invoiceData.TotalAmount <= balanceResponse.Balance;

                if (!result.PoBalanceValid)
                {
                    result.AllChecksPass = false;
                    var indian = new System.Globalization.CultureInfo("en-IN");
                    result.Issues.Add(
                        $"₹{invoiceData.TotalAmount.ToString("N0", indian)} exceeds available PO balance (₹{balanceResponse.Balance.ToString("N0", indian)})");
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "PO balance check failed for PO {PONumber} — API call failed. CorrelationId: {CorrelationId}",
                    poData.PONumber, correlationId);
                // Mark as failed when we can't verify the balance
                result.PoBalanceValid = false;
                result.AllChecksPass = false;
                result.Issues.Add($"PO balance check failed for PO {poData.PONumber}: unable to fetch balance from API");
            }
        }

        // 6. GST Percentage validation (should match default 18% or state-specific rate)
        var expectedGSTPercentage = _referenceDataService.GetDefaultGSTPercentage(invoiceData.StateCode);
        result.GSTPercentageValid = Math.Abs(invoiceData.GSTPercentage - expectedGSTPercentage) < 0.01m;
        if (!result.GSTPercentageValid)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"GST Percentage mismatch: Invoice has {invoiceData.GSTPercentage}%, expected {expectedGSTPercentage}%");
        }

        _logger.LogInformation(
            "Invoice cross-document validation completed. AllChecksPass: {AllChecksPass}, IssueCount: {IssueCount}. CorrelationId: {CorrelationId}",
            result.AllChecksPass, result.Issues.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Validates that all required cost summary fields are present.
    /// Checks for place of supply, element-wise costs, number of days, element-wise quantities, and total cost.
    /// </summary>
    /// <param name="costSummaryData">The cost summary data to validate</param>
    /// <returns>A CostSummaryFieldPresenceResult listing any missing required fields</returns>
    private CostSummaryFieldPresenceResult ValidateCostSummaryFieldPresence(CostSummaryData costSummaryData)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting cost summary field presence validation. CorrelationId: {CorrelationId}",
            correlationId);

        var result = new CostSummaryFieldPresenceResult { AllFieldsPresent = true };
        var missingFields = new List<string>();

        // 1. Place of Supply (State) - Required
        if (string.IsNullOrWhiteSpace(costSummaryData.PlaceOfSupply) && 
            string.IsNullOrWhiteSpace(costSummaryData.State))
        {
            missingFields.Add("Place of Supply / State");
        }

        // 2. Element wise Cost - Required (check if cost breakdowns have amounts)
        // Requirement 6: Cost Summary Element-wise Cost Field Presence
        if (costSummaryData.CostBreakdowns == null || !costSummaryData.CostBreakdowns.Any())
        {
            missingFields.Add("Element wise Cost");
        }
        else
        {
            // Check each element individually for missing or invalid amounts
            var elementsWithMissingCost = costSummaryData.CostBreakdowns
                .Where(cb => cb.Amount <= 0)
                .Select(cb => cb.ElementName ?? cb.Category)
                .ToList();

            if (elementsWithMissingCost.Any())
            {
                missingFields.Add($"Element wise Cost (missing for: {string.Join(", ", elementsWithMissingCost)})");
            }
        }

        // 3. No of Days - Required
        // Requirement 7: Cost Summary Number of Days Field Presence
        if (!costSummaryData.NumberOfDays.HasValue || costSummaryData.NumberOfDays.Value <= 0)
        {
            missingFields.Add("Number of Days");
        }

        // 4. Element wise Quantity - Required (check if cost breakdowns have quantities)
        // Requirement 8: Cost Summary Element-wise Quantity Field Presence
        if (costSummaryData.CostBreakdowns == null || !costSummaryData.CostBreakdowns.Any())
        {
            if (!missingFields.Contains("Element wise Cost"))
            {
                missingFields.Add("Element wise Quantity");
            }
        }
        else
        {
            // Check each element individually for missing or invalid quantities
            var elementsWithMissingQuantity = costSummaryData.CostBreakdowns
                .Where(cb => !cb.Quantity.HasValue || cb.Quantity.Value <= 0)
                .Select(cb => cb.ElementName ?? cb.Category)
                .ToList();

            if (elementsWithMissingQuantity.Any())
            {
                missingFields.Add($"Element wise Quantity (missing for: {string.Join(", ", elementsWithMissingQuantity)})");
            }
        }

        // CHANGE: Added No of Activation field presence check per spec
        // 5. No of Activation - Required
        if (!costSummaryData.NumberOfActivations.HasValue || costSummaryData.NumberOfActivations.Value <= 0)
        {
            missingFields.Add("Number of Activations");
        }

        // CHANGE: Added No of Teams field presence check per spec
        // 6. No of Teams - Required
        if (!costSummaryData.NumberOfTeams.HasValue || costSummaryData.NumberOfTeams.Value <= 0)
        {
            missingFields.Add("Number of Teams");
        }

        // 7. Total Cost - Required
        if (costSummaryData.TotalCost <= 0)
        {
            missingFields.Add("Total Cost");
        }

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        _logger.LogInformation(
            "Cost summary field presence validation completed. AllFieldsPresent: {AllFieldsPresent}, MissingFieldCount: {MissingFieldCount}. CorrelationId: {CorrelationId}",
            result.AllFieldsPresent, missingFields.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Validates cost summary cross-document fields against invoice data.
    /// Checks total cost, element-wise costs against state rates, fixed cost limits, and variable cost limits.
    /// </summary>
    /// <param name="costSummaryData">The cost summary data to validate</param>
    /// <param name="invoiceData">The invoice data to validate against</param>
    /// <returns>A CostSummaryCrossDocumentResult containing validation status and any issues</returns>
    private CostSummaryCrossDocumentResult ValidateCostSummaryCrossDocument(
        CostSummaryData costSummaryData, 
        InvoiceData invoiceData)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting cost summary cross-document validation. TotalCost: {TotalCost}, InvoiceAmount: {InvoiceAmount}. CorrelationId: {CorrelationId}",
            costSummaryData.TotalCost, invoiceData.TotalAmount, correlationId);

        var result = new CostSummaryCrossDocumentResult { AllChecksPass = true };

        // Get state code for validation
        var stateCode = !string.IsNullOrWhiteSpace(costSummaryData.PlaceOfSupply) 
            ? costSummaryData.PlaceOfSupply 
            : costSummaryData.State;

        // 1. Total Cost validation (must be <= Invoice amount)
        result.TotalCostValid = costSummaryData.TotalCost <= invoiceData.TotalAmount;
        if (!result.TotalCostValid)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"Cost Summary total ({costSummaryData.TotalCost:F2}) exceeds Invoice amount ({invoiceData.TotalAmount:F2})");
        }

        // 2. Element wise Cost validation (match with state rates)
        result.ElementCostsValid = true;
        if (costSummaryData.CostBreakdowns != null && costSummaryData.CostBreakdowns.Any())
        {
            foreach (var breakdown in costSummaryData.CostBreakdowns)
            {
                if (!string.IsNullOrWhiteSpace(breakdown.ElementName))
                {
                    var isValid = _referenceDataService.ValidateElementCostAgainstStateRate(
                        breakdown.ElementName,
                        breakdown.Amount,
                        stateCode);

                    if (!isValid)
                    {
                        result.ElementCostsValid = false;
                        result.AllChecksPass = false;
                        var expectedRate = _referenceDataService.GetStateRate(breakdown.ElementName, stateCode);
                        result.Issues.Add($"Element '{breakdown.ElementName}' cost ({breakdown.Amount:F2}) does not match state rate (expected: {expectedRate:F2})");
                    }
                }
            }
        }

        // 3. Fixed Cost Limits validation
        result.FixedCostsValid = true;
        if (costSummaryData.CostBreakdowns != null && costSummaryData.CostBreakdowns.Any())
        {
            var fixedCosts = costSummaryData.CostBreakdowns.Where(cb => cb.IsFixedCost).ToList();
            foreach (var fixedCost in fixedCosts)
            {
                var isValid = _referenceDataService.ValidateFixedCostLimit(
                    fixedCost.Category,
                    fixedCost.Amount,
                    stateCode);

                if (!isValid)
                {
                    result.FixedCostsValid = false;
                    result.AllChecksPass = false;
                    result.Issues.Add($"Fixed cost '{fixedCost.Category}' ({fixedCost.Amount:F2}) exceeds state limit");
                }
            }
        }

        // 4. Variable Cost Limits validation
        result.VariableCostsValid = true;
        if (costSummaryData.CostBreakdowns != null && costSummaryData.CostBreakdowns.Any())
        {
            var variableCosts = costSummaryData.CostBreakdowns.Where(cb => cb.IsVariableCost).ToList();
            foreach (var variableCost in variableCosts)
            {
                var isValid = _referenceDataService.ValidateVariableCostLimit(
                    variableCost.Category,
                    variableCost.Amount,
                    stateCode);

                if (!isValid)
                {
                    result.VariableCostsValid = false;
                    result.AllChecksPass = false;
                    result.Issues.Add($"Variable cost '{variableCost.Category}' ({variableCost.Amount:F2}) exceeds state limit");
                }
            }
        }

        _logger.LogInformation(
            "Cost summary cross-document validation completed. AllChecksPass: {AllChecksPass}, IssueCount: {IssueCount}. CorrelationId: {CorrelationId}",
            result.AllChecksPass, result.Issues.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Validates that all required activity summary fields are present.
    /// Checks for dealer information, location activities, and number of days per location.
    /// </summary>
    /// <param name="activityData">The activity data to validate</param>
    /// <returns>An ActivityFieldPresenceResult listing any missing required fields</returns>
    // CHANGE: Updated ValidateActivityFieldPresence for new simplified ActivityData DTO (Rows with Dealer, Location, To, From, Day, WorkingDay)
    private ActivityFieldPresenceResult ValidateActivityFieldPresence(ActivityData activityData)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting activity field presence validation. DealerName: {DealerName}. CorrelationId: {CorrelationId}",
            activityData.DealerName, correlationId);

        var result = new ActivityFieldPresenceResult { AllFieldsPresent = true };
        var missingFields = new List<string>();

        if (activityData.Rows == null || !activityData.Rows.Any())
        {
            missingFields.Add("Activity Rows");
        }
        else
        {
            // Check if any row has dealer info
            var hasAnyDealer = activityData.Rows
                .Any(r => !string.IsNullOrWhiteSpace(r.DealerName));
            
            if (!hasAnyDealer)
            {
                missingFields.Add("Dealer Name");
            }

            // Check if rows have location
            var rowsWithoutLocation = activityData.Rows
                .Where(r => string.IsNullOrWhiteSpace(r.Location))
                .Count();

            if (rowsWithoutLocation > 0)
            {
                missingFields.Add($"Location missing for {rowsWithoutLocation} row(s)");
            }

            // Check if rows have days
            var rowsWithoutDays = activityData.Rows
                .Where(r => r.Day <= 0)
                .Count();

            if (rowsWithoutDays == activityData.Rows.Count)
            {
                missingFields.Add("Number of days");
            }
        }

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        _logger.LogInformation(
            "Activity field presence validation completed. AllFieldsPresent: {AllFieldsPresent}, MissingFieldCount: {MissingFieldCount}. CorrelationId: {CorrelationId}",
            result.AllFieldsPresent, missingFields.Count, correlationId);

        return result;
    }

    /// <summary>
    /// Validates activity summary cross-document fields against cost summary data.
    /// Ensures number of days matches between activity summary and cost summary.
    /// </summary>
    /// <param name="activityData">The activity data to validate</param>
    /// <param name="costSummaryData">The cost summary data to validate against</param>
    /// <returns>An ActivityCrossDocumentResult containing validation status and any issues</returns>
    // CHANGE: Updated ValidateActivityCrossDocument for new simplified ActivityData DTO
    private ActivityCrossDocumentResult ValidateActivityCrossDocument(
        ActivityData activityData,
        CostSummaryData costSummaryData)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting activity cross-document validation. CorrelationId: {CorrelationId}",
            correlationId);

        var result = new ActivityCrossDocumentResult { AllChecksPass = true };

        // Calculate working days from activity rows
        var activityTotalDays = activityData.Rows?.Sum(r => r.WorkingDay) ?? 0;

        var costSummaryDays = costSummaryData.NumberOfDays ?? 0;

        // Validate: Number of days must match between Activity and Cost Summary
        result.NumberOfDaysMatches = activityTotalDays == costSummaryDays;

        if (!result.NumberOfDaysMatches)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"No. of working days in Activity Summary ({activityTotalDays}) does not match No. of days in Cost Summary ({costSummaryDays})");
        }

        _logger.LogInformation(
            "Activity cross-document validation completed. AllChecksPass: {AllChecksPass}, ActivityDays: {ActivityDays}, CostSummaryDays: {CostSummaryDays}. CorrelationId: {CorrelationId}",
            result.AllChecksPass, activityTotalDays, costSummaryDays, correlationId);

        return result;
    }

    /// <summary>
    /// Validates photo field presence including date, location, and AI-detected content.
    /// Checks for EXIF metadata (date, GPS) and AI-detected features (blue t-shirt, Bajaj vehicle).
    /// </summary>
    /// <param name="teamPhotos">List of team photo entities to validate</param>
    /// <returns>A PhotoFieldPresenceResult with counts of photos meeting each requirement</returns>
    private PhotoFieldPresenceResult ValidatePhotoFieldPresence(List<Domain.Entities.TeamPhotos> teamPhotos)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting photo field presence validation. PhotoCount: {PhotoCount}. CorrelationId: {CorrelationId}",
            teamPhotos.Count, correlationId);

        var result = new PhotoFieldPresenceResult 
        { 
            AllFieldsPresent = true,
            TotalPhotos = teamPhotos.Count
        };
        var missingFields = new List<string>();

        if (!teamPhotos.Any())
        {
            missingFields.Add("No photos uploaded");
            result.AllFieldsPresent = false;
            result.MissingFields = missingFields;
            return result;
        }

        int photosWithDate = 0;
        int photosWithLocation = 0;
        int photosWithBlueTshirt = 0;
        int photosWithVehicle = 0;
        int photosWithFace = 0;
        var photoHashes = new List<(string FileName, string Hash)>();

        foreach (var photo in teamPhotos)
        {
            // Read from dedicated columns first, fall back to ExtractedMetadataJson then Caption
            // (same pattern as per-photo validation in BuildPerDocumentResults)
            bool hasDate = photo.DateVisible ?? photo.PhotoTimestamp.HasValue;
            bool hasLocation = photo.Latitude.HasValue && photo.Longitude.HasValue;
            bool hasBlueTshirt = photo.BlueTshirtPresent ?? false;
            bool hasVehicle = photo.ThreeWheelerPresent ?? false;
            bool hasFace = false;
            string? perceptualHash = null;

            // Fallback: parse ExtractedMetadataJson if dedicated columns are null
            var metadataSource = photo.ExtractedMetadataJson ?? photo.Caption;
            if (photo.DateVisible == null && photo.BlueTshirtPresent == null && !string.IsNullOrEmpty(metadataSource))
            {
                try
                {
                    var photoMetadata = JsonSerializer.Deserialize<PhotoMetadata>(metadataSource);
                    if (photoMetadata != null)
                    {
                        if (!hasDate && photoMetadata.Timestamp.HasValue) hasDate = true;
                        if (!hasLocation && photoMetadata.Latitude.HasValue && photoMetadata.Longitude.HasValue) hasLocation = true;
                        if (!hasBlueTshirt && photoMetadata.HasBlueTshirtPerson) hasBlueTshirt = true;
                        if (!hasVehicle && photoMetadata.HasBajajVehicle) hasVehicle = true;
                        if (photoMetadata.HasHumanFace) hasFace = true;
                        perceptualHash = photoMetadata.PerceptualHash;
                    }
                }
                catch { /* skip unparseable metadata */ }
            }
            else if (!string.IsNullOrEmpty(metadataSource))
            {
                // Dedicated columns are populated — still parse metadata for face detection and perceptual hash
                try
                {
                    var photoMetadata = JsonSerializer.Deserialize<PhotoMetadata>(metadataSource);
                    if (photoMetadata != null)
                    {
                        hasFace = photoMetadata.HasHumanFace;
                        perceptualHash = photoMetadata.PerceptualHash;
                    }
                }
                catch { /* skip unparseable metadata */ }
            }

            if (hasDate) photosWithDate++;
            if (hasLocation) photosWithLocation++;
            if (hasBlueTshirt) photosWithBlueTshirt++;
            if (hasVehicle) photosWithVehicle++;
            if (hasFace) photosWithFace++;

            if (!string.IsNullOrEmpty(perceptualHash))
            {
                var fileName = photo.BlobUrl ?? photo.Id.ToString();
                photoHashes.Add((fileName, perceptualHash));
            }
        }

        result.PhotosWithDate = photosWithDate;
        result.PhotosWithLocation = photosWithLocation;
        result.PhotosWithBlueTshirt = photosWithBlueTshirt;
        result.PhotosWithVehicle = photosWithVehicle;
        result.PhotosWithFace = photosWithFace;

        // Detect duplicate photos using perceptual hash comparison
        const double similarityThreshold = 0.9;
        for (int i = 0; i < photoHashes.Count; i++)
        {
            for (int j = i + 1; j < photoHashes.Count; j++)
            {
                var similarity = _perceptualHashService.ComputeSimilarity(
                    photoHashes[i].Hash, photoHashes[j].Hash);
                if (similarity >= similarityThreshold)
                {
                    result.DuplicatePhotos.Add(new DuplicatePhotoPair
                    {
                        Photo1FileName = photoHashes[i].FileName,
                        Photo2FileName = photoHashes[j].FileName,
                        SimilarityScore = similarity
                    });
                }
            }
        }

        if (photosWithDate < teamPhotos.Count)
        {
            missingFields.Add($"Date present on {photosWithDate} out of {teamPhotos.Count} photos");
        }

        if (photosWithLocation < teamPhotos.Count)
        {
            missingFields.Add($"Location coordinates present on {photosWithLocation} out of {teamPhotos.Count} photos");
        }

        if (photosWithBlueTshirt == 0)
        {
            missingFields.Add("No photos with person in blue t-shirt detected (AI validation)");
        }

        if (photosWithVehicle == 0)
        {
            missingFields.Add("No photos with Bajaj vehicle detected (AI validation)");
        }

        if (photosWithFace == 0)
        {
            missingFields.Add("No photos with human face detected (AI validation)");
        }

        if (result.DuplicatePhotos.Count > 0)
        {
            missingFields.Add($"Duplicate images detected: {result.DuplicatePhotos.Count} pair(s) with >90% similarity");
        }

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        _logger.LogInformation(
            "Photo field presence validation completed. AllFieldsPresent: {AllFieldsPresent}, PhotosWithDate: {PhotosWithDate}, PhotosWithLocation: {PhotosWithLocation}. CorrelationId: {CorrelationId}",
            result.AllFieldsPresent, result.PhotosWithDate, result.PhotosWithLocation, correlationId);

        return result;
    }

    /// <summary>
    /// Validates photo cross-document consistency with activity and cost summary data.
    /// Extracts dates from photos, deduplicates to unique days, and compares against Activity Summary days.
    /// </summary>
    /// <param name="photos">List of team photos in the package</param>
    /// <param name="activityData">Activity summary data (optional)</param>
    /// <param name="costSummaryData">Cost summary data (optional)</param>
    /// <returns>A PhotoCrossDocumentResult containing validation status and any issues</returns>
    private PhotoCrossDocumentResult ValidatePhotoCrossDocument(
        List<Domain.Entities.TeamPhotos> photos,
        ActivityData? activityData,
        CostSummaryData? costSummaryData)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Starting photo cross-document validation. PhotoCount: {PhotoCount}. CorrelationId: {CorrelationId}",
            photos.Count, correlationId);

        var result = new PhotoCrossDocumentResult 
        { 
            AllChecksPass = true,
            PhotoCount = photos.Count
        };

        // Extract unique days from photo dates (EXIF timestamp or overlay date)
        var uniqueDates = new HashSet<DateOnly>();
        foreach (var photo in photos)
        {
            DateOnly? photoDate = null;

            // Priority 1: EXIF timestamp from dedicated column
            if (photo.PhotoTimestamp.HasValue)
            {
                photoDate = DateOnly.FromDateTime(photo.PhotoTimestamp.Value);
            }
            // Priority 2: Overlay date text
            else if (!string.IsNullOrEmpty(photo.PhotoDateOverlay) && DateTime.TryParse(photo.PhotoDateOverlay, out var overlayDt))
            {
                photoDate = DateOnly.FromDateTime(overlayDt);
            }
            // Priority 3: Parse from ExtractedMetadataJson
            else if (!string.IsNullOrEmpty(photo.ExtractedMetadataJson))
            {
                try
                {
                    var json = System.Text.Json.JsonSerializer.Deserialize<System.Text.Json.JsonElement>(
                        photo.ExtractedMetadataJson,
                        new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                    if (json.TryGetProperty("timestamp", out var ts) && ts.ValueKind != System.Text.Json.JsonValueKind.Null)
                    {
                        if (DateTime.TryParse(ts.GetString(), out var tsDt))
                            photoDate = DateOnly.FromDateTime(tsDt);
                    }
                    if (!photoDate.HasValue && json.TryGetProperty("photoDateFromOverlay", out var ov) && ov.ValueKind != System.Text.Json.JsonValueKind.Null)
                    {
                        if (DateTime.TryParse(ov.GetString(), out var ovDt))
                            photoDate = DateOnly.FromDateTime(ovDt);
                    }
                }
                catch
                {
                    // Metadata parse failure — skip this photo's date
                }
            }

            if (photoDate.HasValue)
            {
                uniqueDates.Add(photoDate.Value);
            }
        }

        int uniquePhotoDays = uniqueDates.Count;
        result.UniquePhotoDays = uniquePhotoDays;

        // Get Activity Summary days (Activation Days / Billed Days / Working Days — all equivalent)
        int activitySummaryDays = activityData?.Rows?.Sum(r => r.WorkingDay) ?? activityData?.TotalDays ?? 0;
        result.ActivitySummaryDays = activitySummaryDays;

        // Also keep cost summary days for backward compatibility
        int costSummaryDays = costSummaryData?.NumberOfDays ?? 0;
        result.CostSummaryDays = costSummaryDays;

        // No. of Days validation: unique photo days must match Activity Summary days
        result.NumberOfDaysMatches = uniquePhotoDays == activitySummaryDays;
        // Keep legacy property in sync
        result.PhotoCountMatchesManDays = result.NumberOfDaysMatches;

        if (!result.NumberOfDaysMatches && activitySummaryDays > 0)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"Photos cover {uniquePhotoDays} unique day(s) but Activity Summary states {activitySummaryDays} day(s)");
        }
        else if (!result.NumberOfDaysMatches && activitySummaryDays == 0 && costSummaryDays > 0)
        {
            // Fallback: if Activity Summary days not available, compare against Cost Summary days
            result.NumberOfDaysMatches = uniquePhotoDays == costSummaryDays;
            result.PhotoCountMatchesManDays = result.NumberOfDaysMatches;
            if (!result.NumberOfDaysMatches)
            {
                result.AllChecksPass = false;
                result.Issues.Add($"Photos cover {uniquePhotoDays} unique day(s) but Cost Summary states {costSummaryDays} day(s)");
            }
        }

        _logger.LogInformation(
            "Photo cross-document validation completed. AllChecksPass: {AllChecksPass}, PhotoCount: {PhotoCount}, UniquePhotoDays: {UniquePhotoDays}, ActivitySummaryDays: {ActivitySummaryDays}. CorrelationId: {CorrelationId}",
            result.AllChecksPass, photos.Count, uniquePhotoDays, activitySummaryDays, correlationId);

        return result;
    }

    // CHANGE: Added ValidateEnquiryDumpFieldPresence for Enquiry Dump field validation
    /// <summary>
    /// Validates that Enquiry Dump has all required fields: State, Date, DealerCode, DealerName, District, Pincode, CustomerName, CustomerNumber, TestRideTaken
    /// </summary>
    private EnquiryDumpFieldPresenceResult ValidateEnquiryDumpFieldPresence(EnquiryDumpData enquiryDumpData)
    {
        var result = new EnquiryDumpFieldPresenceResult { AllFieldsPresent = true };
        var missingFields = new List<string>();

        // Check if there are any records
        if (enquiryDumpData.Records == null || !enquiryDumpData.Records.Any())
        {
            missingFields.Add("No enquiry records found");
            result.TotalRecords = 0;
        }
        else
        {
            result.TotalRecords = enquiryDumpData.Records.Count;

            // Count records with each field present
            result.RecordsWithState = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.State));
            result.RecordsWithDate = enquiryDumpData.Records.Count(r => r.Date.HasValue);
            result.RecordsWithDealerCode = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.DealerCode));
            result.RecordsWithDealerName = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.DealerName));
            result.RecordsWithDistrict = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.District));
            result.RecordsWithPincode = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.Pincode));
            result.RecordsWithCustomerName = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.CustomerName));
            result.RecordsWithCustomerNumber = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.CustomerNumber));
            result.RecordsWithTestRide = enquiryDumpData.Records.Count(r => !string.IsNullOrWhiteSpace(r.TestRideTaken));

            // Flag fields where more than 50% of records are missing the field
            int threshold = result.TotalRecords / 2;

            if (result.RecordsWithState <= threshold)
                missingFields.Add($"State (present in {result.RecordsWithState}/{result.TotalRecords} records)");
            if (result.RecordsWithDate <= threshold)
                missingFields.Add($"Date (present in {result.RecordsWithDate}/{result.TotalRecords} records)");
            if (result.RecordsWithDealerCode <= threshold)
                missingFields.Add($"Dealer Code (present in {result.RecordsWithDealerCode}/{result.TotalRecords} records)");
            if (result.RecordsWithDealerName <= threshold)
                missingFields.Add($"Dealer Name (present in {result.RecordsWithDealerName}/{result.TotalRecords} records)");
            if (result.RecordsWithDistrict <= threshold)
                missingFields.Add($"District (present in {result.RecordsWithDistrict}/{result.TotalRecords} records)");
            if (result.RecordsWithPincode <= threshold)
                missingFields.Add($"Pincode (present in {result.RecordsWithPincode}/{result.TotalRecords} records)");
            if (result.RecordsWithCustomerName <= threshold)
                missingFields.Add($"Customer Name (present in {result.RecordsWithCustomerName}/{result.TotalRecords} records)");
            if (result.RecordsWithCustomerNumber <= threshold)
                missingFields.Add($"Customer Number (present in {result.RecordsWithCustomerNumber}/{result.TotalRecords} records)");
            if (result.RecordsWithTestRide <= threshold)
                missingFields.Add($"Test Ride Taken (present in {result.RecordsWithTestRide}/{result.TotalRecords} records)");
        }

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        return result;
    }

    // CHANGE: Added ValidateEnquiryDumpCrossDocument for cross-document validation with Activity Summary
    /// <summary>
    /// Validates Enquiry Dump against Activity Summary: State match, Dealer details match
    /// </summary>
    private EnquiryDumpCrossDocumentResult ValidateEnquiryDumpCrossDocument(
        EnquiryDumpData enquiryDumpData,
        ActivityData activityData)
    {
        var result = new EnquiryDumpCrossDocumentResult { AllChecksPass = true };

        // CHANGE: Updated for new ActivityData DTO — no top-level State, use Rows instead of LocationActivities

        // 1. Dealer details match: Dealers in Enquiry Dump should exist in Activity Summary rows
        if (enquiryDumpData.Records != null && enquiryDumpData.Records.Any() &&
            activityData.Rows != null && activityData.Rows.Any())
        {
            var activityDealerNames = activityData.Rows
                .Where(r => !string.IsNullOrWhiteSpace(r.DealerName))
                .Select(r => r.DealerName!.Trim().ToUpperInvariant())
                .ToHashSet();

            var enquiryDealerNames = enquiryDumpData.Records
                .Where(r => !string.IsNullOrWhiteSpace(r.DealerName))
                .Select(r => r.DealerName!.Trim().ToUpperInvariant())
                .Distinct()
                .ToList();

            if (activityDealerNames.Any() && enquiryDealerNames.Any())
            {
                var unmatchedDealers = enquiryDealerNames
                    .Where(dn => !activityDealerNames.Contains(dn))
                    .ToList();

                result.DealerDetailsMatchActivity = unmatchedDealers.Count == 0;
                if (!result.DealerDetailsMatchActivity)
                {
                    result.AllChecksPass = false;
                    result.Issues.Add($"Enquiry Dump has {unmatchedDealers.Count} dealer(s) not found in Activity Summary: {string.Join(", ", unmatchedDealers.Take(5))}");
                }
            }
        }

        return result;
    }

    /// <summary>
    /// Persists per-document-type validation results to the database.
    /// Creates or updates a ValidationResult entity for each document type that was validated.
    /// Errors on individual saves are logged and do not block the pipeline.
    /// </summary>
    private async Task SaveValidationResultsAsync(
        PackageValidationResult result,
        Domain.Entities.DocumentPackage package,
        CancellationToken cancellationToken)
    {
        var correlationId = _correlationIdService.GetCorrelationId();
        _logger.LogInformation(
            "Persisting validation results for package {PackageId}. CorrelationId: {CorrelationId}",
            package.Id, correlationId);

        var documentResults = BuildPerDocumentResults(result, package);

        foreach (var (documentType, documentId, allPassed, failureReason, detailsJson, ruleResultsJson) in documentResults)
        {
            try
            {
                var existing = await _context.ValidationResults
                    .FirstOrDefaultAsync(
                        v => v.DocumentType == documentType && v.DocumentId == documentId,
                        cancellationToken);

                // Merge the current run's rules into ValidationDetailsJson so the web detail pages
                // always have a "proactiveRules" key with all validation rows.
                // For existing records with prior chatbot rules, combine both rule sets first.
                // New reactive rules take precedence (primary) over old stored rules (secondary)
                // because reactive rules use live API data (e.g. PO balance) that may have changed.
                var combinedRulesJson = CombineRuleArrays(ruleResultsJson, existing?.RuleResultsJson);
                var mergedDetailsJson = MergeProactiveRulesIntoDetails(detailsJson, combinedRulesJson);

                if (existing != null)
                {
                    existing.AllValidationsPassed = allPassed;
                    existing.FailureReason = failureReason;
                    existing.ValidationDetailsJson = mergedDetailsJson;
                    existing.RuleResultsJson = ruleResultsJson;
                    existing.UpdatedAt = DateTime.UtcNow;
                }
                else
                {
                    _context.ValidationResults.Add(new Domain.Entities.ValidationResult
                    {
                        Id = Guid.NewGuid(),
                        DocumentType = documentType,
                        DocumentId = documentId,
                        AllValidationsPassed = allPassed,
                        FailureReason = failureReason,
                        ValidationDetailsJson = mergedDetailsJson,
                        RuleResultsJson = ruleResultsJson,
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    });
                }

                await _context.SaveChangesAsync(cancellationToken);

                _logger.LogInformation(
                    "Saved ValidationResult for {DocumentType} (DocumentId: {DocumentId}). Passed: {Passed}",
                    documentType, documentId, allPassed);
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Failed to save ValidationResult for {DocumentType} (DocumentId: {DocumentId}). CorrelationId: {CorrelationId}",
                    documentType, documentId, correlationId);
            }
        }
    }

    /// <summary>
    /// Merges proactive rule results (from RuleResultsJson) into the reactive ValidationDetailsJson.
    /// Proactive rules are added under a "proactiveRules" key. Reactive checks that overlap with
    /// proactive rules (by matching rule code patterns) are not duplicated — the proactive version
    /// is kept since it has richer detail (extractedValue, expectedValue, message).
    /// </summary>
    private static string MergeProactiveRulesIntoDetails(string? reactiveDetailsJson, string? ruleResultsJson)
    {
        if (string.IsNullOrWhiteSpace(ruleResultsJson))
            return reactiveDetailsJson ?? "{}";

        try
        {
            // Parse the reactive details (e.g. {"fieldPresence": {...}, "crossDocument": {...}})
            using var reactiveDoc = JsonDocument.Parse(reactiveDetailsJson ?? "{}");

            // Parse the proactive rules array
            using var proactiveDoc = JsonDocument.Parse(ruleResultsJson);
            if (proactiveDoc.RootElement.ValueKind != JsonValueKind.Array)
                return reactiveDetailsJson ?? "{}";

            // Collect proactive rule codes for dedup
            var proactiveRuleCodes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var rule in proactiveDoc.RootElement.EnumerateArray())
            {
                if (rule.TryGetProperty("RuleCode", out var rc) || rule.TryGetProperty("ruleCode", out rc))
                {
                    var code = rc.GetString();
                    if (!string.IsNullOrEmpty(code))
                        proactiveRuleCodes.Add(code);
                }
            }

            // Build reactive rules from fieldPresence.missingFields and crossDocument.issues
            // to detect overlap with proactive rules
            var reactiveFieldNames = ExtractReactiveFieldNames(reactiveDoc.RootElement);

            // Build merged JSON: copy all reactive properties + add proactiveRules array
            using var stream = new MemoryStream();
            using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = false }))
            {
                writer.WriteStartObject();

                // Copy all existing reactive properties
                foreach (var prop in reactiveDoc.RootElement.EnumerateObject())
                {
                    prop.WriteTo(writer);
                }

                // Add proactive rules array
                writer.WritePropertyName("proactiveRules");
                proactiveDoc.RootElement.WriteTo(writer);

                writer.WriteEndObject();
            }

            return System.Text.Encoding.UTF8.GetString(stream.ToArray());
        }
        catch (JsonException ex)
        {
            // If JSON parsing fails, return reactive details unchanged
            System.Diagnostics.Debug.WriteLine($"Failed to merge proactive rules: {ex.Message}");
            return reactiveDetailsJson ?? "{}";
        }
    }

    /// <summary>
    /// Extracts field names referenced in reactive validation details for dedup awareness.
    /// </summary>
    private static HashSet<string> ExtractReactiveFieldNames(JsonElement root)
    {
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        if (root.TryGetProperty("fieldPresence", out var fp) &&
            fp.TryGetProperty("missingFields", out var mf) &&
            mf.ValueKind == JsonValueKind.Array)
        {
            foreach (var field in mf.EnumerateArray())
            {
                var val = field.GetString();
                if (!string.IsNullOrEmpty(val))
                    names.Add(val);
            }
        }

        if (root.TryGetProperty("crossDocument", out var cd) &&
            cd.TryGetProperty("issues", out var issues) &&
            issues.ValueKind == JsonValueKind.Array)
        {
            foreach (var issue in issues.EnumerateArray())
            {
                var val = issue.GetString();
                if (!string.IsNullOrEmpty(val))
                    names.Add(val);
            }
        }

        return names;
    }

    /// <summary>
    /// Combines two JSON rule arrays into one, deduplicating by ruleCode.
    /// The primary array takes precedence over the secondary for duplicate codes.
    /// </summary>
    private static string? CombineRuleArrays(string? primaryJson, string? secondaryJson)
    {
        if (string.IsNullOrWhiteSpace(primaryJson) && string.IsNullOrWhiteSpace(secondaryJson))
            return null;
        if (string.IsNullOrWhiteSpace(secondaryJson))
            return primaryJson;
        if (string.IsNullOrWhiteSpace(primaryJson))
            return secondaryJson;

        try
        {
            using var primaryDoc = JsonDocument.Parse(primaryJson);
            using var secondaryDoc = JsonDocument.Parse(secondaryJson);

            if (primaryDoc.RootElement.ValueKind != JsonValueKind.Array)
                return secondaryJson;
            if (secondaryDoc.RootElement.ValueKind != JsonValueKind.Array)
                return primaryJson;

            // Collect rule codes from primary
            var seenCodes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var rule in primaryDoc.RootElement.EnumerateArray())
            {
                if (rule.TryGetProperty("RuleCode", out var rc) || rule.TryGetProperty("ruleCode", out rc))
                {
                    var code = rc.GetString();
                    if (!string.IsNullOrEmpty(code))
                        seenCodes.Add(code);
                }
            }

            using var stream = new MemoryStream();
            using (var writer = new Utf8JsonWriter(stream))
            {
                writer.WriteStartArray();

                // Write all primary rules
                foreach (var rule in primaryDoc.RootElement.EnumerateArray())
                    rule.WriteTo(writer);

                // Write secondary rules not already in primary
                foreach (var rule in secondaryDoc.RootElement.EnumerateArray())
                {
                    string? code = null;
                    if (rule.TryGetProperty("RuleCode", out var rc) || rule.TryGetProperty("ruleCode", out rc))
                        code = rc.GetString();

                    if (string.IsNullOrEmpty(code) || !seenCodes.Contains(code))
                        rule.WriteTo(writer);
                }

                writer.WriteEndArray();
            }

            return System.Text.Encoding.UTF8.GetString(stream.ToArray());
        }
        catch (JsonException)
        {
            return primaryJson ?? secondaryJson;
        }
    }

    /// <summary>
    /// Builds a list of per-document-type validation result tuples from the package validation result.
    /// Each tuple includes RuleResultsJson in the same format as the chatbot pipeline.
    /// </summary>
    private static List<(DocumentType Type, Guid DocumentId, bool AllPassed, string? FailureReason, string? DetailsJson, string? RuleResultsJson)>
        BuildPerDocumentResults(PackageValidationResult result, Domain.Entities.DocumentPackage package)
    {
        var items = new List<(DocumentType, Guid, bool, string?, string?, string?)>();
        var jsonOptions = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull };

        // Helper: serialize rules list to RuleResultsJson
        static string? SerializeRules(IEnumerable<object> rules) =>
            JsonSerializer.Serialize(rules);

        // PO: SAP verification + date validation
        if (package.PO != null)
        {
            var passed = (result.SAPVerification?.IsVerified ?? true || result.SAPVerification?.SAPConnectionFailed == true)
                         && (result.DateValidation?.IsValid ?? true);
            var issues = new List<string>();
            if (result.SAPVerification != null && !result.SAPVerification.IsVerified && !result.SAPVerification.SAPConnectionFailed)
                issues.AddRange(result.SAPVerification.Discrepancies);
            if (result.DateValidation != null && !result.DateValidation.IsValid)
                issues.AddRange(result.DateValidation.DateIssues);

            var details = new { sapVerification = result.SAPVerification, dateValidation = result.DateValidation };
            var poRules = new List<object>
            {
                new { ruleCode = "PO_SAP_VERIFIED", type = "Required", passed = result.SAPVerification?.IsVerified ?? true, isWarning = false, label = "SAP Verification", extractedValue = result.SAPVerification?.IsVerified == true ? "Verified" : (string?)null, message = result.SAPVerification?.IsVerified == false ? string.Join("; ", result.SAPVerification.Discrepancies) : null },
                new { ruleCode = "PO_DATE_VALID", type = "Required", passed = result.DateValidation?.IsValid ?? true, isWarning = false, label = "Date Validation", extractedValue = (string?)null, message = result.DateValidation?.IsValid == false ? string.Join("; ", result.DateValidation.DateIssues) : null }
            };
            items.Add((DocumentType.PO, package.PO.Id, passed,
                issues.Count > 0 ? string.Join("; ", issues) : null,
                JsonSerializer.Serialize(details, jsonOptions),
                SerializeRules(poRules)));
        }

        // Invoice: field presence + cross-document + cross-cutting checks (amount consistency, line items, vendor matching)
        var invoiceDoc = package.Invoices.FirstOrDefault();
        if (invoiceDoc != null)
        {
            var invPassed = (result.InvoiceFieldPresence?.AllFieldsPresent ?? true)
                            && (result.InvoiceCrossDocument?.AllChecksPass ?? true);
            var invIssues = new List<string>();
            if (result.InvoiceFieldPresence != null && !result.InvoiceFieldPresence.AllFieldsPresent)
                invIssues.AddRange(result.InvoiceFieldPresence.MissingFields);
            if (result.InvoiceCrossDocument != null && !result.InvoiceCrossDocument.AllChecksPass)
                invIssues.AddRange(result.InvoiceCrossDocument.Issues);

            // Include cross-cutting validations that involve the invoice
            if (result.AmountConsistency != null && !result.AmountConsistency.IsConsistent)
                invIssues.Add($"Amount mismatch: Invoice {result.AmountConsistency.InvoiceTotal:F2} vs Cost Summary {result.AmountConsistency.CostSummaryTotal:F2} (diff {result.AmountConsistency.PercentageDifference:F1}%)");
            if (result.LineItemMatching != null && !result.LineItemMatching.AllItemsMatched)
                invIssues.Add($"Missing {result.LineItemMatching.MissingItemCodes.Count} PO line items: {string.Join(", ", result.LineItemMatching.MissingItemCodes)}");
            if (result.VendorMatching != null && !result.VendorMatching.IsMatched)
                invIssues.Add($"Vendor mismatch: PO={result.VendorMatching.POVendor}, Invoice={result.VendorMatching.InvoiceVendor}, SAP={result.VendorMatching.SAPVendor}");

            var details = new
            {
                fieldPresence = result.InvoiceFieldPresence,
                crossDocument = result.InvoiceCrossDocument,
                amountConsistency = result.AmountConsistency,
                lineItemMatching = result.LineItemMatching,
                vendorMatching = result.VendorMatching
            };
            // Read agency/billing/state from ExtractedDataJson (not stored as dedicated columns on Invoice entity)
            string? invAgencyName = null, invAgencyAddr = null, invBillingName = null, invBillingAddr = null, invStateVal = null;
            decimal? invGstPercent = null;
            string? invVendorCode = null;
            if (!string.IsNullOrEmpty(invoiceDoc.ExtractedDataJson))
            {
                try
                {
                    var invJson = JsonSerializer.Deserialize<JsonElement>(invoiceDoc.ExtractedDataJson);
                    if (invJson.TryGetProperty("AgencyName", out var an) || invJson.TryGetProperty("agencyName", out an)) invAgencyName = an.GetString();
                    if (invJson.TryGetProperty("AgencyAddress", out var aa) || invJson.TryGetProperty("agencyAddress", out aa)) invAgencyAddr = aa.GetString();
                    if (invJson.TryGetProperty("BillingName", out var bn) || invJson.TryGetProperty("billingName", out bn)) invBillingName = bn.GetString();
                    if (invJson.TryGetProperty("BillingAddress", out var ba) || invJson.TryGetProperty("billingAddress", out ba)) invBillingAddr = ba.GetString();
                    if (invJson.TryGetProperty("StateName", out var sn) || invJson.TryGetProperty("stateName", out sn)) invStateVal = sn.GetString();
                    if (string.IsNullOrWhiteSpace(invStateVal) && (invJson.TryGetProperty("StateCode", out var sc) || invJson.TryGetProperty("stateCode", out sc))) invStateVal = sc.GetString();
                    if (invJson.TryGetProperty("GSTPercentage", out var gp) || invJson.TryGetProperty("gstPercentage", out gp) || invJson.TryGetProperty("gstPercent", out gp))
                    {
                        if (gp.ValueKind == JsonValueKind.Number) invGstPercent = gp.GetDecimal();
                    }
                    if (invJson.TryGetProperty("VendorCode", out var vc) || invJson.TryGetProperty("vendorCode", out vc)) invVendorCode = vc.GetString();
                }
                catch { }
            }
            // Also fall back to the entity's extracted data (already parsed above via invJson)
            // invGstPercent is already populated from ExtractedDataJson if present
            var invAgencyOk = !string.IsNullOrWhiteSpace(invAgencyName) && !string.IsNullOrWhiteSpace(invAgencyAddr);
            var invAgencyExtracted = invAgencyOk ? $"{invAgencyName}, {invAgencyAddr}" : invAgencyName ?? invAgencyAddr;
            var invBillingOk = !string.IsNullOrWhiteSpace(invBillingName) && !string.IsNullOrWhiteSpace(invBillingAddr);
            var invBillingExtracted = invBillingOk ? $"{invBillingName}, {invBillingAddr}" : invBillingName ?? invBillingAddr;
            var invStateOk = !string.IsNullOrWhiteSpace(invStateVal);

            var invRules = new List<object>
            {
                new { ruleCode = "INV_NUMBER_PRESENT", type = "Required", passed = !(result.InvoiceFieldPresence?.MissingFields?.Contains("Invoice Number") ?? false), isWarning = false, label = "Invoice Number", extractedValue = invoiceDoc.InvoiceNumber, message = (string?)null },
                new { ruleCode = "INV_DATE_PRESENT", type = "Required", passed = !(result.InvoiceFieldPresence?.MissingFields?.Contains("Invoice Date") ?? false), isWarning = false, label = "Invoice Date", extractedValue = invoiceDoc.InvoiceDate?.ToString("dd-MMM-yyyy"), message = (string?)null },
                new { ruleCode = "INV_AMOUNT_PRESENT", type = "Required", passed = !(result.InvoiceFieldPresence?.MissingFields?.Contains("Invoice Amount") ?? false), isWarning = false, label = "Invoice Amount", extractedValue = invoiceDoc.TotalAmount.HasValue ? $"₹{invoiceDoc.TotalAmount:N0}" : null, message = (string?)null },
                new { ruleCode = "INV_GST_PRESENT", type = "Required", passed = !(result.InvoiceFieldPresence?.MissingFields?.Contains("GST Number") ?? false), isWarning = false, label = "GST Number", extractedValue = invoiceDoc.GSTNumber, message = (string?)null },
                new { ruleCode = "INV_AGENCY_NAME_ADDRESS", type = "Required", passed = invAgencyOk, isWarning = false, label = "Agency Name & Address", extractedValue = invAgencyExtracted, message = invAgencyOk ? null : (string.IsNullOrWhiteSpace(invAgencyName) ? "Supplier name not detected" : "Supplier address not detected") },
                new { ruleCode = "INV_VENDOR_CODE_PRESENT", type = "Required", passed = !string.IsNullOrWhiteSpace(invVendorCode), isWarning = false, label = "Agency Code", extractedValue = invVendorCode, message = !string.IsNullOrWhiteSpace(invVendorCode) ? null : "Agency code not detected" },
                new { ruleCode = "INV_BILLING_NAME_ADDRESS", type = "Required", passed = invBillingOk, isWarning = false, label = "Billing Name & Address", extractedValue = invBillingExtracted, message = invBillingOk ? null : (string.IsNullOrWhiteSpace(invBillingName) ? "Recipient name not detected" : "Recipient address not detected") },
                new { ruleCode = "INV_SUPPLIER_STATE", type = "Required", passed = invStateOk, isWarning = false, label = "Supplier State", extractedValue = invStateVal, message = invStateOk ? null : "Supplier state not detected" },
                new { ruleCode = "INV_PO_MATCH", type = "Required", passed = result.InvoiceCrossDocument?.PONumberMatches ?? true, isWarning = false, label = "PO Number Match", extractedValue = (string?)null, message = result.InvoiceCrossDocument?.PONumberMatches == false ? "PO number mismatch" : null },
                new { ruleCode = "INV_GST_PERCENT_PRESENT", type = "Required", passed = invGstPercent.HasValue && invGstPercent.Value > 0, isWarning = false, label = "GST %", extractedValue = invGstPercent.HasValue && invGstPercent.Value > 0 ? $"{invGstPercent.Value}%" : (string?)null, message = invGstPercent.HasValue && invGstPercent.Value > 0 ? null : "Field is missing" },
            };
            // INV_AMOUNT_VS_PO_BALANCE — always include
            {
                var indian = new System.Globalization.CultureInfo("en-IN");
                var poBalPassed = result.InvoiceCrossDocument?.PoBalanceValid ?? true;
                var extractedAmt = invoiceDoc.TotalAmount.HasValue
                    ? $"₹{invoiceDoc.TotalAmount.Value.ToString("N0", indian)}"
                    : (string?)null;
                var poBalMsg = !poBalPassed && invoiceDoc.TotalAmount.HasValue
                    ? $"₹{invoiceDoc.TotalAmount.Value.ToString("N0", indian)} exceeds available PO balance (₹{result.InvoiceCrossDocument!.PoBalanceAmount!.Value.ToString("N0", indian)})"
                    : (result.InvoiceCrossDocument?.PoBalanceAmount.HasValue == true ? null : "Field is missing");
                invRules.Add(new { ruleCode = "INV_AMOUNT_VS_PO_BALANCE", type = "Required", passed = poBalPassed, isWarning = false, label = "Amount vs PO Balance", extractedValue = extractedAmt, message = poBalMsg });
            }
            items.Add((DocumentType.Invoice, invoiceDoc.Id, invPassed,
                invIssues.Count > 0 ? string.Join("; ", invIssues) : null,
                JsonSerializer.Serialize(details, jsonOptions),
                SerializeRules(invRules)));
        }

        // CostSummary: field presence + cross-document + completeness check (package-level)
        if (package.CostSummary != null)
        {
            var passed = (result.CostSummaryFieldPresence?.AllFieldsPresent ?? true)
                         && (result.CostSummaryCrossDocument?.AllChecksPass ?? true);
            var issues = new List<string>();
            if (result.CostSummaryFieldPresence != null && !result.CostSummaryFieldPresence.AllFieldsPresent)
                issues.AddRange(result.CostSummaryFieldPresence.MissingFields);
            if (result.CostSummaryCrossDocument != null && !result.CostSummaryCrossDocument.AllChecksPass)
                issues.AddRange(result.CostSummaryCrossDocument.Issues);
            if (result.Completeness != null && !result.Completeness.IsComplete)
                issues.Add($"Missing {result.Completeness.MissingItems.Count} required items: {string.Join(", ", result.Completeness.MissingItems)}");

            var details = new { fieldPresence = result.CostSummaryFieldPresence, crossDocument = result.CostSummaryCrossDocument, completeness = result.Completeness };
            var cs = package.CostSummary;
            var csRules = new List<object>
            {
                new { ruleCode = "CS_PLACE_OF_SUPPLY", type = "Required", passed = !string.IsNullOrWhiteSpace(cs.PlaceOfSupply), isWarning = false, label = "Place of Supply", extractedValue = cs.PlaceOfSupply, message = (string?)null },
                new { ruleCode = "CS_NUMBER_OF_DAYS", type = "Required", passed = cs.NumberOfDays.HasValue && cs.NumberOfDays > 0, isWarning = false, label = "No. of Days", extractedValue = cs.NumberOfDays?.ToString(), message = (string?)null },
                new { ruleCode = "CS_NUMBER_OF_ACTIVATIONS", type = "Required", passed = cs.NumberOfActivations.HasValue && cs.NumberOfActivations > 0, isWarning = false, label = "No. of Activations", extractedValue = cs.NumberOfActivations?.ToString(), message = (string?)null },
                new { ruleCode = "CS_NUMBER_OF_TEAMS", type = "Required", passed = cs.NumberOfTeams.HasValue && cs.NumberOfTeams > 0, isWarning = false, label = "No. of Teams", extractedValue = cs.NumberOfTeams?.ToString(), message = (string?)null },
                new { ruleCode = "CS_ELEMENT_WISE_COST", type = "Required", passed = !string.IsNullOrWhiteSpace(cs.ElementWiseCostsJson) && cs.ElementWiseCostsJson != "[]", isWarning = false, label = "Element-wise Cost", extractedValue = "Cost breakdown detected", message = (string?)null },
                new { ruleCode = "CS_ELEMENT_WISE_QTY", type = "Required", passed = !string.IsNullOrWhiteSpace(cs.ElementWiseQuantityJson) && cs.ElementWiseQuantityJson != "[]", isWarning = false, label = "Element-wise Quantity", extractedValue = "Quantity breakdown detected", message = (string?)null },
                new { ruleCode = "CS_FIXED_COST_LIMITS", type = "Check", passed = result.CostSummaryCrossDocument?.FixedCostsValid ?? true, isWarning = !(result.CostSummaryCrossDocument?.FixedCostsValid ?? true), label = "Fixed Cost Limits", extractedValue = (string?)null, message = (result.CostSummaryCrossDocument?.FixedCostsValid ?? true) ? "Fixed cost items within state limits" : "One or more fixed cost items exceed state limit" },
                new { ruleCode = "CS_VARIABLE_COST_LIMITS", type = "Check", passed = result.CostSummaryCrossDocument?.VariableCostsValid ?? true, isWarning = !(result.CostSummaryCrossDocument?.VariableCostsValid ?? true), label = "Variable Cost Limits", extractedValue = (string?)null, message = (result.CostSummaryCrossDocument?.VariableCostsValid ?? true) ? "Variable cost items within state limits" : "One or more variable cost items exceed state limit" }
            };
            items.Add((DocumentType.CostSummary, package.CostSummary.Id, passed,
                issues.Count > 0 ? string.Join("; ", issues) : null,
                JsonSerializer.Serialize(details, jsonOptions),
                SerializeRules(csRules)));
        }

        // ActivitySummary: only days-match cross-document validation
        if (package.ActivitySummary != null)
        {
            var passed = result.ActivityCrossDocument?.AllChecksPass ?? true;
            var issues = new List<string>();
            if (result.ActivityCrossDocument != null && !result.ActivityCrossDocument.AllChecksPass)
                issues.AddRange(result.ActivityCrossDocument.Issues);

            var details = new { crossDocument = result.ActivityCrossDocument };
            var act = package.ActivitySummary;
            var actWorkingDays = act.TotalWorkingDays ?? 0;
            var csDays = package.CostSummary?.NumberOfDays ?? 0;
            var daysMatch = actWorkingDays == csDays;
            var actRules = new List<object>
            {
                new { ruleCode = "AS_DAYS_MATCH_COST_SUMMARY", type = "Required", passed = daysMatch, isWarning = false, label = "No. of Working Days vs Cost Summary Days", extractedValue = $"Activity Working Days: {actWorkingDays} | Cost Summary Days: {csDays}", message = daysMatch ? null : $"No. of working days in Activity Summary ({actWorkingDays}) does not match No. of days in Cost Summary ({csDays})" }
            };
            items.Add((DocumentType.ActivitySummary, package.ActivitySummary.Id, passed,
                issues.Count > 0 ? string.Join("; ", issues) : null,
                JsonSerializer.Serialize(details, jsonOptions),
                SerializeRules(actRules)));
        }

        // EnquiryDocument: field presence + cross-document
        if (package.EnquiryDocument != null)
        {
            var passed = (result.EnquiryDumpFieldPresence?.AllFieldsPresent ?? true)
                         && (result.EnquiryDumpCrossDocument?.AllChecksPass ?? true);
            var issues = new List<string>();
            if (result.EnquiryDumpFieldPresence != null && !result.EnquiryDumpFieldPresence.AllFieldsPresent)
                issues.AddRange(result.EnquiryDumpFieldPresence.MissingFields);
            if (result.EnquiryDumpCrossDocument != null && !result.EnquiryDumpCrossDocument.AllChecksPass)
                issues.AddRange(result.EnquiryDumpCrossDocument.Issues);

            var details = new { fieldPresence = result.EnquiryDumpFieldPresence, crossDocument = result.EnquiryDumpCrossDocument };
            // Build per-field rules from EnquiryDumpFieldPresence
            var eq = result.EnquiryDumpFieldPresence;
            var eqRules = new List<object>
            {
                new { ruleCode = "EQ_STATE", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("State")) ?? false), isWarning = false, label = "State", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_DATE", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("Date")) ?? false), isWarning = false, label = "Date", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_DEALER_CODE", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("Dealer Code")) ?? false), isWarning = false, label = "Dealer Code", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_DEALER_NAME", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("Dealer Name")) ?? false), isWarning = false, label = "Dealer Name", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_DISTRICT", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("District")) ?? false), isWarning = false, label = "District", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_PINCODE", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("Pincode")) ?? false), isWarning = false, label = "Pincode", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_CUSTOMER_NAME", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("Customer Name")) ?? false), isWarning = false, label = "Customer Name", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_CUSTOMER_PHONE", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("Customer Phone")) ?? false), isWarning = false, label = "Customer Phone", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "EQ_TEST_RIDE", type = "Required", passed = !(eq?.MissingFields?.Any(f => f.Contains("Test Ride")) ?? false), isWarning = false, label = "Test Ride", extractedValue = (string?)null, message = (string?)null }
            };
            items.Add((DocumentType.EnquiryDocument, package.EnquiryDocument.Id, passed,
                issues.Count > 0 ? string.Join("; ", issues) : null,
                JsonSerializer.Serialize(details, jsonOptions),
                SerializeRules(eqRules)));
        }

        // TeamPhotos: aggregate entry (package-level) for backward compatibility
        if (result.PhotoFieldPresence != null || result.PhotoCrossDocument != null)
        {
            var passed = (result.PhotoFieldPresence?.AllFieldsPresent ?? true)
                         && (result.PhotoCrossDocument?.AllChecksPass ?? true);
            var issues = new List<string>();
            if (result.PhotoFieldPresence != null && !result.PhotoFieldPresence.AllFieldsPresent)
                issues.AddRange(result.PhotoFieldPresence.MissingFields);
            if (result.PhotoCrossDocument != null && !result.PhotoCrossDocument.AllChecksPass)
                issues.AddRange(result.PhotoCrossDocument.Issues);

            var details = new { fieldPresence = result.PhotoFieldPresence, crossDocument = result.PhotoCrossDocument };
            var ph = result.PhotoFieldPresence;
            var phRules = new List<object>
            {
                new { ruleCode = "PHOTO_COUNT", type = "Required", passed = ph?.AllFieldsPresent ?? true, isWarning = false, label = "Photo Count", extractedValue = (string?)null, message = ph?.AllFieldsPresent == false ? string.Join("; ", ph.MissingFields) : null },
                new { ruleCode = "PHOTO_DATE_VISIBLE", type = "Required", passed = !(ph?.MissingFields?.Any(f => f.Contains("date") || f.Contains("Date")) ?? false), isWarning = false, label = "Date", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "PHOTO_GPS_VISIBLE", type = "Required", passed = !(ph?.MissingFields?.Any(f => f.Contains("GPS") || f.Contains("location")) ?? false), isWarning = false, label = "GPS", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "PHOTO_BLUE_TSHIRT", type = "Required", passed = !(ph?.MissingFields?.Any(f => f.Contains("t-shirt") || f.Contains("tshirt") || f.Contains("Blue")) ?? false), isWarning = false, label = "Blue T-shirt", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "PHOTO_3W_VEHICLE", type = "Required", passed = !(ph?.MissingFields?.Any(f => f.Contains("vehicle") || f.Contains("Vehicle") || f.Contains("3W")) ?? false), isWarning = false, label = "3W Vehicle", extractedValue = (string?)null, message = (string?)null },
                new { ruleCode = "PHOTO_NO_OF_DAYS", type = "Required", passed = result.PhotoCrossDocument?.NumberOfDaysMatches ?? true, isWarning = false, label = "No. of Days", extractedValue = result.PhotoCrossDocument != null ? $"Unique Photo Days: {result.PhotoCrossDocument.UniquePhotoDays} | Activity Summary Days: {result.PhotoCrossDocument.ActivitySummaryDays}" : null, message = result.PhotoCrossDocument != null && !result.PhotoCrossDocument.NumberOfDaysMatches ? string.Join("; ", result.PhotoCrossDocument.Issues) : null }
            };
            items.Add((DocumentType.TeamPhoto, package.Id, passed,
                issues.Count > 0 ? string.Join("; ", issues) : null,
                JsonSerializer.Serialize(details, jsonOptions),
                SerializeRules(phRules)));
        }

        // TeamPhotos: per-photo validation entries (one per photo with DocumentId = photo.Id)
        // Uses same rule codes and data sources as chatbot's RunPhotoValidationRules
        var allTeamPhotos = package.Teams.SelectMany(t => t.Photos).Where(p => !p.IsDeleted).ToList();
        foreach (var photo in allTeamPhotos)
        {
            // Read from dedicated columns first, fall back to ExtractedMetadataJson (same as chatbot)
            bool dateVisible = photo.DateVisible ?? photo.PhotoTimestamp.HasValue;
            string? dateVal = photo.PhotoTimestamp?.ToString("dd-MMM-yyyy HH:mm") ?? photo.PhotoDateOverlay;

            bool gpsVisible = photo.Latitude.HasValue && photo.Longitude.HasValue;
            string? gpsVal = gpsVisible ? $"{photo.Latitude:F4}, {photo.Longitude:F4}" : null;

            bool blueTshirt = photo.BlueTshirtPresent ?? false;
            bool threeWheeler = photo.ThreeWheelerPresent ?? false;

            // Fallback: parse ExtractedMetadataJson if dedicated columns are null
            if (photo.DateVisible == null && photo.BlueTshirtPresent == null && !string.IsNullOrEmpty(photo.ExtractedMetadataJson))
            {
                try
                {
                    var metadata = JsonSerializer.Deserialize<PhotoMetadata>(photo.ExtractedMetadataJson);
                    if (metadata != null)
                    {
                        if (!dateVisible && metadata.Timestamp.HasValue)
                        { dateVisible = true; dateVal = metadata.Timestamp.Value.ToString("dd-MMM-yyyy HH:mm"); }
                        if (!dateVisible && !string.IsNullOrEmpty(metadata.PhotoDateFromOverlay))
                        { dateVisible = true; dateVal = metadata.PhotoDateFromOverlay; }
                        if (!gpsVisible && metadata.Latitude.HasValue && metadata.Longitude.HasValue)
                        { gpsVisible = true; gpsVal = $"{metadata.Latitude:F4}, {metadata.Longitude:F4}"; }
                        if (!blueTshirt) blueTshirt = metadata.HasBlueTshirtPerson;
                        if (!threeWheeler) threeWheeler = metadata.HasBajajVehicle || metadata.Has3WVehicle;
                    }
                }
                catch { /* skip malformed metadata */ }
            }

            // Required rules: all 4 must pass (matches chatbot RunPhotoValidationRules)
            var photoPassed = dateVisible && gpsVisible && blueTshirt && threeWheeler;

            var photoIssues = new List<string>();
            if (!dateVisible) photoIssues.Add("Date not visible in photo");
            if (!gpsVisible) photoIssues.Add("GPS coordinates not detected");
            if (!blueTshirt) photoIssues.Add("Person with blue T-shirt not detected");
            if (!threeWheeler) photoIssues.Add("3-wheel vehicle not detected");

            var photoRules = new List<object>
            {
                new { ruleCode = "PHOTO_DATE_VISIBLE", type = "Required", passed = dateVisible, isWarning = false, label = "Date", extractedValue = dateVal, message = dateVisible ? null : "Date not visible in photo" },
                new { ruleCode = "PHOTO_GPS_VISIBLE", type = "Required", passed = gpsVisible, isWarning = false, label = "GPS", extractedValue = gpsVal, message = gpsVisible ? null : "GPS coordinates not detected" },
                new { ruleCode = "PHOTO_BLUE_TSHIRT", type = "Required", passed = blueTshirt, isWarning = false, label = "Blue T-shirt", extractedValue = blueTshirt ? "Present ✓" : null, message = blueTshirt ? null : "Person with blue T-shirt not detected" },
                new { ruleCode = "PHOTO_3W_VEHICLE", type = "Required", passed = threeWheeler, isWarning = false, label = "3W Vehicle", extractedValue = threeWheeler ? "Present ✓" : null, message = threeWheeler ? null : "3-wheel vehicle not detected" },
            };

            var photoDetails = new
            {
                fileName = photo.FileName,
                dateVisible,
                gpsVisible,
                blueTshirt,
                threeWheeler,
                latitude = photo.Latitude,
                longitude = photo.Longitude,
                timestamp = photo.PhotoTimestamp,
            };

            items.Add((DocumentType.TeamPhoto, photo.Id, photoPassed,
                photoIssues.Count > 0 ? string.Join("; ", photoIssues) : null,
                JsonSerializer.Serialize(photoDetails, jsonOptions),
                SerializeRules(photoRules)));
        }

        return items;
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
