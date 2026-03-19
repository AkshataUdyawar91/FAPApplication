-- =============================================
-- Migration: Drop deprecated columns from DocumentPackages
-- Date: 2026-03-18
-- Author: Kiro
-- Purpose: Remove columns that were replaced by dedicated tables:
--   - Review/approval columns → RequestApprovalHistory table
--   - Resubmission count columns → VersionNumber column
--   - Campaign/dealership columns → Teams table
--   - Enquiry document columns → EnquiryDocument table
-- Rollback: DROP_DOCUMENTPACKAGES_DEPRECATED_COLUMNS_ROLLBACK.sql
-- Dependencies: None (columns are already removed from the EF entity)
-- Safe to run multiple times (idempotent)
-- =============================================

BEGIN TRANSACTION;

BEGIN TRY

    -- ── 1. Review / Approval columns (replaced by RequestApprovalHistory) ──

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ReviewedByUserId')
        ALTER TABLE DocumentPackages DROP COLUMN ReviewedByUserId;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ReviewedAt')
        ALTER TABLE DocumentPackages DROP COLUMN ReviewedAt;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ReviewNotes')
        ALTER TABLE DocumentPackages DROP COLUMN ReviewNotes;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ASMReviewedByUserId')
        ALTER TABLE DocumentPackages DROP COLUMN ASMReviewedByUserId;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ASMReviewedAt')
        ALTER TABLE DocumentPackages DROP COLUMN ASMReviewedAt;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ASMReviewNotes')
        ALTER TABLE DocumentPackages DROP COLUMN ASMReviewNotes;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'HQReviewedByUserId')
        ALTER TABLE DocumentPackages DROP COLUMN HQReviewedByUserId;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'HQReviewedAt')
        ALTER TABLE DocumentPackages DROP COLUMN HQReviewedAt;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'HQReviewNotes')
        ALTER TABLE DocumentPackages DROP COLUMN HQReviewNotes;

    -- ── 2. Resubmission count columns (replaced by VersionNumber) ──

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'ResubmissionCount')
        ALTER TABLE DocumentPackages DROP COLUMN ResubmissionCount;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'HQResubmissionCount')
        ALTER TABLE DocumentPackages DROP COLUMN HQResubmissionCount;

    -- ── 3. Campaign / dealership columns (moved to Teams table) ──

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'CampaignStartDate')
        ALTER TABLE DocumentPackages DROP COLUMN CampaignStartDate;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'CampaignEndDate')
        ALTER TABLE DocumentPackages DROP COLUMN CampaignEndDate;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'CampaignWorkingDays')
        ALTER TABLE DocumentPackages DROP COLUMN CampaignWorkingDays;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'DealershipName')
        ALTER TABLE DocumentPackages DROP COLUMN DealershipName;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'DealershipAddress')
        ALTER TABLE DocumentPackages DROP COLUMN DealershipAddress;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'GPSLocation')
        ALTER TABLE DocumentPackages DROP COLUMN GPSLocation;

    -- ── 4. Enquiry document columns (moved to EnquiryDocument table) ──

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocFileName')
        ALTER TABLE DocumentPackages DROP COLUMN EnquiryDocFileName;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocBlobUrl')
        ALTER TABLE DocumentPackages DROP COLUMN EnquiryDocBlobUrl;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocContentType')
        ALTER TABLE DocumentPackages DROP COLUMN EnquiryDocContentType;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocFileSizeBytes')
        ALTER TABLE DocumentPackages DROP COLUMN EnquiryDocFileSizeBytes;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocExtractedDataJson')
        ALTER TABLE DocumentPackages DROP COLUMN EnquiryDocExtractedDataJson;

    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'DocumentPackages' AND COLUMN_NAME = 'EnquiryDocExtractionConfidence')
        ALTER TABLE DocumentPackages DROP COLUMN EnquiryDocExtractionConfidence;

    PRINT 'DROP_DOCUMENTPACKAGES_DEPRECATED_COLUMNS: completed successfully.';

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT 'ERROR: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
