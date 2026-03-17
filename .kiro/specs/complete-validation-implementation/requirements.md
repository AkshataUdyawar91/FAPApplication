# Requirements Document

## Introduction

This specification defines the requirements for implementing 14 missing validation checks in the Bajaj Document Processing System. The system currently implements 46 validations but lacks critical backend rate validations, field presence checks, and 3-way cross-document validations identified in the business requirements document. These missing validations are essential for ensuring data integrity, compliance with state-specific rates, and consistency across the Purchase Order, Invoice, Cost Summary, Activity Summary, and Photo Proof documents.

## Glossary

- **Validation_Agent**: The service responsible for performing all document validation checks
- **Reference_Data_Service**: The service that provides access to backend reference data including state rates, GST mappings, and HSN/SAC codes
- **Invoice_Document**: The invoice document containing billing information, line items, and tax details
- **Cost_Summary_Document**: The cost summary document containing campaign costs broken down by elements
- **Activity_Document**: The activity summary document containing location-based activity details and man-days
- **Photo_Document**: Photo proof documents with metadata (date, location, blue t-shirt, vehicle)
- **PO_Document**: Purchase Order document containing line items and vendor information
- **Backend_Rate**: State-specific cost rates stored in the reference data system
- **State_Code**: Two-character code representing an Indian state (e.g., "MH" for Maharashtra)
- **GST_Number**: 15-character Goods and Services Tax identification number where first 2 digits represent state code
- **HSN_SAC_Code**: Harmonized System of Nomenclature or Services Accounting Code for tax classification
- **Element_Cost**: Individual cost item in the Cost Summary (e.g., "BA Salary", "Vehicle Rent")
- **Fixed_Cost**: Cost that remains constant regardless of activity volume
- **Variable_Cost**: Cost that varies with activity volume
- **Man_Days**: Total person-days of work calculated from activity data
- **3_Way_Validation**: Cross-validation across three documents (Photos, Activity, Cost Summary)

## Requirements

### Requirement 1: Invoice PO Number Field Presence

**User Story:** As an ASM, I want the system to verify that the Invoice contains a PO Number field, so that I can ensure proper cross-referencing between documents.

#### Acceptance Criteria

1. WHEN an Invoice_Document is validated, THE Validation_Agent SHALL check if the PONumber field is present
2. WHEN the PONumber field is empty or null, THE Validation_Agent SHALL add "PO Number" to the missing fields list
3. WHEN the PONumber field is present and non-empty, THE Validation_Agent SHALL mark this check as passed
4. THE Validation_Agent SHALL include this check result in the InvoiceFieldPresenceResult

### Requirement 2: Invoice GST Number State Backend Validation

**User Story:** As an ASM, I want the system to validate that the GST Number matches the State Code using backend reference data, so that I can detect tax registration inconsistencies.

#### Acceptance Criteria

1. WHEN an Invoice_Document is validated, THE Validation_Agent SHALL extract the first 2 digits from the GSTNumber field
2. WHEN the GST state code is extracted, THE Validation_Agent SHALL call Reference_Data_Service to validate against the StateCode field
3. IF the GST state code does not match the StateCode, THEN THE Validation_Agent SHALL add an issue to InvoiceCrossDocumentResult with details of the mismatch
4. WHEN the GST state code matches the StateCode, THE Validation_Agent SHALL mark the GSTStateMatches flag as true
5. THE Validation_Agent SHALL handle invalid GST_Number formats by treating them as validation failures

### Requirement 3: Invoice HSN/SAC Code Backend Validation

**User Story:** As an ASM, I want the system to validate HSN/SAC codes against the backend reference database, so that I can ensure correct tax classification.

#### Acceptance Criteria

1. WHEN an Invoice_Document is validated, THE Validation_Agent SHALL call Reference_Data_Service to validate the HSNSACCode field
2. WHEN the HSNSACCode exists in the reference data, THE Validation_Agent SHALL mark the HSNSACCodeValid flag as true
3. IF the HSNSACCode does not exist in the reference data, THEN THE Validation_Agent SHALL add an issue to InvoiceCrossDocumentResult indicating invalid code
4. WHEN the HSNSACCode field is empty, THE Validation_Agent SHALL treat it as a validation failure

### Requirement 4: Invoice Amount vs PO Amount Validation

**User Story:** As an ASM, I want the system to verify that the Invoice amount is equal to or less than the PO amount, so that I can prevent overbilling.

#### Acceptance Criteria

