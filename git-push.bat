@echo off
echo Setting up Git repository...

REM Remove any nested .git folders
if exist "backend\.git" rmdir /s /q "backend\.git"
if exist "frontend\.git" rmdir /s /q "frontend\.git"

REM Initialize git in root if not already initialized
if not exist ".git" (
    git init
    echo Git repository initialized
)

REM Configure git user
git config user.name "Akshata Udyawar"
git config user.email "audyawar@deloitte.com"

REM Add remote if not exists
git remote remove origin 2>nul
git remote add origin https://github.com/AkshataUdyawar91/FAPApplication.git

REM Add all files
echo Adding files...
git add .

REM Commit
echo Committing changes...
git commit -m "Initial commit: Bajaj Document Processing System with AI-powered validation"

REM Push to main branch
echo Pushing to GitHub...
git branch -M main
git push -u origin main --force

echo Done!
pause
