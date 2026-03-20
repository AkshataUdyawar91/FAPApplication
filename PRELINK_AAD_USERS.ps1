# =============================================
# Admin Script: Bulk pre-link Azure AD Object IDs to system users
# Purpose:   Queries Microsoft Graph API for all users in the tenant,
#            matches by email, and updates the Users table with AadObjectId.
# Prerequisites:
#   - Install-Module Microsoft.Graph.Users
#   - Azure AD app registration with User.Read.All permission (application)
#   - Or run as signed-in admin with Connect-MgGraph -Scopes "User.Read.All"
# Usage:     .\PRELINK_AAD_USERS.ps1
# =============================================

param(
    [string]$SqlServer = "localhost\SQLEXPRESS",
    [string]$Database = "BajajDocumentProcessing"
)

# 1. Connect to Microsoft Graph (interactive sign-in)
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Read.All"

# 2. Get all Azure AD users with email
Write-Host "Fetching Azure AD users..." -ForegroundColor Cyan
$aadUsers = Get-MgUser -All -Property Id, Mail, DisplayName, UserPrincipalName |
    Where-Object { $_.Mail -ne $null }

Write-Host "Found $($aadUsers.Count) Azure AD users with email addresses" -ForegroundColor Green

# 3. Get system users from database
$connectionString = "Server=$SqlServer;Database=$Database;Trusted_Connection=True;TrustServerCertificate=true"
$systemUsers = Invoke-Sqlcmd -ConnectionString $connectionString -Query @"
    SELECT [Id], [Email], [FullName], [Role], [AadObjectId]
    FROM [Users]
    WHERE [IsDeleted] = 0 AND [IsActive] = 1
"@

Write-Host "Found $($systemUsers.Count) active system users" -ForegroundColor Green

# 4. Match and update
$matched = 0
$skipped = 0
$notFound = 0

foreach ($sysUser in $systemUsers) {
    if ($sysUser.AadObjectId) {
        Write-Host "  SKIP $($sysUser.Email) — already linked to $($sysUser.AadObjectId)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    $aadMatch = $aadUsers | Where-Object {
        $_.Mail -ieq $sysUser.Email -or $_.UserPrincipalName -ieq $sysUser.Email
    } | Select-Object -First 1

    if ($aadMatch) {
        $updateQuery = @"
            UPDATE [Users]
            SET [AadObjectId] = '$($aadMatch.Id)'
            WHERE [Id] = '$($sysUser.Id)' AND [IsDeleted] = 0
"@
        Invoke-Sqlcmd -ConnectionString $connectionString -Query $updateQuery
        Write-Host "  LINKED $($sysUser.Email) -> $($aadMatch.Id)" -ForegroundColor Green
        $matched++
    }
    else {
        Write-Host "  NOT FOUND in AAD: $($sysUser.Email)" -ForegroundColor Yellow
        $notFound++
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "  Linked:    $matched"
Write-Host "  Skipped:   $skipped (already linked)"
Write-Host "  Not found: $notFound"
Write-Host ""

Disconnect-MgGraph
