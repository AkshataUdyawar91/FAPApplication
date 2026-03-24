# =============================================
# sync-localdb.ps1
# Applies all pending EF Core migrations to the local SQL Server instance.
# Target: localhost\SQLEXPRESS | Database: BajajDocumentProcessing
# Usage: .\sync-localdb.ps1
# =============================================

$ErrorActionPreference = "Stop"

$apiProject    = "backend\src\BajajDocumentProcessing.API"
$infraProject  = "backend\src\BajajDocumentProcessing.Infrastructure"
$connectionString = "Server=localhost\SQLEXPRESS;Database=BajajDocumentProcessing;Trusted_Connection=True;MultipleActiveResultSets=true;TrustServerCertificate=true"

Write-Host "=== Bajaj Document Processing - Local DB Sync ===" -ForegroundColor Cyan
Write-Host "Target: localhost\SQLEXPRESS / BajajDocumentProcessing" -ForegroundColor Gray

# Pre-check: ensure dotnet-ef tool is available
if (-not (dotnet ef --version 2>$null)) {
    Write-Host "`n[ERROR] dotnet-ef tool not found. Install it with:" -ForegroundColor Red
    Write-Host "  dotnet tool install --global dotnet-ef" -ForegroundColor Yellow
    exit 1
}

# Pre-check: verify SQL Server is reachable
Write-Host "`n[0/3] Verifying SQL Server connectivity..." -ForegroundColor Yellow
try {
    $conn = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $conn.Open()
    $conn.Close()
    Write-Host "      SQL Server reachable." -ForegroundColor Green
} catch {
    Write-Host "`n[ERROR] Cannot connect to localhost\SQLEXPRESS." -ForegroundColor Red
    Write-Host "        Ensure SQL Server Express is running (services.msc -> SQL Server (SQLEXPRESS))." -ForegroundColor Yellow
    exit 1
}

# Step 1: Build
Write-Host "`n[1/3] Building solution..." -ForegroundColor Yellow
dotnet build backend\BajajDocumentProcessing.sln --configuration Debug --nologo -v q
if ($LASTEXITCODE -ne 0) { Write-Host "`n[ERROR] Build failed. Fix compilation errors before syncing DB." -ForegroundColor Red; exit 1 }

# Step 2: Show pending migrations
Write-Host "`n[2/3] Checking migrations..." -ForegroundColor Yellow
dotnet ef migrations list `
    --project $infraProject `
    --startup-project $apiProject `
    --connection $connectionString `
    --no-build
if ($LASTEXITCODE -ne 0) { Write-Host "`n[ERROR] Could not list migrations." -ForegroundColor Red; exit 1 }

# Step 3: Apply migrations
Write-Host "`n[3/3] Applying pending migrations..." -ForegroundColor Yellow
dotnet ef database update `
    --project $infraProject `
    --startup-project $apiProject `
    --connection $connectionString `
    --no-build

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Migration failed. Check the error above." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Done. Local DB is up to date. ===" -ForegroundColor Green
