# Quick Start Guide - Enhanced Validation Report Testing

## 🚀 Simple Startup Instructions

### Option 1: Using Batch Files (Easiest)

**Terminal 1 - Start Backend:**
```bash
.\start-backend.bat
```

**Terminal 2 - Start Frontend:**
```bash
.\start-frontend.bat
```

### Option 2: Manual Commands

**Terminal 1 - Start Backend:**
```bash
cd backend
dotnet run
```

**Terminal 2 - Start Frontend:**
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## ✅ What to Expect

### Backend Terminal
You should see:
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5000
      Now listening on: https://localhost:7001
```

### Frontend Terminal
You should see:
```
Launching lib/main.dart on Chrome in debug mode...
Building application for the web...
...
Application finished.
```

Then your browser will open automatically.

## 🧪 Testing the Feature

1. **Login** as ASM user:
   - Email: `asm@bajaj.com`
   - Password: `ASM@123`

2. **Find a submission** in the dashboard

3. **Click the "View AI Report" button** (📊 icon or button)

4. **Verify** the validation report displays with:
   - Confidence score
   - Validation categories
   - AI recommendation
   - Detailed evidence

## ❌ Troubleshooting

### Error: "Cannot find path backend\backend"
**Cause**: You're in the wrong directory or using an incorrect command

**Solution**: Make sure you're in the project root directory:
```bash
# Check current directory
pwd

# Should show: .../FAPLatest

# If not, navigate to project root
cd "C:\Users\audyawar\OneDrive - Deloitte (O365D)\Documents\KIRO\FAPLatest"
```

### Error: "dotnet command not found"
**Solution**: Install .NET 8 SDK from https://dotnet.microsoft.com/download

### Error: "flutter command not found"
**Solution**: Install Flutter from https://flutter.dev/docs/get-started/install

### Error: "Backend not responding"
**Solution**: 
1. Check if backend is running (Terminal 1 should show "Now listening...")
2. Try accessing http://localhost:5000/api/health in browser
3. Check for port conflicts (kill any process using port 5000)

### Error: "Failed to load validation report"
**Solution**:
1. Ensure backend is running
2. Check browser console (F12) for errors
3. Verify you're logged in as ASM or HQ user

## 📁 Project Structure

```
FAPLatest/
├── backend/              ← Backend API (.NET 8)
│   ├── src/
│   │   └── BajajDocumentProcessing.API/
│   └── BajajDocumentProcessing.sln
├── frontend/             ← Frontend UI (Flutter)
│   ├── lib/
│   └── pubspec.yaml
├── start-backend.bat     ← Use this to start backend
├── start-frontend.bat    ← Use this to start frontend
└── START_HERE.md         ← This file
```

## 🎯 Quick Test Checklist

- [ ] Backend starts without errors
- [ ] Frontend starts and opens browser
- [ ] Can login as ASM user
- [ ] Dashboard shows submissions
- [ ] "View AI Report" button is visible
- [ ] Clicking button opens dialog
- [ ] Validation report displays correctly
- [ ] Can close dialog
- [ ] No console errors

## 📞 Need Help?

Check these files:
- `TESTING_GUIDE.md` - Detailed testing instructions
- `TESTING_CHECKLIST.md` - Systematic testing checklist
- `README_TESTING.md` - Testing overview

## 🎉 Success!

When you see the validation report dialog with confidence scores, validation categories, and AI recommendations, the feature is working correctly!

**Next**: Follow `TESTING_GUIDE.md` for comprehensive testing.
