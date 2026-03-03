-- Clear All Data from Bajaj Document Processing Database
-- Run this script in SQL Server Management Studio or Azure Data Studio

USE BajajDocumentProcessing;
GO

-- Disable all foreign key constraints
EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';
GO

-- Delete all data from all tables
DELETE FROM ConversationMessages;
DELETE FROM Conversations;
DELETE FROM AuditLogs;
DELETE FROM Notifications;
DELETE FROM Recommendations;
DELETE FROM ConfidenceScores;
DELETE FROM ValidationResults;
DELETE FROM Documents;
DELETE FROM DocumentPackages;
DELETE FROM Users;
GO

-- Re-enable all foreign key constraints
EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL';
GO

-- Reset identity columns (if any)
-- DBCC CHECKIDENT ('Users', RESEED, 0);
-- DBCC CHECKIDENT ('DocumentPackages', RESEED, 0);

-- Verify all tables are empty
SELECT 'Users' as TableName, COUNT(*) as RecordCount FROM Users
UNION ALL
SELECT 'DocumentPackages', COUNT(*) FROM DocumentPackages
UNION ALL
SELECT 'Documents', COUNT(*) FROM Documents
UNION ALL
SELECT 'ValidationResults', COUNT(*) FROM ValidationResults
UNION ALL
SELECT 'ConfidenceScores', COUNT(*) FROM ConfidenceScores
UNION ALL
SELECT 'Recommendations', COUNT(*) FROM Recommendations
UNION ALL
SELECT 'Notifications', COUNT(*) FROM Notifications
UNION ALL
SELECT 'Conversations', COUNT(*) FROM Conversations
UNION ALL
SELECT 'ConversationMessages', COUNT(*) FROM ConversationMessages
UNION ALL
SELECT 'AuditLogs', COUNT(*) FROM AuditLogs;
GO

PRINT 'All data cleared successfully!';
PRINT 'Database is now empty and ready for production use.';
GO
