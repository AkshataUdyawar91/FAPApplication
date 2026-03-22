# Requirements Document

## Introduction

The Agency Upload page currently presents a 7-step linear wizard for submitting document packages (Purchase Order, Invoice, Team, Cost Summary, Activity Summary, Enquiry Doc, Additional Docs). This feature consolidates those 7 steps into 3 steps, keeping the existing wizard-style stepper with Back/Next navigation. All underlying data, API calls, and upload logic remain unchanged — only the UI organisation changes.

The three steps are:
1. **Invoice Details** — PO upload + PO fields, Invoice(s), Cost Summary
2. **Teams** — Activity Summary and Team details (campaigns/photos)
3. **Enquiry & Additional Docs** — Enquiry document (mandatory) and Additional documents (optional)

## Glossary

- **Agency_Upload_Page**: The Flutter page at `agency_upload_page.dart` used by agency users to create or edit a submission.
- **Step**: A sequential section in the wizard. Three steps replace the previous 7 steps.
- **Stepper**: The existing wizard-style progress indicator with Back/Next navigation.
- **Step_Controller**: The `_currentStep` integer (1–3) that manages active step state.
- **Invoice_Details_Step**: Step 1 — contains PO upload, PO extracted fields, invoice list, and cost summary upload.
- **Teams_Step**: Step 2 — contains activity summary upload and the campaign/team list with photos.
- **Enquiry_Step**: Step 3 — contains the mandatory enquiry document upload and optional additional documents list.
- **Progress_Card**: The visual stepper card showing step numbers, titles, and progress bar.
- **Submission**: A document package created or edited by an agency user.
- **Edit_Mode**: When `submissionId` is provided to the page; existing data is pre-populated.
- **CampaignListSection**: Existing widget rendering team details and photos.
- **POFieldsSection**: Existing widget rendering extracted PO fields.

---

## Requirements

### Requirement 1: Three-Step Wizard Layout

**User Story:** As an agency user, I want the submission form organised into three clearly labelled steps, so that I can complete the submission in a logical sequence with fewer screens.

#### Acceptance Criteria

1. THE Agency_Upload_Page SHALL render a Progress_Card with exactly three steps: "Invoice Details", "Teams", and "Enquiry & Additional Docs".
2. WHEN the page first loads, THE Step_Controller SHALL activate Step 1 ("Invoice Details") by default.
3. THE Progress_Card SHALL visually indicate the current step, completed steps, and remaining steps using the Bajaj primary colour (`#003087`).
4. THE Agency_Upload_Page SHALL replace the existing 7-step `_steps` list and `_totalSteps = 7` with a 3-step equivalent.
5. THE existing Back and Next Step buttons SHALL remain, navigating between the 3 steps sequentially.

---

### Requirement 2: Invoice Details Step Content

**User Story:** As an agency user, I want all invoice-related documents and fields on one step, so that I can complete the financial section of my submission without switching screens.

#### Acceptance Criteria

1. THE Invoice_Details_Step SHALL contain the Purchase Order file upload card.
2. THE Invoice_Details_Step SHALL contain the POFieldsSection widget displaying extracted or manually entered PO fields.
3. THE Invoice_Details_Step SHALL contain the invoice list for adding and managing invoices linked to the PO.
4. THE Invoice_Details_Step SHALL contain the Cost Summary file upload card.
5. WHEN the PO extraction is in progress, THE Invoice_Details_Step SHALL display the extraction loading indicator within the step content area.
6. WHERE the page is in Edit_Mode and an existing PO file is present, THE Invoice_Details_Step SHALL display the existing file card with a "Replace" option.
7. WHEN the user taps "Next Step" on Step 1, THE Agency_Upload_Page SHALL validate that a Purchase Order file exists (new or existing); if missing, display "Please upload Purchase Order".

---

### Requirement 3: Teams Step Content

**User Story:** As an agency user, I want team and activity information on a dedicated step, so that I can manage campaign details independently from financial documents.

#### Acceptance Criteria

