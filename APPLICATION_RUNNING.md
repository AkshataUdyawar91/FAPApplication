# Application Running with Azure Synapse Database

## Backend Status ✅

The .NET 8 Web API is running successfully on `http://localhost:5000` with Azure OpenAI integration.

**Swagger UI**: `http://localhost:5000/swagger`

### ⚠️ Database Firewall Configuration Required

The application is running but cannot connect to Azure Synapse until you add your IP to the firewall rules.

**Error**: `Cannot open server 'balsynwsdev' requested by the login. Client with IP address is not allowed to access the server.`

See `AZURE_SYNAPSE_SETUP.md` for detailed instructions on adding firewall rules.

## Current Configuration

### Azure OpenAI ✅
- Endpoint: `https://aif-bal-agentic-ai-1-sin-002.cognitiveservices.azure.com/`
- Deployment: `gpt-5-mini`
- Embedding Model: `text-embedding-ada-002`
- Status: **Configured and Ready**

### Azure Synapse SQL Database ⚠️
- Server: `balsynwsdev.sql.azuresynapse.net`
- Database: `Balsynwsdev`
- Username: `deloitte03`
- Status: **Firewall Configuration Required**

### Azure AI Search (Optional) ℹ️
- Status: **Not Configured (Optional)**
- Impact: Chat and advanced analytics features disabled
- Core features: **Working without it**
- See: `AZURE_AI_SEARCH_OPTIONAL_COMPLETE.md`

### Azure Blob Storage ⏳
- Status: **Not Configured**
- Impact: Document upload will fail
- Required for: Document storage

### Azure Communication Services ⏳
- Status: **Not Configured**
- Impact: Email notifications disabled
- Required for: Email delivery

### 🔧 Required Fix: Add Firewall Rule

You need to add your client IP address to the Azure Synapse firewall rules:

#### Option 1: Azure Portal (Recommended)
1. Go to Azure Portal: https://portal.azure.com
2. Navigate to your Synapse workspace: `balsynwsdev`
3. Go to **Networking** or **Firewalls and virtual networks**
4. Click **Add client IP** (this will add your current IP automatically)
5. Or manually add a firewall rule:
   - Rule name: `DevelopmentMachine`
   - Start IP: Your current IP address
   - End IP: Your current IP address
6. Click **Save**
7. Wait 1-2 minutes for the rule to propagate

#### Option 2: Azure CLI
```bash
az synapse workspace firewall-rule create \
  --name DevelopmentMachine \
  --workspace-name balsynwsdev \
  --resource-group <your-resource-group> \
  --start-ip-address <your-ip> \
  --end-ip-address <your-ip>
```

#### Option 3: Allow Azure Services
In Azure Portal, enable "Allow Azure services and resources to access this workspace"

### After Adding Firewall Rule

Once the firewall rule is added, restart the backend:

```bash
# Stop current process (Ctrl+C in the terminal)
# Then restart:
cd backend
dotnet run --project src/BajajDocumentProcessing.API
```

The application will:
1. Connect to Azure Synapse database
2. Run Entity Framework migrations (create tables if needed)
3. Seed initial users (agency, asm, hq)
4. Start accepting API requests

### Key Changes Made

1. **Removed Azure Document Intelligence Dependency**
   - Removed `Azure.AI.FormRecognizer` NuGet package
   - Updated `DocumentAgent.cs` to use only Azure OpenAI GPT-4 Vision for all document processing
   - Removed Document Intelligence configuration from `appsettings.json`

2. **Updated Azure OpenAI Configuration**
   - Configured with your actual Azure OpenAI credentials
   - Deployment name: `gpt-5-mini`
   - Embedding deployment: `text-embedding-ada-002`

3. **Fixed Compilation Issues**
   - Fixed nullable DateTime conversion in `DocumentAgent.cs`
   - All warnings resolved, application compiles successfully

4. **Updated Documentation**
   - `AZURE_CONFIGURATION_GUIDE.md`: Removed Document Intelligence sections, updated cost estimates
   - `ARCHITECTURE_DIAGRAM.md`: Removed Document Intelligence from architecture
   - Steering files updated to reflect Azure OpenAI-only approach

### Document Processing Approach

The system now uses **Azure OpenAI GPT-4 Vision exclusively** for:

1. **Document Classification**
   - Identifies document types: PO, Invoice, Cost Summary, Photo, Additional Document
   - Returns confidence scores and reasoning

