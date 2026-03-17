@echo off
REM Check submission state in database

set SERVER=localhost\SQLEXPRESS
set DATABASE=BajajDocumentProcessing

echo.
echo ========================================
echo  CHECK SUBMISSION STATE
echo ========================================
echo.

echo Checking all submissions in database...
echo.

sqlcmd -S %SERVER% -d %DATABASE% -C -Q "SELECT Id, State, CASE State WHEN 0 THEN 'Uploaded' WHEN 1 THEN 'Extracting' WHEN 2 THEN 'Validating' WHEN 3 THEN 'Scoring' WHEN 4 THEN 'Recommending' WHEN 5 THEN 'PendingASMApproval' WHEN 6 THEN 'PendingHQApproval' WHEN 7 THEN 'Approved' WHEN 8 THEN 'RejectedByASM' WHEN 9 THEN 'RejectedByHQ' ELSE 'Unknown' END AS StateName, CreatedAt, UpdatedAt FROM DocumentPackages ORDER BY CreatedAt DESC;"

echo.
echo.
echo State Values:
echo   0 = Uploaded (workflow not started)
echo   1 = Extracting (AI extracting data)
echo   2 = Validating (AI validating)
echo   3 = Scoring (AI scoring confidence)
echo   4 = Recommending (AI generating recommendation)
echo   5 = PendingASMApproval (ready for ASM review)
echo   6 = PendingHQApproval (ready for HQ review)
echo   7 = Approved (final approval)
echo   8 = RejectedByASM (rejected by ASM)
echo   9 = RejectedByHQ (rejected by HQ)
echo.
echo If State = 0 (Uploaded), the workflow hasn't started yet.
echo The workflow should automatically move it to state 5 (PendingASMApproval).
echo.
pause
