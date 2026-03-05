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
    private readonly IReferenceDataService _referenceDataService;
    private readonly AsyncCircuitBreakerPolicy _circuitBreakerPolicy;
    private readonly IAsyncPolicy _retryPolicy;

    public ValidationAgent(
        IApplicationDbContext context,
        ILogger<ValidationAgent> logger,
        IHttpClientFactory httpClientFactory,
        IReferenceDataService referenceDataService)
    {
        _context = context;
        _logger = logger;
        _sapHttpClient = httpClientFactory.CreateClient("SAP");
        _referenceDataService = referenceDataService;

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
            var activityDoc = package.Documents.FirstOrDefault(d => d.Type == DocumentType.Activity);

            POData? poData = null;
            InvoiceData? invoiceData = null;
            CostSummaryData? costSummaryData = null;
            ActivityData? activityData = null;

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

            if (activityDoc?.ExtractedDataJson != null)
            {
                activityData = JsonSerializer.Deserialize<ActivityData>(activityDoc.ExtractedDataJson);
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
                result.InvoiceCrossDocument = ValidateInvoiceCrossDocument(invoiceData, poData);
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
            var photoDocuments = package.Documents.Where(d => d.Type == DocumentType.Photo).ToList();
            if (photoDocuments.Any())
            {
                result.PhotoFieldPresence = ValidatePhotoFieldPresence(photoDocuments);
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
            if (photoDocuments.Any())
            {
                result.PhotoCrossDocument = ValidatePhotoCrossDocument(
                    photoDocuments.Count,
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
                              (result.PhotoCrossDocument == null || result.PhotoCrossDocument.AllChecksPass);
                              (result.DateValidation == null || result.DateValidation.IsValid);
            
            // Note: AmountConsistency, LineItemMatching, and VendorMatching are informational only

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
    /// Validates invoice field presence (all required fields must exist)
    /// </summary>
    private InvoiceFieldPresenceResult ValidateInvoiceFieldPresence(InvoiceData invoiceData)
    {
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

        return result;
    }

    /// <summary>
    /// Validates invoice cross-document fields against PO
    /// </summary>
    private InvoiceCrossDocumentResult ValidateInvoiceCrossDocument(InvoiceData invoiceData, POData poData)
    {
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

        // 6. GST Percentage validation (should match default 18% or state-specific rate)
        var expectedGSTPercentage = _referenceDataService.GetDefaultGSTPercentage(invoiceData.StateCode);
        result.GSTPercentageValid = Math.Abs(invoiceData.GSTPercentage - expectedGSTPercentage) < 0.01m;
        if (!result.GSTPercentageValid)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"GST Percentage mismatch: Invoice has {invoiceData.GSTPercentage}%, expected {expectedGSTPercentage}%");
        }

        return result;
    }

    private CostSummaryFieldPresenceResult ValidateCostSummaryFieldPresence(CostSummaryData costSummaryData)
    {
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

        // 5. Total Cost - Required
        if (costSummaryData.TotalCost <= 0)
        {
            missingFields.Add("Total Cost");
        }

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        return result;
    }

    private CostSummaryCrossDocumentResult ValidateCostSummaryCrossDocument(
        CostSummaryData costSummaryData, 
        InvoiceData invoiceData)
    {
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

        return result;
    }

    private ActivityFieldPresenceResult ValidateActivityFieldPresence(ActivityData activityData)
    {
        var result = new ActivityFieldPresenceResult { AllFieldsPresent = true };
        var missingFields = new List<string>();

        // 1. Dealer and Location details - Required
        if (string.IsNullOrWhiteSpace(activityData.DealerName) && 
            string.IsNullOrWhiteSpace(activityData.DealerCode))
        {
            missingFields.Add("Dealer Name/Code");
        }

        if (activityData.LocationActivities == null || !activityData.LocationActivities.Any())
        {
            missingFields.Add("Location Activities");
        }
        else
        {
            // Check if location activities have required details
            var locationsWithoutDetails = activityData.LocationActivities
                .Where(la => string.IsNullOrWhiteSpace(la.LocationName))
                .Count();

            if (locationsWithoutDetails > 0)
            {
                missingFields.Add($"Location details missing for {locationsWithoutDetails} location(s)");
            }
        }

        // Note: "No of days in each Location" is marked as "N" (not required for implementation)
        // but we'll validate it exists for completeness
        if (activityData.LocationActivities != null && activityData.LocationActivities.Any())
        {
            var locationsWithoutDays = activityData.LocationActivities
                .Where(la => la.NumberOfDays <= 0)
                .Count();

            if (locationsWithoutDays == activityData.LocationActivities.Count)
            {
                // All locations are missing days - this is an issue
                missingFields.Add("Number of days in locations");
            }
        }

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        return result;
    }

    private ActivityCrossDocumentResult ValidateActivityCrossDocument(
        ActivityData activityData,
        CostSummaryData costSummaryData)
    {
        var result = new ActivityCrossDocumentResult { AllChecksPass = true };

        // Calculate total days from activity data
        var activityTotalDays = activityData.TotalDays ?? 
            (activityData.LocationActivities?.Sum(la => la.NumberOfDays) ?? 0);

        var costSummaryDays = costSummaryData.NumberOfDays ?? 0;

        // Validate: Number of days must match between Activity and Cost Summary
        result.NumberOfDaysMatches = activityTotalDays == costSummaryDays;

        if (!result.NumberOfDaysMatches)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"Number of days mismatch: Activity Summary has {activityTotalDays} days, Cost Summary has {costSummaryDays} days");
        }

        return result;
    }

    private PhotoFieldPresenceResult ValidatePhotoFieldPresence(List<Domain.Entities.Document> photoDocuments)
    {
        var result = new PhotoFieldPresenceResult 
        { 
            AllFieldsPresent = true,
            TotalPhotos = photoDocuments.Count
        };
        var missingFields = new List<string>();

        if (!photoDocuments.Any())
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

        foreach (var photoDoc in photoDocuments)
        {
            if (photoDoc.ExtractedDataJson != null)
            {
                var photoMetadata = JsonSerializer.Deserialize<PhotoMetadata>(photoDoc.ExtractedDataJson);
                
                if (photoMetadata != null)
                {
                    // Check for date/timestamp
                    if (photoMetadata.Timestamp.HasValue)
                    {
                        photosWithDate++;
                    }

                    // Check for location (lat/long)
                    if (photoMetadata.Latitude.HasValue && photoMetadata.Longitude.HasValue)
                    {
                        photosWithLocation++;
                    }

                    // Check for blue t-shirt person (AI-detected)
                    if (photoMetadata.HasBlueTshirtPerson)
                    {
                        photosWithBlueTshirt++;
                    }

                    // Check for Bajaj vehicle (AI-detected)
                    if (photoMetadata.HasBajajVehicle)
                    {
                        photosWithVehicle++;
                    }
                }
            }
        }

        result.PhotosWithDate = photosWithDate;
        result.PhotosWithLocation = photosWithLocation;
        result.PhotosWithBlueTshirt = photosWithBlueTshirt;
        result.PhotosWithVehicle = photosWithVehicle;

        // Validate: Date should be present on all photos
        if (photosWithDate < photoDocuments.Count)
        {
            missingFields.Add($"Date present on {photosWithDate} out of {photoDocuments.Count} photos");
        }

        // Validate: Location should be present on all photos
        if (photosWithLocation < photoDocuments.Count)
        {
            missingFields.Add($"Location coordinates present on {photosWithLocation} out of {photoDocuments.Count} photos");
        }

        // Note: Blue t-shirt and vehicle are content validations (AI-based)
        // These are informational but not blocking validations
        if (photosWithBlueTshirt == 0)
        {
            missingFields.Add("No photos with person in blue t-shirt detected (AI validation)");
        }

        if (photosWithVehicle == 0)
        {
            missingFields.Add("No photos with Bajaj vehicle detected (AI validation)");
        }

        result.MissingFields = missingFields;
        result.AllFieldsPresent = missingFields.Count == 0;

        return result;
    }

    private PhotoCrossDocumentResult ValidatePhotoCrossDocument(
        int photoCount,
        ActivityData? activityData,
        CostSummaryData? costSummaryData)
    {
        var result = new PhotoCrossDocumentResult 
        { 
            AllChecksPass = true,
            PhotoCount = photoCount
        };

        // Calculate man-days from activity data
        int manDays = 0;
        if (activityData?.LocationActivities != null && activityData.LocationActivities.Any())
        {
            manDays = activityData.LocationActivities.Sum(la => la.NumberOfDays);
        }
        else if (activityData?.TotalDays.HasValue == true)
        {
            manDays = activityData.TotalDays.Value;
        }

        result.ManDays = manDays;

        // Get cost summary days
        int costSummaryDays = costSummaryData?.NumberOfDays ?? 0;
        result.CostSummaryDays = costSummaryDays;

        // Validation 1: Number of photos should match number of man-days in Activity Summary
        result.PhotoCountMatchesManDays = photoCount == manDays;
        if (!result.PhotoCountMatchesManDays && manDays > 0)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"Photo count ({photoCount}) does not match man-days in Activity Summary ({manDays})");
        }

        // Validation 2: Man-days in Activity Summary should be ≤ days in Cost Summary
        result.ManDaysWithinCostSummaryDays = manDays <= costSummaryDays;
        if (!result.ManDaysWithinCostSummaryDays && costSummaryDays > 0)
        {
            result.AllChecksPass = false;
            result.Issues.Add($"Man-days in Activity Summary ({manDays}) exceeds days in Cost Summary ({costSummaryDays})");
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
                InvoiceFieldPresence = result.InvoiceFieldPresence,
                InvoiceCrossDocument = result.InvoiceCrossDocument,
                CostSummaryFieldPresence = result.CostSummaryFieldPresence,
                CostSummaryCrossDocument = result.CostSummaryCrossDocument,
                ActivityFieldPresence = result.ActivityFieldPresence,
                ActivityCrossDocument = result.ActivityCrossDocument,
                PhotoFieldPresence = result.PhotoFieldPresence,
                PhotoCrossDocument = result.PhotoCrossDocument,
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
