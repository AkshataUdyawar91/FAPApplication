# Authentication and Authorization Setup

## Overview

Task 3 has been completed successfully. The system now has a complete authentication and authorization implementation with JWT tokens, password hashing, and role-based access control.

## What Was Implemented

### 1. Authentication Service (Task 3.1)
- **JWT Token Generation**: Tokens with 30-minute expiration
- **Password Hashing**: BCrypt with 12 rounds minimum
- **Login Endpoint**: POST /api/auth/login
- **Token Validation**: Validates JWT tokens with proper claims

**Key Features**:
- Secure password hashing with BCrypt
- JWT tokens with user ID, email, and role claims
- Configurable token expiration (default: 30 minutes)
- Last login timestamp tracking

### 2. Authorization Middleware (Task 3.2)
- **JWT Bearer Authentication**: Configured in Program.cs
- **Authorization Policies**:
  - `AgencyOnly`: Requires Agency role
  - `ASMOnly`: Requires ASM role
  - `HQOnly`: Requires HQ role
  - `ASMOrHQ`: Requires ASM or HQ role

**Swagger Integration**:
- Bearer token authentication in Swagger UI
- Test authentication directly from Swagger

### 3. Session Management (Task 3.3)
- **Token Expiration**: 30 minutes (configurable)
- **Token Refresh**: POST /api/auth/refresh endpoint
- **Automatic Expiration**: Tokens expire and require re-authentication
- **Refresh Mechanism**: Generate new token from expired token

### 4. Property-Based Tests
All tests use FsCheck with 100 test iterations:

**Password Hashing Properties (Property 77)**:
- Hash is not reversible
- Correct password verifies successfully
- Wrong password is rejected
- Same password produces different hashes (salt)
- Minimum 12 rounds enforced

**Role-Based Authorization Properties (Property 50)**:
- Generated tokens contain correct role
- Tokens contain all required claims (user ID, email, role)
- Each role (Agency, ASM, HQ) has correct access
- Tokens can be validated

**Session Expiration Properties (Property 52)**:
- Tokens have expiration claim
- Tokens expire after 30 minutes
- Expired tokens fail validation
- Valid tokens pass validation
- Custom expiration works correctly
- Token refresh generates new token with new expiration

## API Endpoints

### POST /api/auth/login
Login with email and password.

**Request**:
```json
{
  "email": "agency@bajaj.com",
  "password": "Password123!"
}
```

**Response**:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "email": "agency@bajaj.com",
  "fullName": "Agency User",
  "role": 1,
  "expiresAt": "2024-01-01T12:30:00Z"
}
```

### POST /api/auth/logout
Logout (client-side token removal).

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "message": "Logged out successfully"
}
```

### GET /api/auth/me
Get current user information.

**Headers**: `Authorization: Bearer {token}`

**Response**:
```json
{
  "userId": "guid",
  "email": "agency@bajaj.com",
  "role": "Agency"
}
```

### POST /api/auth/refresh
Refresh expired token.

**Request**:
```json
{
  "token": "expired-token"
}
```

**Response**:
```json
{
  "token": "new-token",
  "email": "agency@bajaj.com",
  "fullName": "Agency User",
  "role": 1,
  "expiresAt": "2024-01-01T13:00:00Z"
}
```

## Test Users

Three test users are seeded in the database:

| Email | Password | Role | Description |
|-------|----------|------|-------------|
| agency@bajaj.com | Password123! | Agency | Can submit documents |
| asm@bajaj.com | Password123! | ASM | Can approve/reject submissions |
| hq@bajaj.com | Password123! | HQ | Can view analytics |

## Configuration

Update `appsettings.json` to configure JWT:

```json
{
  "Jwt": {
    "Secret": "YourSuperSecretKeyThatIsAtLeast32CharactersLong!",
    "Issuer": "BajajDocumentProcessing",
    "Audience": "BajajDocumentProcessing",
    "ExpirationMinutes": "30"
  }
}
```

**Important**: Change the `Secret` in production to a secure random value!

## Testing Authentication

### Using Swagger UI

1. Run the API:
   ```bash
   dotnet run --project src/BajajDocumentProcessing.API
   ```

2. Navigate to https://localhost:7001/swagger

3. Click "Authorize" button

4. Login to get a token:
   - POST /api/auth/login
   - Use test credentials (e.g., agency@bajaj.com / Password123!)
   - Copy the token from the response

5. Enter token in authorization dialog:
   - Format: `Bearer {your-token}`
   - Click "Authorize"

6. Test protected endpoints:
   - GET /api/auth/me should now work

### Using curl

```bash
# Login
curl -X POST https://localhost:7001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"agency@bajaj.com","password":"Password123!"}'

# Use token
curl -X GET https://localhost:7001/api/auth/me \
  -H "Authorization: Bearer {your-token}"
```

### Running Tests

```bash
cd backend
dotnet test
```

All property-based tests should pass with 100 iterations each.

## Security Features

1. **Password Security**:
   - BCrypt hashing with 12 rounds
   - Salted hashes (different hash for same password)
   - One-way hashing (cannot reverse)

2. **Token Security**:
   - HMAC SHA256 signature
   - Expiration enforcement
   - Issuer and audience validation
   - No clock skew tolerance

3. **Role-Based Access**:
   - JWT claims include role
   - Authorization policies enforce role requirements
   - Unauthorized access returns 401/403

4. **Session Security**:
   - 30-minute expiration
   - Token refresh mechanism
   - Last login tracking

## Next Steps

With authentication complete, you can now:

1. **Run the API** and test authentication endpoints
2. **Proceed to Task 5**: Implement file upload and storage service
3. **Integrate with Flutter**: Update Flutter app to use authentication

## Troubleshooting

### "JWT Secret not configured" Error
- Ensure `Jwt:Secret` is set in appsettings.json
- Secret must be at least 32 characters

### "Invalid email or password" Error
- Verify user exists in database (run migrations and seed)
- Check password is correct (default: Password123!)
- Ensure user is active (IsActive = true)

### "Unauthorized" Error
- Verify token is included in Authorization header
- Format: `Authorization: Bearer {token}`
- Check token hasn't expired (30 minutes)
- Use refresh endpoint if token expired

### Tests Failing
- Ensure all NuGet packages are restored
- Check BCrypt.Net-Next package is installed
- Verify test database is accessible
