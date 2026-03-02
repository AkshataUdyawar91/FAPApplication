# Login Credentials - Bajaj Document Processing System

## ✅ CORRECT CREDENTIALS

All test users have the same password: **`Password123!`**

| Role | Email | Password | Access Level |
|------|-------|----------|--------------|
| **Agency** | `agency@bajaj.com` | `Password123!` | Submit documents, track status |
| **ASM** | `asm@bajaj.com` | `Password123!` | Review & approve submissions |
| **HQ** | `hq@bajaj.com` | `Password123!` | View analytics & reports |

## 🔐 Password Details

- Password: `Password123!`
- Must include:
  - Capital 'P'
  - Numbers '123'
  - Exclamation mark '!'
- Case-sensitive

## 🚀 System Status

### Backend API
- ✅ Running on http://localhost:5000
- ✅ Swagger UI: http://localhost:5000/swagger
- ✅ Authentication working correctly
- ✅ Database connected

### Flutter Frontend
- The simplified app now includes:
  - ✅ Show/hide password toggle (eye icon)
  - ✅ Better error messages
  - ✅ Correct credentials displayed on login page
  - ✅ Debug logging for troubleshooting

## 📱 How to Login

1. Open the Flutter app at http://localhost:8080
2. Enter email: `agency@bajaj.com`
3. Enter password: `Password123!` (use the eye icon to verify you typed it correctly)
4. Click Login

## 🔍 Troubleshooting

### If login still fails:

1. **Check the password carefully**:
   - Use the eye icon to show the password
   - Make sure it's exactly: `Password123!`
   - No extra spaces before or after

2. **Check browser console** (F12):
   - Look for error messages
   - Check if the API call is being made

3. **Verify backend is running**:
   ```bash
   curl http://localhost:5000/api/health
   ```

4. **Test login via curl**:
   ```bash
   curl -X POST http://localhost:5000/api/auth/login -H "Content-Type: application/json" -d "{\"email\":\"agency@bajaj.com\",\"password\":\"Password123!\"}"
   ```

## 🎯 What Happens After Login

Once logged in successfully, you'll see:
- Welcome message with your name
- Feature cards for:
  - Upload Documents
  - View Submissions
  - Analytics
  - Chat Assistant
- Backend connection status indicator

## 📝 Notes

- Passwords are hashed using BCrypt with work factor 12
- JWT tokens expire after 30 minutes
- All users are active and ready to use
- Database was seeded automatically on first run

## 🔄 Recent Fixes

1. ✅ Fixed JWT configuration mismatch (`Secret` → `SecretKey`)
2. ✅ Fixed expiration time configuration (`ExpirationMinutes` → `ExpiryMinutes`)
3. ✅ Added show/hide password toggle in Flutter
4. ✅ Improved error handling and logging
5. ✅ Backend restarted with correct configuration

---

**Current Status**: Both backend and frontend are ready. Login should work with `Password123!`
