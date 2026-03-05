# Stop API Process
# This script finds and stops the BajajDocumentProcessing.API process

Write-Host "Finding API process..." -ForegroundColor Cyan

# Get all dotnet processes
$dotnetProcesses = Get-Process dotnet -ErrorAction SilentlyContinue

if ($dotnetProcesses) {
    Write-Host "Found $($dotnetProcesses.Count) dotnet process(es)" -ForegroundColor Yellow
    
    foreach ($process in $dotnetProcesses) {
        try {
            # Try to get the command line to identify which is the API
            $commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($process.Id)").CommandLine
            
            if ($commandLine -like "*BajajDocumentProcessing.API*") {
                Write-Host "`nFound API process:" -ForegroundColor Green
                Write-Host "  PID: $($process.Id)" -ForegroundColor White
                Write-Host "  Command: $commandLine" -ForegroundColor Gray
                
                Write-Host "`nStopping process..." -ForegroundColor Yellow
                Stop-Process -Id $process.Id -Force
                Start-Sleep -Seconds 2
                
                # Verify it stopped
                $stillRunning = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                if ($stillRunning) {
                    Write-Host "  ⚠️  Process still running, trying again..." -ForegroundColor Red
                    Stop-Process -Id $process.Id -Force
                } else {
                    Write-Host "  ✅ Process stopped successfully!" -ForegroundColor Green
                }
            }
        } catch {
            # Ignore errors for processes we can't access
        }
    }
} else {
    Write-Host "No dotnet processes found" -ForegroundColor Yellow
}

Write-Host "`nWaiting for file locks to release..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

Write-Host "✅ Ready to rebuild!" -ForegroundColor Green
Write-Host "`nRun: dotnet build" -ForegroundColor Cyan
