# How to Get Your Submission ID

## Method 1: Using Swagger (Recommended)

1. **Open Swagger UI**
   - Navigate to: http://localhost:5000/swagger

2. **Authorize**
   - Click the "Authorize" button (lock icon) at the top right
   - Enter your token in the format: `Bearer YOUR_TOKEN_HERE`
   - Click "Authorize" then "Close"

3. **Get Submissions List**
   - Find the `GET /api/submissions` endpoint
   - Click "Try it out"
   - Click "Execute"

4. **Find Your Submission ID**
   - Look in the response body under `items` array
   - Each submission has an `id` field (GUID format)
   - Example response:
   ```json
   {
     "total": 1,
     "page": 1,
     "pageSize": 20,
     "items": [
       {
         "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
         "state": "Uploaded",
         "createdAt": "2026-03-02T11:25:00Z",
         "updatedAt": "2026-03-02T11:25:00Z",
         "documentCount": 5
       }
     ]
   }
   ```
   - Copy the `id` value (the long GUID string)

## Method 2: Using Browser Developer Tools

1. **Login to Flutter App**
   - Login as agency user: agency@bajaj.com / Agency@123

2. **Open Developer Console**
   - Press F12 or right-click → Inspect
   - Go to "Network" tab

3. **Navigate to Dashboard**
   - Go to the agency dashboard
   - Look for the network request to `/api/submissions`

4. **View Response**
   - Click on the submissions request
   - Go to "Response" tab
   - Find the `id` field in the items array

## Method 3: Check Database Directly

If you have access to SQL Server Management Studio or similar:

```sql
SELECT TOP 1 
    Id,
    State,
    CreatedAt,
    UpdatedAt,
    SubmittedByUserId
FROM DocumentPackages
ORDER BY CreatedAt DESC
```

The `Id` column contains your submission ID.

## What to Do with the Submission ID

Once you have the submission ID, use it to move the submission to PendingApproval:

1. In Swagger, find `PATCH /api/submissions/{id}/move-to-pending`
2. Click "Try it out"
3. Paste your submission ID in the `id` field
4. Click "Execute"
5. Verify the response shows `"state": "PendingApproval"`

## Example Submission ID Format

Submission IDs are GUIDs that look like:
- `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
- `12345678-1234-1234-1234-123456789abc`

They are always 36 characters long with hyphens in specific positions.

## Troubleshooting

**No submissions found?**
- Make sure you're authorized with the correct token
- Verify you uploaded documents successfully
- Check that the backend is running on http://localhost:5000

**Multiple submissions?**
- Use the most recent one (highest `createdAt` timestamp)
- Or use the one with the most documents (`documentCount`)

**Authorization error?**
- Make sure you're using the agency user's token
- Token format should be: `Bearer eyJhbGc...` (starts with "Bearer ")
