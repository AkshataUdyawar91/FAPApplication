# PowerShell script to clear all data from the database
# Run this from the project root directory

Write-Host "Clearing all data from BajajDocumentProcessing database..." -ForegroundColor Yellow

# SQL commands to clear all data
$sqlCommands = @"
USE BajajDocumentProcessing;

-- Disable foreign key constraints
EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';

-- Delete all data
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

-- Re-enable foreign key constraints
EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT ALL';

-- Verify
SELECT 'Users' as TableName, COUNT(*) as RecordCount FROM Users
UNION ALL SELECT 'DocumentPackages', COUNT(*) FROM DocumentPackages
UNION ALL SELECT 'Documents', COUNT(*) FROM Documents
UNION ALL SELECT 'ValidationResults', COUNT(*) FROM ValidationResults
UNION ALL SELECT 'ConfidenceScores', COUNT(*) FROM ConfidenceScores
UNION ALL SELECT 'Recommendations', COUNT(*) FROM Recommendations
UNION ALL SELECT 'Notifications', COUNT(*) FROM Notifications
UNION ALL SELECT 'Conversations', COUNT(*) FROM Conversations
UNION ALL SELECT 'ConversationMessages', COUNT(*) FROM ConversationMessages
UNION ALL SELECT 'AuditLogs', COUNT(*) FROM AuditLogs;
"@

try {
    # Execute SQL commands
    sqlcmd -S "localhost\SQLEXPRESS" -C -Q $sqlCommands
    
    Write-Host "`nDatabase cleared successfully!" -ForegroundColor Green
    Write-Host "All tables are now empty." -ForegroundColor Green
}
catch {
    Write-Host "`nError clearing database: $_" -ForegroundColor Red
    Write-Host "`nAlternative: Run the CLEAR_ALL_DATA.sql file manually in SQL Server Management Studio" -ForegroundColor Yellow
}

Write-Host "`nPress any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
