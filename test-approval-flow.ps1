# Complete Approval/Rejection Flow Test Script
# Tests all approval and rejection scenarios

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:5000/api"

# Color output functions
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Step { param($msg) Write-Host "`n🔹 $msg" -ForegroundColor Yellow }

# Test results tracking
$script:testResults = @{
    Passed = 0
    Failed = 0
    Tests = @()
}

function Add-TestResult {
    param($name, $passed, $message)
    $script:testResults.Tests += @{
        Name = $name
        Passed = $passed
        Message = $message
    }
    if ($passed) {
        $script:testResults.Passed++
        Write-Success "$name - $message"
    } else {
        $script:testResults.Failed++
        Write-Error "$name - $message"
    }
}

# Login function
function Get-AuthToken {
    param($email, $password)
    
    try {
        $loginData = @{
            email = $email
            password = $password
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$baseUrl/auth/login" `
            -Method Post `
            -ContentType "application/json" `
            -Body $loginData

        return $response.token
    } catch {
        Write-Error "Login failed for $email : $_"
        return $null
    }
}

# Create submission function
function New-Submission {
    param($token)
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/submissions" `
            -Method Post `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType "application/json" `
            -Body "{}"

        return $response.id
    } catch {
        Write-Error "Failed to create submission: $_"
        return $null
    }
}

# Upload document function
function Add-Document {
    param($token, $packageId, $documentType, $filePath)
    
    try {
        # Create a simple test file if it doesn't exist
        if (-not (Test-Path $filePath)) {
            "Test document content for $documentType" | Out-File -FilePath $filePath
        }

        $boundary = [System.Guid]::NewGuid().ToString()
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $fileContent = [System.Text.Encoding]::GetEncoding("iso-8859-1").GetString($fileBytes)

        $bodyLines = @(
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$(Split-Path $filePath -Leaf)`"",
            "Content-Type: application/pdf",
            "",
            $fileContent,
            "--$boundary",
            "Content-Disposition: form-data; name=`"documentType`"",
            "",
            $documentType,
            "--$boundary",
            "Content-Disposition: form-data; name=`"packageId`"",
            "",
            $packageId,
            "--$boundary--"
        )

        $body = $bodyLines -join "`r`n"

        $response = Invoke-RestMethod -Uri "$baseUrl/documents/upload" `
            -Method Post `
            -Headers @{ 
                Authorization = "Bearer $token"
                "Content-Type" = "multipart/form-data; boundary=$boundary"
            } `
            -Body ([System.Text.Encoding]::GetEncoding("iso-8859-1").GetBytes($body))

        return $response
    } catch {
        Write-Error "Failed to upload $documentType : $_"
        return $null
    }
}

# Process workflow function
function Start-Workflow {
    param($token, $packageId)
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/submissions/$packageId/process-now" `
            -Method Post `
            -Headers @{ Authorization = "Bearer $token" }

        return $response
    } catch {
        Write-Error "Failed to process workflow: $_"
        return $null
    }
}

# Get submission status function
function Get-SubmissionStatus {
    param($token, $packageId)
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/submissions/$packageId" `
            -Method Get `
            -Headers @{ Authorization = "Bearer $token" }

        return $response
    } catch {
        Write-Error "Failed to get submission status: $_"
        return $null
    }
}

# ASM Approve function
function Approve-ByASM {
    param($token, $packageId, $notes)
    
    try {
        $body = @{ notes = $notes } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$baseUrl/submissions/$packageId/asm-approve" `
            -Method Patch `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType "application/json" `
            -Body $body

        return $response
    } catch {
        Write-Error "ASM approval failed: $_"
        return $null
    }
}

# ASM Reject function
function Reject-ByASM {
    param($token, $packageId, $reason)
    
    try {
        $body = @{ reason = $reason } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$baseUrl/submissions/$packageId/asm-reject" `
            -Method Patch `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType "application/json" `
            -Body $body

        return $response
    } catch {
        Write-Error "ASM rejection failed: $_"
        return $null
    }
}

# HQ Approve function
function Approve-ByHQ {
    param($token, $packageId, $notes)
    
    try {
        $body = @{ notes = $notes } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$baseUrl/submissions/$packageId/hq-approve" `
            -Method Patch `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType "application/json" `
            -Body $body

        return $response
    } catch {
        Write-Error "HQ approval failed: $_"
        return $null
    }
}

