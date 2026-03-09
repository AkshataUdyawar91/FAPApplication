# Enhanced AI Validation Report - Design

## Architecture Overview

### Components

```
┌─────────────────────────────────────────────────────────────┐
│                     ASM Review Page (Flutter)                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         Enhanced Validation Report Widget             │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Quick Summary Card                             │  │  │
│  │  │  - Overall Confidence: 78%                      │  │  │
│  │  │  - Validations: 12 passed, 3 failed            │  │  │
│  │  │  - Recommendation: Request Resubmission         │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Validation Categories (Expandable)             │  │  │
│  │  │  ✅ PO Number Cross-Validation                  │  │  │
│  │  │  ✅ Invoice Amount Validation                   │  │  │
│  │  │  ✅ Team Photo Quality                          │  │  │
│  │  │  ❌ Branding Visibility                         │  │  │
│  │  │     └─ Details: Logo not visible in Photo #3   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Detailed Evidence Section                      │  │  │
│  │  │  - Document-by-document breakdown               │  │  │
│  │  │  - Specific data comparisons                    │  │  │
│  │  │  - Actionable recommendations                   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ API Call
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              SubmissionsController (.NET API)                │
│  GET /api/submissions/{id}/validation-report                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│          EnhancedValidationReportService (.NET)              │
│  - Aggregates validation results                             │
│  - Calculates validation-based confidence scores             │
│  - Generates detailed evidence with AI                       │
│  - Formats actionable recommendations                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Data Sources                                │
│  - ValidationResult (existing)                               │
│  - ConfidenceScore (existing)                                │
│  - Recommendation (existing)                                 │
│  - DocumentPackage with Documents                            │
└─────────────────────────────────────────────────────────────┘
```

## Data Models

### Enhanced Validation Report DTO

```csharp
public class EnhancedValidationReportDto
{
    // Quick Summary
    public ValidationSummaryDto Summary { get; set; }
    
    // Detailed Validation Results
    public List<ValidationCategoryDto> Categories { get; set; }
    
    // Confidence Score Breakdown
    public ConfidenceBreakdownDto ConfidenceBreakdown { get; set; }
    
    // AI Recommendation
    public RecommendationDto Recommendation { get; set; }
    
    // Detailed Evidence
    public string DetailedEvidence { get; set; }
}

public class ValidationSummaryDto
{
    public double OverallConfidence { get; set; }
    public int TotalValidations { get; set; }
    public int PassedValidations { get; set; }
    public int FailedValidations { get; set; }
    public int CriticalIssues { get; set; }
    public int HighPriorityIssues { get; set; }
    public int MediumPriorityIssues { get; set; }
    public string RecommendationType { get; set; } // Approve, Review, Reject
    public string RiskLevel { get; set; } // Low, Medium, High
}

public class ValidationCategoryDto
{
    public string CategoryName { get; set; }
    public string CategoryIcon { get; set; }
    public bool Passed { get; set; }
    public string Status { get; set; } // Passed, Failed, Warning
    public string Severity { get; set; } // Critical, High, Medium, Low
    public string ShortDescription { get; set; }
    public ValidationDetailDto? Details { get; set; }
}

public class ValidationDetailDto
{
    public string Title { get; set; }
    public string Description { get; set; }
    public string ExpectedValue { get; set; }
    public string ActualValue { get; set; }
    public string Impact { get; set; }
    public string SuggestedAction { get; set; }
    public List<string> AffectedDocuments { get; set; }
    public Dictionary<string, string> AdditionalData { get; set; }
}

public class ConfidenceBreakdownDto
{
    public double OverallConfidence { get; set; }
    public DocumentConfidenceDto POConfidence { get; set; }
    public DocumentConfidenceDto InvoiceConfidence { get; set; }
    public DocumentConfidenceDto CostSummaryConfidence { get; set; }
    public DocumentConfidenceDto ActivityConfidence { get; set; }
    public DocumentConfidenceDto PhotosConfidence { get; set; }
}

public class DocumentConfidenceDto
{
    public double Score { get; set; }
    public double Weight { get; set; }
    public int PassedChecks { get; set; }
    public int TotalChecks { get; set; }
    public List<string> PassedValidations { get; set; }
    public List<string> FailedValidations { get; set; }
}

public class RecommendationDto
{
    public string Type { get; set; } // Approve, RequestResubmission, Reject
    public string Summary { get; set; }
    public List<IssueDto> CriticalIssues { get; set; }
    public List<IssueDto> HighPriorityIssues { get; set; }
    public List<IssueDto> MediumPriorityIssues { get; set; }
    public List<string> PassedValidations { get; set; }
    public string RiskAssessment { get; set; }
    public string RecommendedAction { get; set; }
}

public class IssueDto
{
    public string Title { get; set; }
    public string Description { get; set; }
    public string ExpectedValue { get; set; }
    public string ActualValue { get; set; }
    public string Impact { get; set; }
    public string SuggestedResolution { get; set; }
    public string Severity { get; set; }
}
```

