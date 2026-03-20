-- =============================================
-- Script: SEED_RULE_RESULTS_JSON.sql
-- Purpose: Populate RuleResultsJson in ValidationResults for all 12 test
--          submissions seeded by SEED_TEAMS_TEST_DATA.sql.
--          Rule codes and JSON format match ProactiveValidationService.cs.
-- Date: 2026-03-19
-- Idempotent: Yes — only updates rows where RuleResultsJson IS NULL.
-- Rollback: UPDATE ValidationResults SET RuleResultsJson = NULL
--           WHERE DocumentId IN (SELECT Id FROM POs WHERE PONumber LIKE 'PO-TEST-%')
--           ... (repeat for each doc table with seed pattern)
-- =============================================

-- Guard: only update rows that don't already have RuleResultsJson
-- We match on SubmissionNumber pattern from the seed data.

-- ============================================================
-- SUBMISSION 1: All pass (Maharashtra, PO-TEST-MH-001)
-- PO=all pass, Invoice=all pass, CS=all pass, AS=all pass, ED=all pass
-- ============================================================

-- PO (DocumentType=1)
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-MH-001","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-10","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"450000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-MH-001' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

-- Invoice/CampaignInvoice (DocumentType=2)
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-MH-2026-001","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-12","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"450000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"27AABCU9603R1ZM","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00123","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-MH-001","expectedValue":"PO-TEST-MH-001"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":true,"extractedValue":"450000.00","expectedValue":"450000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-MH-2026-001' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

-- CostSummary (DocumentType=3)
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Maharashtra","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"12","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"450000.00","expectedValue":"450000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00001')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

-- ActivitySummary (DocumentType=4)
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":true,"extractedValue":"Bajaj Auto Pune","expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"12","expectedValue":"12"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"12","expectedValue":"12"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00001')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

-- EnquiryDocument (DocumentType=5)
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"87","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"84","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00001')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;


-- ============================================================
-- SUBMISSION 2: Some failures (Maharashtra, PO-TEST-MH-002)
-- PO: AmountConsistency=0 → PO_SAP amount mismatch
-- Invoice: AmountConsistency=0, Completeness=0 → INV_AMOUNT_VS_PO_BALANCE fail, INV_GST_PERCENT missing
-- CS: all pass
-- AS: Completeness=0 → AS_DEALER_LOCATION missing
-- ED: all pass
-- ============================================================

-- PO (DocumentType=1) — AmountConsistencyPassed=0
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-MH-002","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-12","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"280000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":false,"extractedValue":"280000.00","expectedValue":"295000.00"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-MH-002' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

-- Invoice (DocumentType=2) — AmountConsistency=0, Completeness=0
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-MH-2026-002","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-14","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"280000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"27AABCU9603R1ZM","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00123","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-MH-002","expectedValue":"PO-TEST-MH-002"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":false,"extractedValue":"280000.00","expectedValue":"245000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-MH-2026-002' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

-- CostSummary (DocumentType=3) — all pass
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Maharashtra","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"10","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"280000.00","expectedValue":"280000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00002')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

-- ActivitySummary (DocumentType=4) — Completeness=0
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"10","expectedValue":"10"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"10","expectedValue":"10"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00002')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

-- EnquiryDocument (DocumentType=5) — all pass
UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"52","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"45","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00002')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;

-- ============================================================
-- SUBMISSION 3: All pass (Gujarat, PO-TEST-GJ-001)
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-GJ-001","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-08","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"620000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-GJ-001' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-GJ-2026-001","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-15","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"620000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"24AABCU9603R1ZN","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00456","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-GJ-001","expectedValue":"PO-TEST-GJ-001"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":true,"extractedValue":"620000.00","expectedValue":"500000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-GJ-2026-001' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Gujarat","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"15","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"620000.00","expectedValue":"620000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00003')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":true,"extractedValue":"Bajaj Auto Ahmedabad","expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"15","expectedValue":"15"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"15","expectedValue":"15"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00003')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"120","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"115","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00003')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;


