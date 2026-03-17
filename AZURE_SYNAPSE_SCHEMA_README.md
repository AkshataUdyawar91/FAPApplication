# Azure Synapse Analytics Schema - Balsynwsdev

Complete database schema for the Bajaj Document Processing system, targeting Azure Synapse Analytics Dedicated SQL Pool. All tables prefixed with `BDP_`.

## Target Environment

- Platform: Azure Synapse Analytics (Dedicated SQL Pool)
- Database: `Balsynwsdev`
- Table Prefix: `BDP_`
- Client Tool: SSMS 18+

## Execution Order

Run in SSMS connected to your Synapse dedicated SQL pool:

1. `AZURE_SYNAPSE_COMPLETE_SCHEMA_PART1.sql` - Drops all BDP_ tables, creates reference data + core entity tables
2. `AZURE_SYNAPSE_COMPLETE_SCHEMA_PART2.sql` - Document entity tables
3. `AZURE_SYNAPSE_COMPLETE_SCHEMA_PART3.sql` - Validation, scoring, workflow, notification, chat tables
4. `AZURE_SYNAPSE_COMPLETE_SCHEMA_PART4.sql` - Seed data (reference + test data)

## Synapse Compatibility

| Feature | What We Did |
|---------|------------|
| Foreign Keys | Removed - documented as comments |
| UNIQUE constraints | Removed |
| DEFAULT values | Removed - explicit values in INSERTs |
| PRIMARY KEY | Removed - using CCI instead |
| CREATE INDEX | Removed - CCI handles analytics queries |
| DROP TABLE IF EXISTS | Uses `IF EXISTS (SELECT ... FROM sys.objects)` pattern |
| NVARCHAR(MAX) | Changed to NVARCHAR(4000) |
| Distribution | HASH on join keys for fact tables, ROUND_ROBIN for dimensions |

## All 24 Tables

| # | Table Name | Distribution | Purpose |
|---|-----------|-------------|---------|
| 1 | BDP_StateGstMasters | ROUND_ROBIN | GST state codes |
| 2 | BDP_HsnMasters | ROUND_ROBIN | HSN/SAC codes |
| 3 | BDP_CostMasters | ROUND_ROBIN | Cost elements |
| 4 | BDP_CostMasterStateRates | ROUND_ROBIN | State-wise rates |
| 5 | BDP_Agencies | ROUND_ROBIN | Supplier agencies |
| 6 | BDP_ASMs | ROUND_ROBIN | Area Sales Managers |
| 7 | BDP_Users | ROUND_ROBIN | System users |
| 8 | BDP_DocumentPackages | HASH(AgencyId) | Submission packages |
| 9 | BDP_POs | HASH(PackageId) | Purchase Orders |
| 10 | BDP_CostSummaries | HASH(PackageId) | Cost summaries |
| 11 | BDP_ActivitySummaries | HASH(PackageId) | Activity summaries |
| 12 | BDP_EnquiryDocuments | HASH(PackageId) | Enquiry documents |
| 13 | BDP_AdditionalDocuments | HASH(PackageId) | Supporting documents |
| 14 | BDP_Invoices | HASH(PackageId) | Invoices |
| 15 | BDP_Teams | HASH(PackageId) | Campaign teams |
| 16 | BDP_TeamPhotos | HASH(PackageId) | Team photos |
| 17 | BDP_CampaignInvoices | HASH(PackageId) | Campaign invoices |
| 18 | BDP_ValidationResults | ROUND_ROBIN | Validation results |
| 19 | BDP_ConfidenceScores | HASH(PackageId) | AI confidence scores |
| 20 | BDP_Recommendations | HASH(PackageId) | AI recommendations |
| 21 | BDP_RequestApprovalHistory | HASH(PackageId) | Approval history |
| 22 | BDP_RequestComments | HASH(PackageId) | Package comments |
| 23 | BDP_Notifications | HASH(UserId) | User notifications |
| 24 | BDP_AuditLogs | ROUND_ROBIN | Audit trail |
| 25 | BDP_Conversations | HASH(UserId) | Chat conversations |
| 26 | BDP_ConversationMessages | HASH(ConversationId) | Chat messages |

## Enum Mappings

| Enum | Values |
|------|--------|
| UserRole | 0=Agency, 1=ASM, 2=RA, 3=Admin |
| DocumentType | 0=PO, 1=Invoice, 2=CostSummary, 3=ActivitySummary, 4=EnquiryDocument, 5=TeamPhoto |
| PackageState | 0=Uploaded, 1=Extracting, 2=Validating, 3=PendingASM, 4=ASMRejected, 5=PendingRA, 6=RARejected, 7=Approved |
| NotificationType | 0=SubmissionReceived, 1=FlaggedForReview, 2=Approved, 3=Rejected, 4=ReuploadRequested |
| RecommendationType | 0=Approve, 1=Review, 2=Reject |
| ApprovalAction | 0=Submitted, 1=Approved, 2=Rejected, 3=Resubmitted |