## Backend Implementation

### 1. EnhancedValidationReportService

```csharp
public interface IEnhancedValidationReportService
{
    Task<EnhancedValidationReportDto> GenerateReportAsync(
        Guid packageId, 
        CancellationToken cancellationToken = default);
}

public class EnhancedValidationReportService : IEnhancedValidationReportService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<EnhancedValidationReportService> _logger;
    private readonly Kernel _kernel; // Semantic Kernel for AI
    private readonly ICorrelationIdService _correlationIdService;

    public async Task<EnhancedValidationReportDto> GenerateReportAsync(
        Guid packageId, 
        CancellationToken cancellationToken = default)
    {
        // 1. Load all data
        var package = await LoadPackageWithAllDataAsync(packageId, cancellationToken);
        var validationResult = await LoadValidationResultAsync(packageId, cancellationToken);
        var confidenceScore = await LoadConfidenceScoreAsync(packageId, cancellationToken);
        var recommendation = await LoadRecommendationAsync(packageId, cancellationToken);

        // 2. Build validation categories
        var categories = BuildValidationCategories(package, validationResult);

        // 3. Calculate validation-based confidence
        var confidenceBreakdown = CalculateValidationBasedConfidence(
            package, validationResult, confidenceScore);

        // 4. Build summary
        var summary = BuildSummary(categories, confidenceBreakdown, recommendation);

        // 5. Generate detailed evidence with AI
        var detailedEvidence = await GenerateDetailedEvidenceAsync(
            package, validationResult, categories, cancellationToken);

        // 6. Build recommendation DTO
        var recommendationDto = BuildRecommendationDto(
            recommendation, categories, summary);

        return new EnhancedValidationReportDto
        {
            Summary = summary,
            Categories = categories,
            ConfidenceBreakdown = confidenceBreakdown,
            Recommendation = recommendationDto,
            DetailedEvidence = detailedEvidence
        };
    }

    private List<ValidationCategoryDto> BuildValidationCategories(
        DocumentPackage package, 
        ValidationResult validationResult)
    {
        var categories = new List<ValidationCategoryDto>();

        // 1. PO Number Cross-Validation
        categories.Add(BuildPONumberValidation(package, validationResult));

        // 2. Invoice Amount Validation
        categories.Add(BuildInvoiceAmountValidation(package, validationResult));

        // 3. Team Photo Quality
        categories.Add(BuildTeamPhotoValidation(package, validationResult));

        // 4. Branding Visibility
        categories.Add(BuildBrandingValidation(package, validationResult));

        // 5. Date Validation
        categories.Add(BuildDateValidation(package, validationResult));

        // 6. Vendor Matching
        categories.Add(BuildVendorValidation(package, validationResult));

        // 7. GST Validation
        categories.Add(BuildGSTValidation(package, validationResult));

        // 8. Campaign Duration
        categories.Add(BuildCampaignDurationValidation(package, validationResult));

        // 9. SAP Verification
        categories.Add(BuildSAPValidation(package, validationResult));

        // 10. Document Completeness
        categories.Add(BuildCompletenessValidation(package, validationResult));

        return categories;
    }

    private ValidationCategoryDto BuildPONumberValidation(
        DocumentPackage package, 
        ValidationResult validationResult)
    {
        var poDoc = package.Documents.FirstOrDefault(d => d.Type == DocumentType.PO);
        var invoiceDoc = package.Documents.FirstOrDefault(d => d.Type == DocumentType.Invoice);

        if (poDoc?.ExtractedDataJson == null || invoiceDoc?.ExtractedDataJson == null)
        {
            return new ValidationCategoryDto
            {
                CategoryName = "PO Number Cross-Validation",
                CategoryIcon = "description",
                Passed = false,
                Status = "Failed",
                Severity = "Critical",
                ShortDescription = "Missing PO or Invoice document"
            };
        }

        var poData = JsonSerializer.Deserialize<POData>(poDoc.ExtractedDataJson);
        var invoiceData = JsonSerializer.Deserialize<InvoiceData>(invoiceDoc.ExtractedDataJson);

        var poNumberMatch = poData?.PONumber?.Equals(
            invoiceData?.PONumber, 
            StringComparison.OrdinalIgnoreCase) ?? false;

        return new ValidationCategoryDto
        {
            CategoryName = "PO Number Cross-Validation",
            CategoryIcon = "check_circle",
            Passed = poNumberMatch,
            Status = poNumberMatch ? "Passed" : "Failed",
            Severity = poNumberMatch ? "Low" : "Critical",
            ShortDescription = poNumberMatch 
                ? "PO number matches between invoice and PO document"
                : "PO number mismatch detected",
            Details = poNumberMatch ? null : new ValidationDetailDto
            {
                Title = "PO Number Mismatch",
                Description = "The PO number referenced in the invoice does not match the PO document number.",
                ExpectedValue = $"PO Number: {poData?.PONumber}",
                ActualValue = $"Invoice references: {invoiceData?.PONumber}",
                Impact = "Critical - Documents do not match, possible fraud risk or data entry error",
                SuggestedAction = "Verify the correct PO number and request corrected invoice",
                AffectedDocuments = new List<string> { "Purchase Order", "Invoice" },
                AdditionalData = new Dictionary<string, string>
                {
                    { "PO Document Number", poData?.PONumber ?? "N/A" },
                    { "Invoice PO Reference", invoiceData?.PONumber ?? "N/A" }
                }
            }
        };
    }

    // Similar methods for other validation categories...

    private async Task<string> GenerateDetailedEvidenceAsync(
        DocumentPackage package,
        ValidationResult validationResult,
        List<ValidationCategoryDto> categories,
        CancellationToken cancellationToken)
    {
        var chatService = _kernel.GetRequiredService<IChatCompletionService>();

        var prompt = BuildEvidencePrompt(package, validationResult, categories);

        var chatHistory = new ChatHistory();
        chatHistory.AddSystemMessage(@"You are an AI assistant helping Area Sales Managers review document submissions.
Generate a clear, professional validation report with specific evidence and actionable recommendations.

Format the response as:
1. Executive Summary (2-3 sentences)
2. Critical Issues (if any) with specific data
3. Passed Validations (brief list)
4. Recommendations with reasoning

Be specific, factual, and actionable. Use actual data from the documents.");

        chatHistory.AddUserMessage(prompt);

        var response = await chatService.GetChatMessageContentAsync(
            chatHistory,
            cancellationToken: cancellationToken);

        return response.Content ?? "Evidence generation failed";
    }

    private string BuildEvidencePrompt(
        DocumentPackage package,
        ValidationResult validationResult,
        List<ValidationCategoryDto> categories)
    {
        var sb = new StringBuilder();
        sb.AppendLine("Generate a detailed validation report for this document package:");
        sb.AppendLine();
        sb.AppendLine($"Package ID: {package.Id}");
        sb.AppendLine($"Submitted by: {package.AgencyName}");
        sb.AppendLine($"Submission Date: {package.CreatedAt:yyyy-MM-dd}");
        sb.AppendLine();

        sb.AppendLine("Validation Results:");
        foreach (var category in categories)
        {
            sb.AppendLine($"- {category.CategoryName}: {category.Status}");
            if (category.Details != null)
            {
                sb.AppendLine($"  Expected: {category.Details.ExpectedValue}");
                sb.AppendLine($"  Actual: {category.Details.ActualValue}");
                sb.AppendLine($"  Impact: {category.Details.Impact}");
            }
        }

        sb.AppendLine();
        sb.AppendLine("Generate a professional report with specific recommendations.");

        return sb.ToString();
    }
}
```