1. THE Teams_Step SHALL contain the Activity Summary file upload card.
2. THE Teams_Step SHALL contain the CampaignListSection widget for adding and managing teams and their photos.
3. WHERE the page is in Edit_Mode and an existing Activity Summary file is present, THE Teams_Step SHALL display the existing file card with a "Replace" option.

---

### Requirement 4: Enquiry & Additional Docs Step Content

**User Story:** As an agency user, I want the enquiry document and any supplementary files on a single step, so that I can complete the mandatory enquiry upload and optionally attach extra documents in one place.

#### Acceptance Criteria

1. THE Enquiry_Step SHALL contain the Enquiry document file upload card, labelled as mandatory.
2. THE Enquiry_Step SHALL contain the Additional Documents section, labelled as optional.
3. THE Enquiry_Step SHALL visually distinguish the mandatory Enquiry upload from the optional Additional Documents section (e.g., a "Required" badge or label on the enquiry card).
4. WHERE the page is in Edit_Mode and an existing Enquiry document is present, THE Enquiry_Step SHALL display the existing file card with a "Replace" option.
5. WHEN the user taps "Submit for Review" on Step 3, THE Agency_Upload_Page SHALL validate that an Enquiry document file exists (new or existing); if missing, display "Please upload Enquiry Document".

---

### Requirement 5: Submission Action

**User Story:** As an agency user, I want a "Submit" button on the final step, so that I can submit my package after completing all three sections.

#### Acceptance Criteria

1. THE Agency_Upload_Page SHALL render the Submit button only on Step 3 (replacing the "Next Step" button).
2. WHEN the user taps "Submit for Review" and the Enquiry document is missing, THE Agency_Upload_Page SHALL display "Please upload Enquiry Document".
3. WHEN the user taps "Submit for Review" and all required fields are present, THE Agency_Upload_Page SHALL execute the existing `_handleSubmit` logic unchanged.
4. WHILE a submission is uploading, THE Agency_Upload_Page SHALL disable the Submit button and display a loading indicator on it.

---

### Requirement 6: Edit Mode Pre-population

**User Story:** As an agency user editing an existing submission, I want all previously uploaded files and data to appear in the correct tabs, so that I can review and update only what needs changing.

#### Acceptance Criteria

1. WHEN the page loads in Edit_Mode, THE Agency_Upload_Page SHALL call the existing `_loadExistingSubmission` method and pre-populate all tab sections with retrieved data.
2. WHEN existing submission data is loading, THE Agency_Upload_Page SHALL display a full-page loading indicator across all tabs.
3. WHEN loading completes, THE Agency_Upload_Page SHALL display pre-populated data in the appropriate tab: PO and invoices in Invoice_Details_Tab, teams and activity summary in Teams_Tab, enquiry and additional docs in Enquiry_Tab.

---

### Requirement 7: Responsive Layout

**User Story:** As an agency user on any device, I want the tab layout to adapt to my screen size, so that the form is usable on mobile, tablet, and desktop.

#### Acceptance Criteria

1. THE Tab_Bar SHALL render horizontally on tablet and desktop screen widths (≥ 600px).
2. THE Tab_Bar SHALL render horizontally on mobile (< 600px) with tab labels truncated or scrollable if needed.
3. THE Agency_Upload_Page SHALL preserve the existing sidebar, top bar, and chat panel behaviour on all device sizes.
4. THE Agency_Upload_Page SHALL preserve the existing mobile `AppBar` and `AppDrawer` on mobile screen widths.

---

### Requirement 8: No Backend Changes

**User Story:** As a developer, I want the redesign to be purely a UI reorganisation, so that no API contracts, data models, or backend logic need to change.

#### Acceptance Criteria

1. THE Agency_Upload_Page SHALL retain all existing state variables (`_purchaseOrder`, `_invoices`, `_campaigns`, `_costSummaryFile`, `_activitySummaryFile`, `_enquiryDocFile`, `_additionalDocs`, etc.) without modification.
2. THE Agency_Upload_Page SHALL retain all existing API call methods (`_handleSubmit`, `_uploadAndExtractPO`, `_pollForPOExtraction`, `_loadExistingSubmission`, etc.) without modification.
3. THE Agency_Upload_Page SHALL retain all existing file picker methods without modification.