1. WHEN an Invoice_Document and PO_Document are validated together, THE Validation_Agent SHALL compare the Invoice TotalAmount with the PO TotalAmount
2. WHEN the Invoice TotalAmount is less than or equal to the PO TotalAmount, THE Validation_Agent SHALL mark the InvoiceAmountValid flag as true
3. IF the Invoice TotalAmount exceeds the PO TotalAmount, THEN THE Validation_Agent SHALL add an issue to InvoiceCrossDocumentResult with both amounts
4. THE Validation_Agent SHALL include the difference amount in the validation issue when amounts are invalid

### Requirement 5: Invoice GST Percentage State Validation

**User Story:** As an ASM, I want the system to validate that the GST percentage matches the state's default rate, so that I can detect incorrect tax calculations.

#### Acceptance Criteria

1. WHEN an Invoice_Document is validated, THE Validation_Agent SHALL call Reference_Data_Service to get the default GST percentage for the StateCode
2. WHEN the Invoice GSTPercentage matches the default rate, THE Validation_Agent SHALL mark the GSTPercentageValid flag as true
3. IF the Invoice GSTPercentage does not match the default rate, THEN THE Validation_Agent SHALL add an issue to InvoiceCrossDocumentResult with expected and actual values
4. THE Validation_Agent SHALL use 18% as the default GST percentage when state-specific rate is not available

### Requirement 6: Cost Summary Element-wise Cost Field Presence

**User Story:** As an ASM, I want the system to verify that all cost elements have an Amount field, so that I can ensure complete cost data.

#### Acceptance Criteria

1. WHEN a Cost_Summary_Document is validated, THE Validation_Agent SHALL iterate through all CostBreakdowns
2. WHEN any CostBreakdown has an Amount of zero or negative value, THE Validation_Agent SHALL add the ElementName to the missing fields list
3. WHEN all CostBreakdowns have positive Amount values, THE Validation_Agent SHALL mark this check as passed
4. THE Validation_Agent SHALL include element names in the validation error message for missing costs

### Requirement 7: Cost Summary Number of Days Field Presence

**User Story:** As an ASM, I want the system to verify that the Cost Summary contains a Number of Days field, so that I can validate campaign duration.

#### Acceptance Criteria

1. WHEN a Cost_Summary_Document is validated, THE Validation_Agent SHALL check if the NumberOfDays field is present
2. WHEN the NumberOfDays field is null or zero, THE Validation_Agent SHALL add "Number of Days" to the missing fields list
3. WHEN the NumberOfDays field is present and greater than zero, THE Validation_Agent SHALL mark this check as passed
4. THE Validation_Agent SHALL include this check result in the CostSummaryFieldPresenceResult

### Requirement 8: Cost Summary Element-wise Quantity Field Presence

**User Story:** As an ASM, I want the system to verify that all cost elements have a Quantity field, so that I can ensure complete quantity data.

#### Acceptance Criteria

1. WHEN a Cost_Summary_Document is validated, THE Validation_Agent SHALL iterate through all CostBreakdowns
2. WHEN any CostBreakdown has a null or zero Quantity, THE Validation_Agent SHALL add the ElementName to the missing fields list
3. WHEN all CostBreakdowns have positive Quantity values, THE Validation_Agent SHALL mark this check as passed
4. THE Validation_Agent SHALL include element names in the validation error message for missing quantities

### Requirement 9: Cost Summary Element-wise Cost State Rate Backend Validation

**User Story:** As an ASM, I want the system to validate element costs against state-specific backend rates, so that I can detect pricing violations.

#### Acceptance Criteria

1. WHEN a Cost_Summary_Document is validated, THE Validation_Agent SHALL iterate through all CostBreakdowns
2. FOR EACH CostBreakdown, THE Validation_Agent SHALL call Reference_Data_Service to validate the Amount against the state rate for the ElementName
3. WHEN an element cost does not match the state rate, THE Validation_Agent SHALL add an issue to CostSummaryCrossDocumentResult with element name, actual cost, and expected rate
4. WHEN all element costs match state rates, THE Validation_Agent SHALL mark the ElementCostsValid flag as true
5. THE Validation_Agent SHALL skip validation for elements without defined state rates

### Requirement 10: Cost Summary Fixed Cost Limits State Rate Backend Validation

**User Story:** As an ASM, I want the system to validate fixed costs against state-specific limits, so that I can ensure compliance with cost policies.

#### Acceptance Criteria