### 2. API Endpoint

```csharp
// SubmissionsController.cs

[HttpGet("{id}/validation-report")]
[Authorize(Roles = "ASM,HQ")]
public async Task<ActionResult<EnhancedValidationReportDto>> GetValidationReport(
    Guid id,
    CancellationToken cancellationToken)
{
    try
    {
        var report = await _enhancedValidationReportService.GenerateReportAsync(
            id, cancellationToken);
        
        return Ok(report);
    }
    catch (NotFoundException ex)
    {
        return NotFound(new { message = ex.Message });
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error generating validation report for package {PackageId}", id);
        return StatusCode(500, new { message = "Error generating validation report" });
    }
}
```

## Frontend Implementation

### 1. Enhanced Validation Report Widget

```dart
// enhanced_validation_report_widget.dart

class EnhancedValidationReportWidget extends StatelessWidget {
  final EnhancedValidationReport report;

  const EnhancedValidationReportWidget({
    Key? key,
    required this.report,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Summary Card
        _buildSummaryCard(),
        
        const SizedBox(height: 16),
        
        // Validation Categories
        _buildValidationCategories(),
        
        const SizedBox(height: 16),
        
        // Confidence Breakdown
        _buildConfidenceBreakdown(),
        
        const SizedBox(height: 16),
        
        // Detailed Evidence
        _buildDetailedEvidence(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getRecommendationIcon(),
                  color: _getRecommendationColor(),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Validation Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Overall Confidence: ${report.summary.overallConfidence.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildRecommendationBadge(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Total',
                  report.summary.totalValidations.toString(),
                  Colors.blue,
                ),
                _buildStatItem(
                  'Passed',
                  report.summary.passedValidations.toString(),
                  Colors.green,
                ),
                _buildStatItem(
                  'Failed',
                  report.summary.failedValidations.toString(),
                  Colors.red,
                ),
                _buildStatItem(
                  'Critical',
                  report.summary.criticalIssues.toString(),
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationCategories() {
    return Card(
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          'Validation Results',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        initiallyExpanded: true,
        children: report.categories.map((category) {
          return _buildValidationCategoryItem(category);
        }).toList(),
      ),
    );
  }

  Widget _buildValidationCategoryItem(ValidationCategory category) {
    final hasDetails = category.details != null;
    
    return ListTile(
      leading: Icon(
        category.passed ? Icons.check_circle : Icons.cancel,
        color: category.passed ? Colors.green : Colors.red,
      ),
      title: Text(category.categoryName),
      subtitle: Text(category.shortDescription),
      trailing: hasDetails
          ? Icon(Icons.info_outline, color: Colors.blue)
          : null,
      onTap: hasDetails
          ? () => _showValidationDetails(context, category)
          : null,
    );
  }

  void _showValidationDetails(BuildContext context, ValidationCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category.details!.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(category.details!.description),
              const SizedBox(height: 16),
              _buildDetailRow('Expected', category.details!.expectedValue),
              _buildDetailRow('Actual', category.details!.actualValue),
              const SizedBox(height: 16),
              Text(
                'Impact:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(category.details!.impact),
              const SizedBox(height: 16),
              Text(
                'Suggested Action:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(category.details!.suggestedAction),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

## AI Prompt Templates

### Evidence Generation Prompt

```
You are an AI assistant helping Area Sales Managers review document submissions for Bajaj Auto Limited.

