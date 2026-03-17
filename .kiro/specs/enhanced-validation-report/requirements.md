# Enhanced AI Validation Report - Requirements

## Problem Statement

The current AI Validation Report shows basic validation results (pass/fail) but lacks:
1. **Detailed explanations** of why validations failed
2. **Specific data comparisons** (expected vs actual values)
3. **Actionable insights** for ASMs to make informed decisions
4. **Clear confidence score breakdown** with validation-based scoring
5. **Risk assessment** and impact analysis

ASMs need to understand:
- **What** failed validation
- **Why** it failed (with specific data)
- **How critical** the issue is
- **What action** they should take

## User Stories

### US-1: Detailed Validation Results
**As an** ASM  
**I want to** see detailed validation results with specific data comparisons  
**So that** I can understand exactly what failed and why

**Acceptance Criteria:**
- Each validation check shows pass/fail status
- Failed checks display:
  - Expected value vs Actual value
  - Specific field names and document sources
  - Severity level (Critical, High, Medium, Low)
  - Impact on approval decision
- Passed checks show confirmation with key data points

### US-2: Enhanced Confidence Score Display
**As an** ASM  
**I want to** see confidence scores based on validation results, not just extraction quality  
**So that** I can trust the AI recommendation

**Acceptance Criteria:**
- Overall confidence score reflects validation pass rate
- Individual validation categories show confidence percentages
- Confidence calculation formula is transparent
- Low confidence items are highlighted with explanations

### US-3: Actionable Recommendations
**As an** ASM  
**I want to** receive specific, actionable recommendations  
**So that** I know exactly what to do with the submission

**Acceptance Criteria:**
- Recommendation includes:
  - Clear action (Approve / Request Resubmission / Reject)
  - Specific reasons with evidence
  - List of issues to address (if resubmission needed)
  - Risk assessment (Low / Medium / High)
- Evidence includes:
  - Document-specific findings
  - Cross-validation results
  - Compliance check results
  - Photo validation results

### US-4: Visual Validation Summary
**As an** ASM  
**I want to** see a visual summary of validation results  
**So that** I can quickly assess the submission quality

**Acceptance Criteria:**
- Color-coded validation categories (green/yellow/red)
- Progress indicators for each validation type
- Quick summary cards showing:
  - Total validations: X passed, Y failed
  - Critical issues count
  - Confidence score with visual indicator
  - Recommendation with reasoning

### US-5: Detailed Issue Breakdown
**As an** ASM  
**I want to** see a detailed breakdown of each validation issue  
**So that** I can provide specific feedback to agencies

**Acceptance Criteria:**
- Issues grouped by category:
  - Document Completeness
  - Cross-Document Validation
  - SAP Verification
  - Amount Validation
  - Date Validation
  - Photo Quality
- Each issue shows:
  - Issue title
  - Description with specific data
  - Affected documents
  - Suggested resolution
  - Severity level

## Validation Categories

### 1. PO Number Cross-Validation
**Check:** PO number matches between Invoice and PO document  
**Evidence:**
- PO Number from Invoice: [value]
- PO Number from PO Document: [value]
- Status: Match / Mismatch
- Impact: Critical (blocks approval if mismatch)

### 2. Invoice Amount Validation
**Check:** Invoice amount is within PO limit  
**Evidence:**
- Invoice Amount: ₹[value]
- PO Amount: ₹[value]
- Difference: ₹[value] ([percentage]%)
- Status: Within limit / Exceeds limit
- Impact: Critical (blocks approval if exceeds)

### 3. Team Photo Quality
**Check:** Photos show clear faces of team members  
**Evidence:**
- Total photos: [count]
- Photos with clear faces: [count]
- Photos with team members detected: [count]
- Status: Acceptable / Poor quality
- Impact: Medium (may require resubmission)

### 4. Branding Visibility
**Check:** Bajaj logo clearly visible in stage photos  
**Evidence:**
- Total stage photos: [count]
- Photos with Bajaj logo detected: [count]
- Logo visibility score: [percentage]%
- Specific issues: "Logo not visible in Photo #3, Photo #5"
- Status: Acceptable / Not visible
- Impact: High (brand compliance requirement)

### 5. Date Validation
**Check:** Invoice date is between PO date and submission date  
**Evidence:**
- PO Date: [date]
- Invoice Date: [date]
- Submission Date: [date]
- Status: Valid / Invalid
- Issue: "Invoice date is before PO date" (if applicable)
- Impact: Critical

### 6. Vendor Matching
**Check:** Vendor name consistent across documents  
**Evidence:**
- Vendor from PO: [name]
- Vendor from Invoice: [name]
- Vendor from SAP: [name]
- Status: Match / Mismatch
- Impact: Medium

### 7. GST Validation
**Check:** GST number matches state code  
**Evidence:**
- GST Number: [value]
- State Code from GST: [code]
- State Code from Invoice: [code]
- Status: Valid / Invalid
- Impact: High (compliance requirement)

### 8. Campaign Duration
**Check:** Campaign dates and working days are valid  
**Evidence:**
- Start Date: [date]
- End Date: [date]
- Working Days: [count]
- Calculated Working Days: [count]
- Status: Match / Mismatch
- Impact: Medium

## Confidence Score Calculation (Enhanced)

