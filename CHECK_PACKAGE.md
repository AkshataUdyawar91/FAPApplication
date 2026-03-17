# Check Package Status

## Package ID
`7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8`

## Your Token
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs
```

## Wait 30-60 Seconds

The workflow is processing in the background. Wait at least 30 seconds before checking.

## Check Package Details

### Using curl:
```bash
curl -X 'GET' \
  'http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8' \
  -H 'accept: */*' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs'
```

### Using PowerShell:
```powershell
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs"

Invoke-RestMethod -Uri "http://localhost:5000/api/Submissions/7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8" -Method Get -Headers @{"Authorization"="Bearer $token"} | ConvertTo-Json -Depth 10
```

## What to Look For

### 1. Check the State
The `state` field should progress through:
- `Uploaded` → Initial state
- `Extracting` → Currently extracting data
- `Validating` → Validating data
- `Scoring` → Calculating confidence
- `Recommending` → Generating recommendation
- `PendingApproval` → ✅ DONE!

### 2. Check Extracted Data
Look for the `documents` array. Each document should have:
- `extractedData` field populated with JSON data
- `extractionConfidence` value

Example:
```json
{
  "documents": [
    {
      "type": "PO",
      "extractedData": {
        "poNumber": "PO-12345",
        "totalAmount": 10500.00
      }
    }
  ]
}
```

### 3. Check Confidence Score
Look for the `confidenceScore` object:
```json
{
  "confidenceScore": {
    "overallConfidence": 85.5,
    "poConfidence": 92.0,
    "invoiceConfidence": 88.0
  }
}
```

## Check Dashboard

After the package reaches `PendingApproval` state, check the submissions list:

```bash
curl -X 'GET' \
  'http://localhost:5000/api/submissions' \
  -H 'accept: */*' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1laWQiOiIwNWIwNGRhZi04MWE3LTRjMDYtOTJkNS03NGUwZDFlMzVhNGQiLCJlbWFpbCI6ImFnZW5jeUBiYWphai5jb20iLCJyb2xlIjoiQWdlbmN5IiwianRpIjoiOGQ4OWViOWItOWY1Ni00ZDNiLTg0MTktZTc2NzcxMmQwZDVmIiwibmJmIjoxNzcyNjk0OTQ1LCJleHAiOjE3NzI2OTY3NDUsImlhdCI6MTc3MjY5NDk0NSwiaXNzIjoiQmFqYWpEb2N1bWVudFByb2Nlc3NpbmciLCJhdWQiOiJCYWphakRvY3VtZW50UHJvY2Vzc2luZyJ9.9f8ZuDTDInLyuqmhRMOL-9qcy3Kdhuzb78kSQfcIHQs'
```

You should now see:
```json
{
  "items": [
    {
      "id": "7dbd1de3-bb3b-4d4e-a70f-e929c8cd94b8",
      "poNumber": "PO-12345",        // ← POPULATED
      "poAmount": 10500.00,           // ← POPULATED
      "overallConfidence": 85.5       // ← POPULATED
    }
  ]
}
```

## Troubleshooting

### If State is Stuck in "Extracting"
Check the API console logs for errors. The extraction may be failing.

### If State is "Rejected"
The workflow encountered an error. Check the API logs for details.

### If Data is Still Empty After "PendingApproval"
This would be unusual. Check:
1. The `extractedData` field in the documents array
2. API logs for extraction errors
3. Document file format (PDF vs JPG/PNG)