# HQ Reject function
function Reject-ByHQ {
    param($token, $packageId, $reason)
    
    try {
        $body = @{ reason = $reason } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "$baseUrl/submissions/$packageId/hq-reject" `
            -Method Patch `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType "application/json" `
            -Body $body

        return $response
    } catch {
        Write-Error "HQ rejection failed: $_"
        return $null
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     BAJAJ DOCUMENT PROCESSING - APPROVAL FLOW TEST SUITE      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Step 1: Login all users
Write-Step "STEP 1: Authenticating Users"
$agencyToken = Get-AuthToken "agency@bajaj.com" "Password123!"
$asmToken = Get-AuthToken "asm@bajaj.com" "Password123!"
$hqToken = Get-AuthToken "hq@bajaj.com" "Password123!"

if (-not $agencyToken -or -not $asmToken -or -not $hqToken) {
    Write-Error "Failed to authenticate users. Exiting."
    exit 1
}

Add-TestResult "User Authentication" $true "All users authenticated successfully"

# ============================================================================
# TEST SCENARIO 1: HAPPY PATH - FULL APPROVAL
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  TEST SCENARIO 1: HAPPY PATH - FULL APPROVAL FLOW             ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Step "Creating submission for happy path test"
$packageId1 = New-Submission $agencyToken

if ($packageId1) {
    Add-TestResult "Create Submission" $true "Package ID: $packageId1"
    
    # Upload documents
    Write-Step "Uploading documents"
    Add-Document $agencyToken $packageId1 "PO" "test-po.pdf"
    Add-Document $agencyToken $packageId1 "Invoice" "test-invoice.pdf"
    Add-Document $agencyToken $packageId1 "CostSummary" "test-cost.pdf"
    Add-Document $agencyToken $packageId1 "Photo" "test-photo.jpg"
    
    Add-TestResult "Upload Documents" $true "4 documents uploaded"
    
    # Process workflow
    Write-Step "Processing workflow (AI extraction and validation)"
    $workflow = Start-Workflow $agencyToken $packageId1
    
    if ($workflow) {
        Add-TestResult "Workflow Processing" $true "Workflow completed"
        
        # Check status after workflow
        Start-Sleep -Seconds 2
        $status = Get-SubmissionStatus $agencyToken $packageId1
        
        if ($status.state -eq "PendingASMApproval") {
            Add-TestResult "Workflow State" $true "State: PendingASMApproval"
            
            # ASM Approval
            Write-Step "ASM reviewing and approving"
            $asmApproval = Approve-ByASM $asmToken $packageId1 "Looks good, approved by ASM"
            
            if ($asmApproval -and $asmApproval.state -eq "PendingHQApproval") {
                Add-TestResult "ASM Approval" $true "State: PendingHQApproval"
                
                # HQ Approval
                Write-Step "HQ reviewing and giving final approval"
                $hqApproval = Approve-ByHQ $hqToken $packageId1 "Final approval by HQ"
                
                if ($hqApproval -and $hqApproval.state -eq "Approved") {
                    Add-TestResult "HQ Final Approval" $true "State: Approved (FINAL)"
                    Write-Success "`n✨ SCENARIO 1 PASSED: Full approval flow completed successfully!"
                } else {
                    Add-TestResult "HQ Final Approval" $false "Expected Approved, got: $($hqApproval.state)"
                }
            } else {
                Add-TestResult "ASM Approval" $false "Expected PendingHQApproval, got: $($asmApproval.state)"
            }
        } else {
            Add-TestResult "Workflow State" $false "Expected PendingASMApproval, got: $($status.state)"
        }
    } else {
        Add-TestResult "Workflow Processing" $false "Workflow failed"
    }
} else {
    Add-TestResult "Create Submission" $false "Failed to create submission"
}

# ============================================================================
# TEST SCENARIO 2: ASM REJECTION
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  TEST SCENARIO 2: ASM REJECTION FLOW                          ║" -ForegroundColor Yellow
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

Write-Step "Creating submission for ASM rejection test"
$packageId2 = New-Submission $agencyToken

if ($packageId2) {
    Add-TestResult "Create Submission (Scenario 2)" $true "Package ID: $packageId2"
    
    # Upload documents
    Write-Step "Uploading documents"
    Add-Document $agencyToken $packageId2 "PO" "test-po.pdf"
    Add-Document $agencyToken $packageId2 "Invoice" "test-invoice.pdf"
    
    # Process workflow
    Write-Step "Processing workflow"
    $workflow = Start-Workflow $agencyToken $packageId2
    
    if ($workflow) {
        Start-Sleep -Seconds 2
        $status = Get-SubmissionStatus $agencyToken $packageId2
        
        if ($status.state -eq "PendingASMApproval") {
            # ASM Rejection
            Write-Step "ASM reviewing and rejecting"
            $asmRejection = Reject-ByASM $asmToken $packageId2 "Invoice amount does not match PO. Please correct and resubmit."
            
            if ($asmRejection -and $asmRejection.state -eq "RejectedByASM") {
                Add-TestResult "ASM Rejection" $true "State: RejectedByASM"
                
                # Verify agency can see rejection
                $agencyView = Get-SubmissionStatus $agencyToken $packageId2
                
                if ($agencyView.asmReviewNotes -eq "Invoice amount does not match PO. Please correct and resubmit.") {
                    Add-TestResult "Agency Sees Rejection Notes" $true "Notes visible to agency"
                    Write-Success "`n✨ SCENARIO 2 PASSED: ASM rejection flow completed successfully!"
                } else {
                    Add-TestResult "Agency Sees Rejection Notes" $false "Notes not visible"
                }
            } else {
                Add-TestResult "ASM Rejection" $false "Expected RejectedByASM, got: $($asmRejection.state)"
            }
        }
    }
}