### Current Formula (Extraction-based):
- PO: 30%
- Invoice: 30%
- Cost Summary: 20%
- Activity: 10%
- Photos: 10%

### Enhanced Formula (Validation-based):
```
Overall Confidence = (
  (PO Validation Score × 0.30) +
  (Invoice Validation Score × 0.30) +
  (Cost Summary Validation Score × 0.20) +
  (Activity Validation Score × 0.10) +
  (Photo Validation Score × 0.10)
)

Where each Validation Score = (Passed Checks / Total Checks) × 100
```

### Validation Score Components:

**PO Validation Score:**
- SAP verification: 40%
- Field completeness: 30%
- Data quality: 30%

**Invoice Validation Score:**
- PO number match: 25%
- Amount validation: 25%
- GST validation: 20%
- Field completeness: 15%
- Vendor match: 15%

**Cost Summary Validation Score:**
- Amount consistency: 40%
- Element-wise validation: 30%
- Field completeness: 30%

**Activity Validation Score:**
- Field completeness: 50%
- Cross-document consistency: 50%

**Photo Validation Score:**
- Team photo quality: 30%
- Branding visibility: 30%
- Metadata presence: 20%
- Photo count: 20%

## Recommendation Logic (Enhanced)

### Approve (Confidence >= 85%)
**Conditions:**
- All critical validations passed
- No high-severity issues
- Confidence score >= 85%

**Evidence Format:**
```
✅ RECOMMENDATION: APPROVE

Confidence Score: 92%

All Critical Validations Passed:
✅ PO Number matches across documents
✅ Invoice amount within PO limit (₹45,000 / ₹50,000)
✅ SAP verification successful
✅ All required documents present
✅ Dates are valid

Minor Observations:
⚠️ Vendor name has slight variation (acceptable)
   - PO: "ABC Marketing Pvt Ltd"
   - Invoice: "ABC Marketing Private Limited"

Risk Assessment: LOW
Recommended Action: APPROVE
```

### Request Resubmission (Confidence 70-85%)
**Conditions:**
- Some medium/high severity issues
- No critical blockers
- Confidence score 70-85%

**Evidence Format:**
```
⚠️ RECOMMENDATION: REQUEST RESUBMISSION

Confidence Score: 78%

Issues Requiring Attention:

🔴 HIGH PRIORITY:
1. Branding Visibility Issue
   - Bajaj logo not clearly visible in Stage Photo #3
   - Required: Clear logo visibility in all stage photos
   - Action: Request clearer photo of stage setup

2. Team Photo Quality
   - Only 3 out of 5 photos show clear team member faces
   - Required: At least 4 photos with clear faces
   - Action: Request additional clear team photos

✅ Passed Validations:
- PO Number matches
- Invoice amount within limit
- SAP verification successful
- Dates are valid

Risk Assessment: MEDIUM
Recommended Action: REQUEST RESUBMISSION with specific feedback
```

### Reject (Confidence < 70%)
**Conditions:**
- Critical validation failures
- Multiple high-severity issues
- Confidence score < 70%

**Evidence Format:**
```
❌ RECOMMENDATION: REJECT

Confidence Score: 62%

Critical Issues (Must be resolved):

🔴 CRITICAL:
1. PO Number Mismatch
   - PO Number in Invoice: "PO-2024-001"
   - PO Number in PO Document: "PO-2024-002"
   - Impact: Documents do not match - possible fraud risk
   - Action: REJECT and investigate

2. Invoice Amount Exceeds PO Limit
   - Invoice Amount: ₹55,000
   - PO Amount: ₹50,000
   - Excess: ₹5,000 (10% over limit)
   - Impact: Unauthorized expenditure
   - Action: REJECT - exceeds approved budget

3. Invalid Invoice Date
   - Invoice Date: 2024-01-15
   - PO Date: 2024-01-20
   - Issue: Invoice dated before PO creation
   - Impact: Timeline inconsistency
   - Action: REJECT - invalid documentation

Additional Issues:
⚠️ Branding visibility poor
⚠️ Missing activity summary details

Risk Assessment: HIGH
Recommended Action: REJECT with detailed feedback
```

## Non-Functional Requirements

### NFR-1: Performance
- Validation report generation: < 2 seconds
- AI evidence generation: < 5 seconds
- Report rendering in UI: < 1 second

### NFR-2: Accuracy
- Validation checks: 100% accurate based on business rules
- AI evidence: Factually correct, no hallucinations
- Data comparisons: Exact values from source documents

### NFR-3: Usability
- Report is easy to read and understand
- Visual hierarchy guides attention to critical issues
- Actions are clear and specific
- Technical jargon is minimized

### NFR-4: Maintainability
- Validation rules are configurable
- Evidence templates are reusable
- New validation checks can be added easily

## Out of Scope

- Real-time validation during document upload
- Automated approval without ASM review
- Integration with external compliance systems
- Historical trend analysis of validation patterns

## Success Metrics

1. **ASM Decision Time:** Reduce from 10 minutes to 3 minutes per submission
2. **Resubmission Clarity:** 90% of agencies understand what to fix on first attempt
3. **Approval Accuracy:** 95% of AI recommendations align with ASM final decisions
4. **User Satisfaction:** ASMs rate the validation report 4.5/5 or higher