-- ============================================================
-- SUBMISSION 4: Many failures (Karnataka, PO-TEST-KA-001)
-- PO: SapVerification=0, AmountConsistency=0, LineItem=0, Vendor=0
-- Invoice: ALL=0
-- CS: AmountConsistency=0, LineItem=0
-- AS: Completeness=0, Date=0
-- ED: Completeness=0
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-KA-001","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-05","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"380000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":false,"extractedValue":"Unknown Vendor","expectedValue":"Demo Agency"},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":false,"extractedValue":"Not Found","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-KA-001' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-KA-2026-001","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"380000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":false,"extractedValue":"PO-WRONG-001","expectedValue":"PO-TEST-KA-001"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":false,"extractedValue":"380000.00","expectedValue":"320000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-KA-2026-001' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Karnataka","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"9","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":false,"extractedValue":"395000.00","expectedValue":"380000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":false,"extractedValue":null,"expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00004')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":false,"extractedValue":"12","expectedValue":"9"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"9","expectedValue":"9"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00004')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"30","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":false,"extractedValue":"Name,Phone,Date","expectedValue":"Name,Phone,Date,State,Model"}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00004')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;

-- ============================================================
-- SUBMISSION 5: All pass (Rajasthan, PO-TEST-RJ-001)
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-RJ-001","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-01","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"550000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-RJ-001' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-RJ-2026-001","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-14","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"550000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"08AABCU9603R1ZQ","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00789","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-RJ-001","expectedValue":"PO-TEST-RJ-001"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":true,"extractedValue":"550000.00","expectedValue":"550000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-RJ-2026-001' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Rajasthan","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"14","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"550000.00","expectedValue":"550000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00005')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":true,"extractedValue":"Bajaj Auto Jaipur","expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"14","expectedValue":"14"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"14","expectedValue":"14"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00005')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"95","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"90","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00005')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;


-- ============================================================
-- SUBMISSION 6: Date failures (Uttar Pradesh, PO-TEST-UP-001)
-- PO: Date=0 → PO date outside validity
-- Invoice: Date=0 → invoice date outside PO period
-- CS: AmountConsistency=0 → cost total mismatch
-- AS: Completeness=0, Date=0 → missing fields, days mismatch
-- ED: all pass
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-UP-001","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-02-28","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"720000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":false,"extractedValue":"2026-02-28","expectedValue":"2026-03-01 to 2026-03-31"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-UP-001' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-UP-2026-001","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":false,"extractedValue":"2026-02-20","expectedValue":"2026-02-25 to 2026-03-15"},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"720000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"09AABCU9603R1ZR","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00234","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-UP-001","expectedValue":"PO-TEST-UP-001"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":false,"extractedValue":"720000.00","expectedValue":"600000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-UP-2026-001' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Uttar Pradesh","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"15","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":false,"extractedValue":"735000.00","expectedValue":"720000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00006')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":false,"extractedValue":"19","expectedValue":"15"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"15","expectedValue":"15"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00006')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"65","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"58","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00006')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;

-- ============================================================
-- SUBMISSION 7: All pass (Maharashtra PendingRA, PO-TEST-MH-003)
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-MH-003","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-01","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"900000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-MH-003' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-MH-2026-003","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-08","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"900000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"27AABCU9603R1ZM","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00123","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-MH-003","expectedValue":"PO-TEST-MH-003"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":true,"extractedValue":"900000.00","expectedValue":"650000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-MH-2026-003' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Maharashtra","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"15","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"900000.00","expectedValue":"900000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00007')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":true,"extractedValue":"Bajaj Auto Nagpur","expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"15","expectedValue":"15"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"15","expectedValue":"15"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00007')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"110","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"105","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00007')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;


-- ============================================================
-- SUBMISSION 8: All pass (Gujarat PendingRA, PO-TEST-GJ-002)
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-GJ-002","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-02-25","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"410000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-GJ-002' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-GJ-2026-002","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-05","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"410000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"24AABCU9603R1ZN","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00456","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-GJ-002","expectedValue":"PO-TEST-GJ-002"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":true,"extractedValue":"410000.00","expectedValue":"410000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-GJ-2026-002' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Gujarat","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"13","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"410000.00","expectedValue":"410000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00008')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":true,"extractedValue":"Bajaj Auto Surat","expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"13","expectedValue":"13"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"13","expectedValue":"13"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00008')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"78","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"74","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00008')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;

