# =============================================
# sync-localdb.ps1
# Applies all pending EF Core migrations to the local SQL Server instance.
# Target: localhost\SQLEXPRESS | Database: BajajDocumentProcessing
# Usage: .\sync-localdb.ps1
# =============================================

$ErrorActionPreference = "Stop"

$apiProject = "backend\src\BajajDocumentProcessing.API"
$infraProject = "backend\src\BajajDocumentProcessing.Infrastructure"
$connectionString = "Server=localhost\SQLEXPRESS;Database=BajajDocumentProcessing;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=true"

Write-Host "=== Bajaj Document Processing - Local DB Sync ===" -ForegroundColor Cyan
Write-Host "Target: localhost\SQLEXPRESS / BajajDocumentProcessing" -ForegroundColor Gray

# Step 1: Restore & build
Write-Host "`n[1/3] Restoring and building solution..." -ForegroundColor Yellow
dotnet build backend\BajajDocumentProcessing.sln --configuration Debug --nologo -v q
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed. Fix compilation errors before syncing DB."; exit 1 }

# Step 2: Show pending migrations
Write-Host "`n[2/3] Checking pending migrations..." -ForegroundColor Yellow
dotnet ef migrations list `
    --project $infraProject `
    --startup-project $apiProject `
    --connection $connectionString `
    --no-build

# Step 3: Apply migrations
Write-Host "`n[3/3] Applying pending migrations..." -ForegroundColor Yellow
dotnet ef database update `
    --project $infraProject `
    --startup-project $apiProject `
    --connection $connectionString `
    --no-build

if ($LASTEXITCODE -ne 0) {
    Write-Error "Migration failed. Check the error above."
    exit 1
}

Write-Host "`n=== Done. Local DB is up to date. ===" -ForegroundColor Green
