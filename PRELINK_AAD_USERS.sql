-- =============================================
-- Admin Script: Pre-link Azure AD Object IDs to system users
-- Purpose:   Maps Azure AD Object IDs to existing Users for seamless
--            Teams bot authentication (no login prompt needed).
-- Date:      2026-03-19
-- Usage:     1. Get AAD Object IDs from Azure Portal > Entra ID > Users
--               or via Microsoft Graph API: GET /users?$select=id,mail
--            2. Replace the placeholder values below with real AAD Object IDs
--            3. Run this script against the BajajDocumentProcessing database
-- Idempotent: Safe to run multiple times.
-- =============================================

-- Example: Link ASM user by email
-- UPDATE [Users]
-- SET [AadObjectId] = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
-- WHERE [Email] = 'asm@bajaj.com' AND [IsDeleted] = 0;

-- Example: Link Agency user by email
-- UPDATE [Users]
-- SET [AadObjectId] = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'
-- WHERE [Email] = 'agency@bajaj.com' AND [IsDeleted] = 0;

-- =============================================
-- INSTRUCTIONS FOR BULK PRE-LINKING
-- =============================================
-- Option A: Manual — fill in AAD Object IDs from Azure Portal
--
-- Option B: Automated — use Microsoft Graph API to fetch all users,
--           then generate UPDATE statements:
--
--   GET https://graph.microsoft.com/v1.0/users?$select=id,mail,displayName
--
--   For each user returned, generate:
--     UPDATE [Users]
--     SET [AadObjectId] = '<graph_user.id>'
--     WHERE [Email] = '<graph_user.mail>' AND [IsDeleted] = 0;
--
-- Option C: PowerShell script (see PRELINK_AAD_USERS.ps1)
-- =============================================

-- Verify linked users after running:
SELECT [Email], [FullName], [Role], [AadObjectId]
FROM [Users]
WHERE [IsDeleted] = 0
ORDER BY [Role], [Email];