1. WHEN a Cost_Summary_Document is validated, THE Validation_Agent SHALL filter CostBreakdowns where IsFixedCost is true
2. FOR EACH fixed cost, THE Validation_Agent SHALL call Reference_Data_Service to validate the Amount against state limits for the Category
3. IF a fixed cost exceeds the state limit, THEN THE Validation_Agent SHALL add an issue to CostSummaryCrossDocumentResult with category, actual cost, and limit
4. WHEN all fixed costs are within limits, THE Validation_Agent SHALL mark the FixedCostsValid flag as true
5. THE Validation_Agent SHALL skip validation for categories without defined limits

### Requirement 11: Cost Summary Variable Cost Limits State Rate Backend Validation

**User Story:** As an ASM, I want the system to validate variable costs against state-specific limits, so that I can ensure compliance with cost policies.

#### Acceptance Criteria

1. WHEN a Cost_Summary_Document is validated, THE Validation_Agent SHALL filter CostBreakdowns where IsVariableCost is true
2. FOR EACH variable cost, THE Validation_Agent SHALL call Reference_Data_Service to validate the Amount against state limits for the Category
3. IF a variable cost exceeds the state limit, THEN THE Validation_Agent SHALL add an issue to CostSummaryCrossDocumentResult with category, actual cost, and limit
4. WHEN all variable costs are within limits, THE Validation_Agent SHALL mark the VariableCostsValid flag as true
5. THE Validation_Agent SHALL skip validation for categories without defined limits

### Requirement 12: Activity Number of Days Cross-Validation with Cost Summary

**User Story:** As an ASM, I want the system to validate that Activity days match Cost Summary days, so that I can ensure consistency in campaign duration.

#### Acceptance Criteria

1. WHEN an Activity_Document and Cost_Summary_Document are validated together, THE Validation_Agent SHALL sum all NumberOfDays from LocationActivities
2. WHEN the Activity total days equals the Cost_Summary NumberOfDays, THE Validation_Agent SHALL mark the NumberOfDaysMatches flag as true
3. IF the Activity total days does not equal the Cost_Summary NumberOfDays, THEN THE Validation_Agent SHALL add an issue to ActivityCrossDocumentResult with both values
4. THE Validation_Agent SHALL handle null or missing NumberOfDays fields by treating them as validation failures

### Requirement 13: Photo Count vs Man Days Validation

**User Story:** As an ASM, I want the system to validate that photo count matches man-days from Activity Summary, so that I can ensure adequate photo documentation.

#### Acceptance Criteria

1. WHEN Photo_Documents and Activity_Document are validated together, THE Validation_Agent SHALL count the total number of Photo_Documents
2. WHEN the Activity_Document contains man-days data, THE Validation_Agent SHALL calculate total Man_Days from LocationActivities
3. WHEN the photo count equals or exceeds the Man_Days, THE Validation_Agent SHALL mark the PhotoCountMatchesManDays flag as true
4. IF the photo count is less than the Man_Days, THEN THE Validation_Agent SHALL add an issue to PhotoCrossDocumentResult with both values
5. THE Validation_Agent SHALL calculate Man_Days as the sum of NumberOfDays across all LocationActivities

### Requirement 14: Three-Way Validation (Photos-Activity-Cost Summary)

**User Story:** As an ASM, I want the system to perform a 3-way validation across Photos, Activity, and Cost Summary, so that I can ensure complete consistency across all documents.

#### Acceptance Criteria

1. WHEN Photo_Documents, Activity_Document, and Cost_Summary_Document are validated together, THE Validation_Agent SHALL perform all individual validations first
2. WHEN man-days from Activity_Document exceed days from Cost_Summary_Document, THE Validation_Agent SHALL add an issue to PhotoCrossDocumentResult
3. WHEN photo count is less than man-days AND man-days exceed cost summary days, THE Validation_Agent SHALL add a combined issue indicating 3-way inconsistency
4. WHEN all three documents are consistent (photo count ≥ man-days ≤ cost summary days), THE Validation_Agent SHALL mark the ManDaysWithinCostSummaryDays flag as true
5. THE Validation_Agent SHALL include all three values (photo count, man-days, cost summary days) in any 3-way validation issues

## Iteration and Feedback

This requirements document represents the initial specification for implementing the 14 missing validations. The requirements follow EARS patterns for clarity and INCOSE quality rules for testability. All requirements are structured to integrate seamlessly with the existing ValidationAgent architecture and leverage the existing IReferenceDataService interface.

Key design decisions:
- All new validations follow the existing pattern of separate field presence and cross-document validation methods
- Backend rate validations use the existing IReferenceDataService interface
- Validation results are added to existing result classes (InvoiceFieldPresenceResult, InvoiceCrossDocumentResult, etc.)
- Error messages include specific details (expected vs actual values) for actionable feedback