-- ============================================================
-- SUBMISSION 9: Mixed failures (UP PendingRA, PO-TEST-UP-002)
-- PO: all pass
-- Invoice: AmountConsistency=0 → amount exceeds PO
-- CS: AmountConsistency=0, LineItem=0 → total mismatch, elements missing
-- AS: Completeness=0 → dealer location missing
-- ED: all pass
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-UP-002","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-02","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"530000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-UP-002' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-UP-2026-002","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-12","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"530000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"09AABCU9603R1ZR","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00234","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-UP-002","expectedValue":"PO-TEST-UP-002"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":false,"extractedValue":"530000.00","expectedValue":"480000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-UP-2026-002' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Uttar Pradesh","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"12","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":false,"extractedValue":"545000.00","expectedValue":"530000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":false,"extractedValue":null,"expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00009')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"12","expectedValue":"12"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"12","expectedValue":"12"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00009')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"42","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"35","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00009')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;


-- ============================================================
-- SUBMISSION 10: All pass (West Bengal PendingRA, PO-TEST-WB-001)
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-WB-001","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-06","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"340000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-WB-001' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-WB-2026-001","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-03-10","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"340000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"19AABCU9603R1ZS","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00567","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-WB-001","expectedValue":"PO-TEST-WB-001"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":true,"extractedValue":"340000.00","expectedValue":"340000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-WB-2026-001' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"West Bengal","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"10","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"340000.00","expectedValue":"340000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00010')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":true,"extractedValue":"Bajaj Auto Kolkata","expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"10","expectedValue":"10"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"10","expectedValue":"10"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00010')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"68","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"65","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00010')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;

-- ============================================================
-- SUBMISSION 11: All pass (Maharashtra Approved, PO-TEST-MH-004)
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-MH-004","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-02-15","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"1100000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":true,"extractedValue":"Demo Agency","expectedValue":null},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":true,"extractedValue":"Verified","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-MH-004' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-MH-2026-004","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-02-28","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"1100000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"27AABCU9603R1ZM","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":true,"extractedValue":"18","expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":true,"extractedValue":"998361","expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":true,"extractedValue":"V00123","expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":true,"extractedValue":"PO-TEST-MH-004","expectedValue":"PO-TEST-MH-004"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":true,"extractedValue":"1100000.00","expectedValue":"800000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-MH-2026-004' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":true,"extractedValue":"Maharashtra","expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"16","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":true,"extractedValue":"1100000.00","expectedValue":"1100000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":true,"extractedValue":"Present","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00011')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":true,"extractedValue":"Bajaj Auto Thane","expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":true,"extractedValue":"16","expectedValue":"16"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"16","expectedValue":"16"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00011')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"150","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"148","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":true,"extractedValue":"Name,Phone,Date,State,Model","expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00011')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;

