-- Add missing AadObjectId column to Users table
ALTER TABLE [Users]
ADD [AadObjectId] NVARCHAR(128) NULL;

-- Add unique index (matching EF config)
CREATE UNIQUE INDEX [IX_Users_AadObjectId]
ON [Users] ([AadObjectId])
WHERE [AadObjectId] IS NOT NULL;
