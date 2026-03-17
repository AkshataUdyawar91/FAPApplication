-- Drop and recreate database
USE master;
GO

-- Kill all connections to the database
ALTER DATABASE BajajDocumentProcessing SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

DROP DATABASE BajajDocumentProcessing;
GO

CREATE DATABASE BajajDocumentProcessing;
GO

PRINT 'Database recreated successfully';