-- ============================================================
-- SUBMISSION 12: Heavy failures — ASMRejected (Gujarat, PO-TEST-GJ-003)
-- PO: SapVerification=0, LineItem=0, Vendor=0
-- Invoice: SapVerification=0, AmountConsistency=0, LineItem=0, Completeness=0, Vendor=0
-- CS: AmountConsistency=0, LineItem=0, Completeness=0
-- AS: Completeness=0, Date=0
-- ED: Completeness=0
-- ============================================================

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"PO_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"PO-TEST-GJ-003","expectedValue":null},{"ruleCode":"PO_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-02-20","expectedValue":null},{"ruleCode":"PO_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"200000.00","expectedValue":null},{"ruleCode":"PO_VENDOR_PRESENT","type":"Required","passed":false,"extractedValue":"Some Other Vendor","expectedValue":"Demo Agency"},{"ruleCode":"PO_SAP_VERIFIED","type":"Check","passed":false,"extractedValue":"Not Found","expectedValue":"Verified"}]'
FROM ValidationResults vr
INNER JOIN POs p ON vr.DocumentId = p.Id
WHERE p.PONumber = 'PO-TEST-GJ-003' AND vr.DocumentType = 1 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"INV_INVOICE_NUMBER_PRESENT","type":"Required","passed":true,"extractedValue":"INV-GJ-2026-003","expectedValue":null},{"ruleCode":"INV_DATE_PRESENT","type":"Required","passed":true,"extractedValue":"2026-02-25","expectedValue":null},{"ruleCode":"INV_AMOUNT_PRESENT","type":"Required","passed":true,"extractedValue":"200000.00","expectedValue":null},{"ruleCode":"INV_GST_NUMBER_PRESENT","type":"Required","passed":false,"extractedValue":"24XXXXX9999R1ZZ","expectedValue":null},{"ruleCode":"INV_GST_PERCENT_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_HSN_SAC_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_VENDOR_CODE_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"INV_PO_NUMBER_MATCH","type":"Check","passed":false,"extractedValue":"PO-FAKE-999","expectedValue":"PO-TEST-GJ-003"},{"ruleCode":"INV_AMOUNT_VS_PO_BALANCE","type":"Check","passed":false,"extractedValue":"200000.00","expectedValue":"150000.00"}]'
FROM ValidationResults vr
INNER JOIN CampaignInvoices ci ON vr.DocumentId = ci.Id
WHERE ci.InvoiceNumber = 'INV-GJ-2026-003' AND vr.DocumentType = 2 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"CS_PLACE_OF_SUPPLY_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"CS_TOTAL_DAYS_PRESENT","type":"Required","passed":true,"extractedValue":"10","expectedValue":null},{"ruleCode":"CS_TOTAL_VS_INVOICE","type":"Check","passed":false,"extractedValue":"215000.00","expectedValue":"200000.00"},{"ruleCode":"CS_ELEMENT_COST_VS_RATES","type":"Check","passed":false,"extractedValue":null,"expectedValue":null}]'
FROM ValidationResults vr
INNER JOIN CostSummaries cs ON vr.DocumentId = cs.Id
WHERE cs.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00012')
  AND vr.DocumentType = 3 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"AS_DEALER_LOCATION_PRESENT","type":"Required","passed":false,"extractedValue":null,"expectedValue":null},{"ruleCode":"AS_DAYS_MATCH_COST_SUMMARY","type":"Check","passed":false,"extractedValue":"14","expectedValue":"10"},{"ruleCode":"AS_DAYS_MATCH_TEAM_DETAILS","type":"Check","passed":true,"extractedValue":"10","expectedValue":"10"}]'
FROM ValidationResults vr
INNER JOIN ActivitySummaries a ON vr.DocumentId = a.Id
WHERE a.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00012')
  AND vr.DocumentType = 4 AND vr.RuleResultsJson IS NULL;

UPDATE vr SET vr.RuleResultsJson = '[{"ruleCode":"ED_TOTAL_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"20","expectedValue":null},{"ruleCode":"ED_COMPLETE_RECORDS_PRESENT","type":"Required","passed":true,"extractedValue":"10","expectedValue":null},{"ruleCode":"ED_FIELDS_PRESENT","type":"Required","passed":false,"extractedValue":"Name,Phone","expectedValue":"Name,Phone,Date,State,Model"}]'
FROM ValidationResults vr
INNER JOIN EnquiryDocuments ed ON vr.DocumentId = ed.Id
WHERE ed.PackageId IN (SELECT Id FROM DocumentPackages WHERE SubmissionNumber = 'CIQ-TEST-00012')
  AND vr.DocumentType = 5 AND vr.RuleResultsJson IS NULL;

-- ============================================================
-- SUMMARY
-- ============================================================
PRINT 'RuleResultsJson populated for all 12 submissions (60 ValidationResult rows).';
PRINT 'Rule codes match ProactiveValidationService.cs serialization format.';
PRINT '';
PRINT 'Submissions with failures: 2 (partial), 4 (heavy), 6 (date), 9 (mixed), 12 (rejected)';
PRINT 'Submissions all-pass: 1, 3, 5, 7, 8, 10, 11';
