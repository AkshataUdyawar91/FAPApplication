# Flutter Execution Policy Fix

## Problem
Your Windows system has a strict PowerShell execution policy (AllSigned) that prevents Flutter from running because Flutter's internal scripts are not digitally signed.

## Current Status
- ✅ Backend API: Running successfully on http://localhost:5000
- ❌ Flutter Frontend: Blocked by PowerShell execution policy

## Solution Options

### Option 1: Fix PowerShell Execution Policy (Recommended)

You need to change the execution policy to allow Flutter to run. Run PowerShell **as Administrator** and execute:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

This will allow locally created scripts and signed remote scripts to run.

After setting this, you can run Flutter:

```bash
cd frontend
flutter run -d chrome --web-port=8080
```

### Option 2: Use the Simplified Flutter App

The simplified `main.dart` is ready and doesn't require code generation. Once you fix the execution policy, it will work immediately.

### Option 3: Use Backend API Only

The backend is fully functional. You can:
- Use Swagger UI: http://localhost:5000/swagger
- Build a different frontend (React, Angular, etc.)
- Use Postman or any HTTP client to test the API

## Test Credentials

Once Flutter is running, you can login with:
- Email: `agency@bajaj.com`
- Password: `password`

Other test users:
- ASM: `asm@bajaj.com` / `password`
- HQ: `hq@bajaj.com` / `password`

## What Will Work After Fix

The simplified Flutter app will:
1. Show a login page
2. Connect to the backend API at http://localhost:5000
3. Authenticate users
4. Display a home page with feature cards
5. Show that the backend connection is working

## Next Steps After Flutter Runs

If you want the full feature set (document upload, analytics, chat), you'll need to:
1. Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`
2. Fix theme configuration in `lib/core/theme/app_theme.dart`
3. Complete router configuration

But the simplified app is enough to verify the system is working end-to-end.

## Current Running Processes

- Backend API (Process ID: 4): http://localhost:5000 ✅
- Flutter (Process ID: 9): Blocked by execution policy ❌

## How to Check Your Execution Policy

```powershell
Get-ExecutionPolicy -List
```

You'll likely see:
```
Scope          ExecutionPolicy
-----          ---------------
MachinePolicy  AllSigned
UserPolicy     Undefined
Process        Undefined
CurrentUser    Undefined
LocalMachine   Undefined
```

The `MachinePolicy` or `UserPolicy` set to `AllSigned` is blocking Flutter.
