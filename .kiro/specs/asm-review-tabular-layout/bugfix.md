# Bugfix Requirements Document

## Introduction

This document specifies the requirements for converting the ASM (Area Sales Manager) review detail page from a card-based layout to a tabular format. The current implementation displays document information, AI analysis results, and validation details in vertical card sections. The desired behavior is to reorganize this information into structured tables for better data organization and readability while maintaining all existing functionality.

Additionally, the comments field in the Review Decision section should be explicitly non-mandatory (no visual indicators suggesting it's required).

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN an ASM views the review detail page THEN the system displays document information in a card-based vertical layout with separate sections for each document type (PO, Invoice, Cost Summary, Event Photos)

1.2 WHEN an ASM views AI analysis results THEN the system displays verification points in a card with bullet points rather than a structured table format

1.3 WHEN an ASM views extracted document data THEN the system displays the data within card containers with inline text rather than in a tabular row-column structure

1.4 WHEN an ASM views the Review Decision section THEN the comments field may appear to be mandatory due to UI conventions, though no validation enforces this

### Expected Behavior (Correct)

2.1 WHEN an ASM views the review detail page THEN the system SHALL display document information in a tabular format with clearly defined columns and rows for better data organization

2.2 WHEN an ASM views AI analysis results THEN the system SHALL display verification points in a table structure with appropriate columns (e.g., Check Item, Status, Details)

2.3 WHEN an ASM views extracted document data THEN the system SHALL display the data in a structured table with Field and Value columns showing PO Number, Amount, Date, and other extracted information

2.4 WHEN an ASM views the Review Decision section THEN the system SHALL display the comments field without any visual indicators (such as asterisks) that suggest it is mandatory

### Unchanged Behavior (Regression Prevention)

3.1 WHEN an ASM approves a FAP submission THEN the system SHALL CONTINUE TO send the approval to HQ and update the submission state correctly

3.2 WHEN an ASM rejects a FAP submission THEN the system SHALL CONTINUE TO require rejection comments and send the rejection back to the Agency

3.3 WHEN an ASM downloads a document THEN the system SHALL CONTINUE TO open the document in a new browser tab using the blob URL

3.4 WHEN an ASM views confidence scores THEN the system SHALL CONTINUE TO display the percentage values with appropriate color coding (green ≥85%, yellow ≥70%, red <70%)

3.5 WHEN an ASM views HQ rejection information THEN the system SHALL CONTINUE TO display the rejection banner with HQ feedback and resubmit option

3.6 WHEN an ASM navigates back from the detail page THEN the system SHALL CONTINUE TO refresh the submissions list

3.7 WHEN the page loads submission details THEN the system SHALL CONTINUE TO make the API call to `/submissions/{id}` and display loading states appropriately

3.8 WHEN an ASM interacts with action buttons (Approve FAP, Reject FAP) THEN the system SHALL CONTINUE TO disable buttons during processing and show loading indicators