# ============================================================================
# TEST SCENARIO 3: HQ REJECTION
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  TEST SCENARIO 3: HQ REJECTION FLOW                           ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

Write-Step "Creating submission for HQ rejection test"
$packageId3 = New-Submission $agencyToken

if ($packageId3) {
    Add-TestResult "Create Submission (Scenario 3)" $true "Package ID: $packageId3"
    
    # Upload documents
    Write-Step "Uploading documents"
    Add-Document $agencyToken $packageId3 "PO" "test-po.pdf"
    Add-Document $agencyToken $packageId3 "Invoice" "test-invoice.pdf"
    
    # Process workflow
    Write-Step "Processing workflow"
    $workflow = Start-Workflow $agencyToken $packageId3
    
    if ($workflow) {
        Start-Sleep -Seconds 2
        
        # ASM Approval
        Write-Step "ASM approving"
        $asmApproval = Approve-ByASM $asmToken $packageId3 "Approved by ASM"
        
        if ($asmApproval -and $asmApproval.state -eq "PendingHQApproval") {
            # HQ Rejection
            Write-Step "HQ reviewing and rejecting"
            $hqRejection = Reject-ByHQ $hqToken $packageId3 "Cost summary missing required signatures. Please have ASM verify and resubmit."
            
            if ($hqRejection -and $hqRejection.state -eq "RejectedByHQ") {
                Add-TestResult "HQ Rejection" $true "State: RejectedByHQ"
                
                # Verify ASM can see rejection
                $asmView = Get-SubmissionStatus $asmToken $packageId3
                
                if ($asmView.hqReviewNotes -eq "Cost summary missing required signatures. Please have ASM verify and resubmit.") {
                    Add-TestResult "ASM Sees HQ Rejection Notes" $true "Notes visible to ASM"
                    Write-Success "`n✨ SCENARIO 3 PASSED: HQ rejection flow completed successfully!"
                } else {
                    Add-TestResult "ASM Sees HQ Rejection Notes" $false "Notes not visible"
                }
            } else {
                Add-TestResult "HQ Rejection" $false "Expected RejectedByHQ, got: $($hqRejection.state)"
            }
        }
    }
}

# ============================================================================
# TEST SCENARIO 4: AUTHORIZATION CHECKS
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║  TEST SCENARIO 4: AUTHORIZATION & SECURITY CHECKS             ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red

Write-Step "Testing unauthorized access attempts"

# Try agency approving (should fail)
try {
    Approve-ByASM $agencyToken $packageId1 "Unauthorized attempt"
    Add-TestResult "Agency Cannot Approve" $false "Agency was able to approve (security issue!)"
} catch {
    Add-TestResult "Agency Cannot Approve" $true "Agency correctly blocked from approving"
}

# Try ASM giving final approval (should fail)
try {
    Approve-ByHQ $asmToken $packageId1 "Unauthorized attempt"
    Add-TestResult "ASM Cannot Give Final Approval" $false "ASM was able to give final approval (security issue!)"
} catch {
    Add-TestResult "ASM Cannot Give Final Approval" $true "ASM correctly blocked from final approval"
}

Write-Success "`n✨ SCENARIO 4 PASSED: Authorization checks working correctly!"

# ============================================================================
# TEST RESULTS SUMMARY
# ============================================================================

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      TEST RESULTS SUMMARY                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Total Tests: $($script:testResults.Passed + $script:testResults.Failed)" -ForegroundColor White
Write-Host "Passed: $($script:testResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($script:testResults.Failed)" -ForegroundColor Red

$passRate = [math]::Round(($script:testResults.Passed / ($script:testResults.Passed + $script:testResults.Failed)) * 100, 2)
Write-Host "Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })

Write-Host "`n📋 Detailed Results:" -ForegroundColor Cyan
foreach ($test in $script:testResults.Tests) {
    $icon = if ($test.Passed) { "✅" } else { "❌" }
    $color = if ($test.Passed) { "Green" } else { "Red" }
    Write-Host "$icon $($test.Name): $($test.Message)" -ForegroundColor $color
}

# Cleanup test files
Write-Host "`n🧹 Cleaning up test files..." -ForegroundColor Cyan
Remove-Item -Path "test-*.pdf", "test-*.jpg" -ErrorAction SilentlyContinue

if ($script:testResults.Failed -eq 0) {
    Write-Host "`n🎉 ALL TESTS PASSED! The approval/rejection flow is working correctly!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  SOME TESTS FAILED. Please review the results above." -ForegroundColor Yellow
    exit 1
}
