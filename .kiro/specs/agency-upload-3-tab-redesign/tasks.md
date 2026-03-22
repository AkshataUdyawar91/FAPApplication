# Implementation Plan: Agency Upload 3-Step Redesign

## Overview

Consolidate the existing 7-step wizard in `agency_upload_page.dart` into 3 steps by updating step metadata, navigation validation, and step content builders. All state variables, API methods, and upload logic remain untouched.

## Tasks

- [x] 1. Update step metadata and constants
  - Change `_totalSteps` from `7` to `3`
  - Replace the 7-entry `_steps` list with 3 entries: `Invoice Details` (Icons.receipt_long), `Teams` (Icons.groups), `Enquiry & Docs` (Icons.find_in_page)
  - _Requirements: 1.1, 1.4_

- [x] 2. Update `_handleNext` validation for 3-step flow
  - [x] 2.1 Rewrite `_handleNext` to validate step 1 (PO required) and step 2 (at least one team required), then increment `_currentStep` up to 3
    - Remove old step 2 campaign/invoice/photo checks (those validations no longer block Next in the new flow)
    - _Requirements: 1.5, 2.7_
  - [ ]* 2.2 Write widget test for `_handleNext` step-1 PO validation
    - **Property 2: Next/Back navigation stays in bounds**
    - **Validates: Requirements 1.5**

- [x] 3. Add enquiry doc validation to `_handleSubmit`
  - Insert guard before the existing PO check: if `_enquiryDocFile == null && _existingEnquiryDocFileName == null`, call `_showError('Please upload Enquiry Document')` and return
  - _Requirements: 4.5, 5.2_

- [x] 4. Replace `_buildStepContent` with 3-case switch
  - Remove the existing 7-case switch body
  - Add `case 1`, `case 2`, `case 3` delegating to `_buildInvoiceDetailsStep`, `_buildTeamsStep`, `_buildEnquiryStep` respectively, each wrapped in `SingleChildScrollView`
  - _Requirements: 1.1_

- [x] 5. Implement `_buildInvoiceDetailsStep`
  - [x] 5.1 Compose the Invoice Details step widget
    - Render PO upload card (existing `_buildFileUploadCard` / `_buildExistingFileCard` for `_purchaseOrder` / `_existingPOFileName`)
    - Render extraction loading card when `_isExtractingPO == true`, otherwise render `POFieldsSection`
    - Render the invoice list section (existing inline invoice UI previously in old step 2)
    - Render cost summary upload card
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  - [ ]* 5.2 Write widget test for Invoice Details step content
    - Verify PO card, POFieldsSection, invoice list, and cost summary card are present
    - Verify extraction loading indicator shown when `_isExtractingPO = true`
    - _Requirements: 2.1–2.5_

- [x] 6. Implement `_buildTeamsStep`
  - [x] 6.1 Compose the Teams step widget
    - Render activity summary upload card (existing `_buildFileUploadCard` / `_buildExistingFileCard` for `_activitySummaryFile` / `_existingActivitySummaryFileName`)
    - Render `CampaignListSection` (unchanged widget, unchanged parameters)
    - _Requirements: 3.1, 3.2, 3.3_
  - [ ]* 6.2 Write widget test for Teams step content
    - Verify activity summary card and CampaignListSection are present
    - _Requirements: 3.1, 3.2_

- [x] 7. Implement `_buildEnquiryStep`
  - [x] 7.1 Compose the Enquiry & Additional Docs step widget
    - Render enquiry doc upload card with a "Required" badge — a small `Container` with `AppColors.primary` background and white text placed next to the card title
    - Render additional documents section (existing `_buildAdditionalDocsStep` content, labelled optional)
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [ ]* 7.2 Write widget test for Enquiry step content
    - Verify enquiry card with "Required" badge is present
    - Verify additional docs section is present
    - _Requirements: 4.1, 4.2, 4.3_

- [x] 8. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Verify Submit button placement and action buttons
  - Confirm `_buildActionButtons` renders Submit only on step 3 and Next Step on steps 1–2 (no code change expected; verify by inspection)
  - Confirm Back button is hidden on step 1 and visible on steps 2–3
  - _Requirements: 5.1, 5.4, 1.5_

- [x] 10. Verify edit-mode pre-population across new steps
  - Confirm `_loadExistingSubmission` still populates all state variables consumed by the three new step builders
  - Confirm full-page loading indicator (`_isLoadingExisting`) is shown across all steps during load
  - _Requirements: 6.1, 6.2, 6.3_

- [x] 11. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- All state variables and API methods remain unchanged per Requirement 8
- The "Required" badge uses `AppColors.primary` (#003087) per Bajaj brand guidelines
- Property tests validate universal correctness properties from the design document