2. **Data Extraction**
   - Purchase Orders: PO Number, Vendor, Date, Line Items, Total
   - Invoices: Invoice Number, Vendor, Date, Line Items, Tax, Total
   - Cost Summaries: Campaign Name, State, Dates, Cost Breakdowns, Total

3. **Photo Analysis**
   - EXIF metadata extraction (timestamp, GPS, device info)
   - Uses MetadataExtractor library for reliable metadata reading

### Test Credentials

**Agency User**:
- Email: `agency@bajaj.com`
- Password: `Password123!`

**ASM User**:
- Email: `asm@bajaj.com`
- Password: `Password123!`

**HQ User**:
- Email: `hq@bajaj.com`
- Password: `Password123!`

## Testing the API

### 1. Access Swagger UI
Open your browser and navigate to:
```
http://localhost:5000/swagger
```

### 2. Test Authentication
1. Expand the `/api/auth/login` endpoint
2. Click "Try it out"
3. Enter credentials:
```json
{
  "email": "agency@bajaj.com",
  "password": "Password123!"
}
```
4. Click "Execute"
5. Copy the `token` from the response

### 3. Authorize Swagger
1. Click the "Authorize" button at the top
2. Enter: `Bearer {your-token}`
3. Click "Authorize"

### 4. Test Document Upload
1. Expand `/api/documents/upload`
2. Click "Try it out"
3. Upload a test document (PDF, image, etc.)
4. The system will:
   - Upload to Azure Blob Storage (if configured)
   - Classify the document using GPT-4 Vision
   - Extract structured data
   - Calculate confidence scores
   - Store in database

## Next Steps

### Required Azure Services Configuration

To enable full functionality, configure these Azure services:

1. **Azure Blob Storage** (Document storage)
   - Create storage account
   - Create container: `documents`
   - Update `AzureBlobStorage:ConnectionString` in appsettings.json

2. **Azure AI Search** (Semantic search for chat)
   - Create search service
   - Create index: `analytics-embeddings`
   - Update `AzureAISearch:Endpoint` and `ApiKey` in appsettings.json

3. **Azure Communication Services** (Email notifications)
   - Create communication service
   - Configure email domain
   - Update `AzureCommunicationServices:ConnectionString` in appsettings.json

4. **SAP Integration** (Optional - for validation)
   - Update `SAP:BaseUrl`, `ApiKey`, `Username`, `Password` in appsettings.json

### Frontend Setup

To run the Flutter frontend:

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Or use the batch file:
```bash
cd frontend
run_flutter_chrome.bat
```

## Architecture Summary

```
Flutter App → .NET 8 API → Azure OpenAI (GPT-5-mini)
                         → Azure Blob Storage
                         → Azure AI Search
                         → SQL Server Express
                         → Azure Communication Services
```

## Troubleshooting

### Backend Not Starting
- Check Azure Synapse firewall rules (see above)
- Verify connection string in appsettings.json
- Check port 5000 is not in use
- Ensure you have network connectivity to Azure

### Database Connection Fails
- **Error 40615**: Add your IP to Azure Synapse firewall rules
- Verify username and password are correct
- Check if database `Balsynwsdev` exists
- Ensure SQL authentication is enabled on the server

### Login Fails
- Verify JWT configuration (SecretKey, Issuer, Audience)
- Check database has seeded users
- Verify password meets requirements

### Document Processing Fails
- Verify Azure OpenAI credentials are correct
- Check deployment name matches: `gpt-5-mini`
- Ensure sufficient quota in Azure OpenAI

### Swagger Not Accessible
- Backend is now configured to show Swagger in all environments
- Access at: `http://localhost:5000/swagger`

## Support

For issues or questions:
1. Check application logs in the console
2. Review `AZURE_CONFIGURATION_GUIDE.md` for setup details
3. Check `ARCHITECTURE_DIAGRAM.md` for system architecture
4. Review `AZURE_END_TO_END_FLOW.md` for workflow details

---

**Status**: ✅ Backend Running | ⚠️ Database Firewall Configuration Required | ⏳ Frontend Pending | ⏳ Azure Services Configuration Pending

## Next Immediate Action

**Add your IP address to Azure Synapse firewall rules** to enable database connectivity. See the "Required Fix" section above for detailed instructions.
