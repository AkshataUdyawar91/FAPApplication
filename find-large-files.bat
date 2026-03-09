@echo off
echo Finding large files on C: drive...
echo This may take a few minutes...
echo.

forfiles /S /M * /C "cmd /c if @fsize GEQ 104857600 echo @path @fsize" 2>nul

echo.
echo Done! Files larger than 100 MB are listed above.
pause
