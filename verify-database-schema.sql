-- Comprehensive Database Schema Verification
-- This script checks if all required tables and columns exist

USE BajajDocumentProcessing;
GO

PRINT '========================================';
PRINT 'DATABASE SCHEMA VERIFICATION';
PRINT '========================================';
PRINT '';

-- Check DocumentPackages table
PRINT '1. Checking DocumentPackages table...';
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'DocumentPackages')
BEGIN
    PRINT '   [OK] DocumentPackages table exists';
    
    -- Check critical columns for approval workflow
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('DocumentPackages') AND name = 'State')
        PRINT '   [OK] State column exists';
    ELSE
        PRINT '   [ERROR] State column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('DocumentPackages') AND name = 'ASMReviewedAt')
        PRINT '   [OK] ASMReviewedAt column exists';
    ELSE
        PRINT '   [ERROR] ASMReviewedAt column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('DocumentPackages') AND name = 'ASMReviewNotes')
        PRINT '   [OK] ASMReviewNotes column exists';
    ELSE
        PRINT '   [ERROR] ASMReviewNotes column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('DocumentPackages') AND name = 'HQReviewedAt')
        PRINT '   [OK] HQReviewedAt column exists';
    ELSE
        PRINT '   [ERROR] HQReviewedAt column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('DocumentPackages') AND name = 'HQReviewNotes')
        PRINT '   [OK] HQReviewNotes column exists';
    ELSE
        PRINT '   [ERROR] HQReviewNotes column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('DocumentPackages') AND name = 'ResubmissionCount')
        PRINT '   [OK] ResubmissionCount column exists';
    ELSE
        PRINT '   [WARNING] ResubmissionCount column missing (will be added)';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('DocumentPackages') AND name = 'HQResubmissionCount')
        PRINT '   [OK] HQResubmissionCount column exists';
    ELSE
        PRINT '   [WARNING] HQResubmissionCount column missing (will be added)';
END
ELSE
BEGIN
    PRINT '   [ERROR] DocumentPackages table does not exist!';
END
PRINT '';

-- Check Documents table
PRINT '2. Checking Documents table...';
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Documents')
BEGIN
    PRINT '   [OK] Documents table exists';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Documents') AND name = 'Type')
        PRINT '   [OK] Type column exists (for PO, Invoice, CostSummary, Photo)';
    ELSE
        PRINT '   [ERROR] Type column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Documents') AND name = 'ExtractedDataJson')
        PRINT '   [OK] ExtractedDataJson column exists';
    ELSE
        PRINT '   [ERROR] ExtractedDataJson column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Documents') AND name = 'ExtractionConfidence')
        PRINT '   [OK] ExtractionConfidence column exists';
    ELSE
        PRINT '   [ERROR] ExtractionConfidence column missing!';
END
ELSE
BEGIN
    PRINT '   [ERROR] Documents table does not exist!';
END
PRINT '';

-- Check ConfidenceScores table
PRINT '3. Checking ConfidenceScores table...';
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'ConfidenceScores')
BEGIN
    PRINT '   [OK] ConfidenceScores table exists';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('ConfidenceScores') AND name = 'PoConfidence')
        PRINT '   [OK] PoConfidence column exists';
    ELSE
        PRINT '   [ERROR] PoConfidence column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('ConfidenceScores') AND name = 'InvoiceConfidence')
        PRINT '   [OK] InvoiceConfidence column exists';
    ELSE
        PRINT '   [ERROR] InvoiceConfidence column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('ConfidenceScores') AND name = 'CostSummaryConfidence')
        PRINT '   [OK] CostSummaryConfidence column exists';
    ELSE
        PRINT '   [ERROR] CostSummaryConfidence column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('ConfidenceScores') AND name = 'PhotosConfidence')
        PRINT '   [OK] PhotosConfidence column exists';
    ELSE
        PRINT '   [ERROR] PhotosConfidence column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('ConfidenceScores') AND name = 'OverallConfidence')
        PRINT '   [OK] OverallConfidence column exists';
    ELSE
        PRINT '   [ERROR] OverallConfidence column missing!';
END
ELSE
BEGIN
    PRINT '   [ERROR] ConfidenceScores table does not exist!';
END
PRINT '';

-- Check ValidationResults table
PRINT '4. Checking ValidationResults table...';
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'ValidationResults')
BEGIN
    PRINT '   [OK] ValidationResults table exists';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('ValidationResults') AND name = 'AllValidationsPassed')
        PRINT '   [OK] AllValidationsPassed column exists';
    ELSE
        PRINT '   [ERROR] AllValidationsPassed column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('ValidationResults') AND name = 'AmountConsistencyPassed')
        PRINT '   [OK] AmountConsistencyPassed column exists';
    ELSE
        PRINT '   [ERROR] AmountConsistencyPassed column missing!';
END
ELSE
BEGIN
    PRINT '   [ERROR] ValidationResults table does not exist!';
END
PRINT '';

-- Check Recommendations table
PRINT '5. Checking Recommendations table...';
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Recommendations')
BEGIN
    PRINT '   [OK] Recommendations table exists';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Recommendations') AND name = 'Type')
        PRINT '   [OK] Type column exists (Approve/Reject)';
    ELSE
        PRINT '   [ERROR] Type column missing!';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Recommendations') AND name = 'Evidence')
        PRINT '   [OK] Evidence column exists';
    ELSE
        PRINT '   [ERROR] Evidence column missing!';
END
ELSE
BEGIN
    PRINT '   [ERROR] Recommendations table does not exist!';
END
PRINT '';

-- Check Users table
PRINT '6. Checking Users table...';
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Users')
BEGIN
    PRINT '   [OK] Users table exists';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Users') AND name = 'Role')
        PRINT '   [OK] Role column exists (Agency=0, ASM=1, HQ=2)';
    ELSE
        PRINT '   [ERROR] Role column missing!';
    
    -- Check if users exist
    DECLARE @userCount INT;
    SELECT @userCount = COUNT(*) FROM Users;
    
    IF @userCount >= 3
        PRINT '   [OK] ' + CAST(@userCount AS VARCHAR) + ' users exist';
    ELSE
        PRINT '   [WARNING] Only ' + CAST(@userCount AS VARCHAR) + ' users exist (need 3: Agency, ASM, HQ)';
END
ELSE
BEGIN
    PRINT '   [ERROR] Users table does not exist!';
END
PRINT '';

-- Summary
PRINT '========================================';
PRINT 'VERIFICATION COMPLETE';
PRINT '========================================';
PRINT '';
PRINT 'Key Tables for Workflow:';
PRINT '  - DocumentPackages: Stores submissions with approval states';
PRINT '  - Documents: Stores PO, Invoice, CostSummary, Photos';
PRINT '  - ConfidenceScores: AI confidence scores per document type';
PRINT '  - ValidationResults: Cross-document validation results';
PRINT '  - Recommendations: AI approval/rejection recommendations';
PRINT '  - Users: Agency, ASM, HQ users';
PRINT '';
PRINT 'Workflow States (DocumentPackages.State):';
PRINT '  0 = Uploaded';
PRINT '  1 = Extracting';
PRINT '  2 = Validating';
PRINT '  3 = Scoring';
PRINT '  4 = Recommending';
PRINT '  5 = PendingASMApproval';
PRINT '  6 = PendingHQApproval';
PRINT '  7 = Approved';
PRINT '  8 = RejectedByASM';
PRINT '  9 = RejectedByHQ';
PRINT '';
GO