Generate a professional validation report based on the following data:

PACKAGE INFORMATION:
- Package ID: {packageId}
- Agency: {agencyName}
- Submission Date: {submissionDate}
- Campaign: {campaignDetails}

VALIDATION RESULTS:
{validationResults}

CONFIDENCE SCORES:
- Overall: {overallConfidence}%
- PO: {poConfidence}%
- Invoice: {invoiceConfidence}%
- Cost Summary: {costSummaryConfidence}%
- Activity: {activityConfidence}%
- Photos: {photosConfidence}%

REQUIREMENTS:
1. Start with a 2-3 sentence executive summary
2. List all critical issues with specific data (Expected vs Actual)
3. Briefly mention passed validations
4. Provide clear, actionable recommendations
5. Include risk assessment (Low/Medium/High)

FORMAT:
Use clear headings, bullet points, and specific data.
Be professional, factual, and helpful.
Focus on actionable insights for the ASM.
```

## Database Changes

No new tables required. Enhanced report is generated on-demand from existing data:
- ValidationResult
- ConfidenceScore
- Recommendation
- DocumentPackage
- Documents

## Performance Considerations

1. **Caching:** Cache validation reports for 5 minutes
2. **Lazy Loading:** Load detailed evidence only when expanded
3. **Parallel Processing:** Calculate validation categories in parallel
4. **AI Timeout:** Set 10-second timeout for AI evidence generation
5. **Fallback:** Use template-based evidence if AI fails

## Security Considerations

1. **Authorization:** Only ASM and HQ roles can access validation reports
2. **Data Sanitization:** Sanitize all user-generated content in evidence
3. **Rate Limiting:** Limit AI evidence generation to prevent abuse
4. **Audit Logging:** Log all validation report accesses

## Testing Strategy

### Unit Tests
- Test each validation category builder
- Test confidence calculation logic
- Test evidence prompt generation
- Test DTO mapping

### Integration Tests
- Test end-to-end report generation
- Test AI evidence generation with mock responses
- Test API endpoint with various scenarios

### UI Tests
- Test report widget rendering
- Test expandable sections
- Test detail dialogs
- Test responsive layout

## Rollout Plan

### Phase 1: Backend (Week 1)
- Implement EnhancedValidationReportService
- Add API endpoint
- Unit tests

### Phase 2: Frontend (Week 2)
- Implement validation report widget
- Integrate with ASM review page
- UI tests

### Phase 3: AI Enhancement (Week 3)
- Implement AI evidence generation
- Fine-tune prompts
- Add fallback logic

### Phase 4: Testing & Refinement (Week 4)
- End-to-end testing
- Performance optimization
- User acceptance testing
