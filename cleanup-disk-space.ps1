# Clean up disk space for Flutter development
# Run as Administrator for best results

Write-Host "=== Cleaning Disk Space ===" -ForegroundColor Cyan
Write-Host ""

# 1. Clean Flutter build cache
Write-Host "1. Cleaning Flutter build cache..." -ForegroundColor Yellow
cd frontend
if (Test-Path "build") {
    $buildSize = (Get-ChildItem build -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "   Removing build folder ($([math]::Round($buildSize, 2)) MB)..." -ForegroundColor Gray
    Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
    Write-Host "   ✓ Build folder removed" -ForegroundColor Green
}

if (Test-Path ".dart_tool") {
    $dartToolSize = (Get-ChildItem .dart_tool -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "   Removing .dart_tool folder ($([math]::Round($dartToolSize, 2)) MB)..." -ForegroundColor Gray
    Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
    Write-Host "   ✓ .dart_tool folder removed" -ForegroundColor Green
}
cd ..

# 2. Clean .NET build artifacts
Write-Host ""
Write-Host "2. Cleaning .NET build artifacts..." -ForegroundColor Yellow
cd backend
if (Test-Path "src/BajajDocumentProcessing.API/bin") {
    Remove-Item -Recurse -Force src/BajajDocumentProcessing.API/bin -ErrorAction SilentlyContinue
    Write-Host "   ✓ API bin folder removed" -ForegroundColor Green
}
if (Test-Path "src/BajajDocumentProcessing.API/obj") {
    Remove-Item -Recurse -Force src/BajajDocumentProcessing.API/obj -ErrorAction SilentlyContinue
    Write-Host "   ✓ API obj folder removed" -ForegroundColor Green
}
cd ..

# 3. Clean Windows Temp folder
Write-Host ""
Write-Host "3. Cleaning Windows Temp folder..." -ForegroundColor Yellow
$tempPath = $env:TEMP
$tempSize = (Get-ChildItem $tempPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "   Temp folder size: $([math]::Round($tempSize, 2)) MB" -ForegroundColor Gray

# Clean Flutter temp files specifically
$flutterTemp = Join-Path $tempPath "flutter_tools.*"
Get-ChildItem $tempPath -Filter "flutter_tools.*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "   Removing $_..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
}
Write-Host "   ✓ Flutter temp files removed" -ForegroundColor Green

# 4. Run Flutter clean
Write-Host ""
Write-Host "4. Running flutter clean..." -ForegroundColor Yellow
cd frontend
flutter clean
cd ..
Write-Host "   ✓ Flutter clean completed" -ForegroundColor Green

# 5. Check disk space
Write-Host ""
Write-Host "5. Checking disk space..." -ForegroundColor Yellow
$drive = Get-PSDrive C
$freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
$usedSpaceGB = [math]::Round($drive.Used / 1GB, 2)
$totalSpaceGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)

Write-Host "   C: Drive Status:" -ForegroundColor Cyan
Write-Host "   Total: $totalSpaceGB GB" -ForegroundColor Gray
Write-Host "   Used: $usedSpaceGB GB" -ForegroundColor Gray
Write-Host "   Free: $freeSpaceGB GB" -ForegroundColor $(if ($freeSpaceGB -lt 5) { "Red" } elseif ($freeSpaceGB -lt 10) { "Yellow" } else { "Green" })

if ($freeSpaceGB -lt 5) {
    Write-Host ""
    Write-Host "   ⚠ WARNING: Less than 5 GB free space!" -ForegroundColor Red
    Write-Host "   You may need to:" -ForegroundColor Yellow
    Write-Host "   - Delete large files or move them to another drive" -ForegroundColor Yellow
    Write-Host "   - Run Disk Cleanup (cleanmgr.exe)" -ForegroundColor Yellow
    Write-Host "   - Empty Recycle Bin" -ForegroundColor Yellow
    Write-Host "   - Uninstall unused programs" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Cyan
