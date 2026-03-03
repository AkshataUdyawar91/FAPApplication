# Azure Portal Configuration Guide
## Bajaj Document Processing System

This guide provides step-by-step instructions for configuring all required Azure services.

> **Note**: This system uses **Azure OpenAI GPT-4 Vision** for all document processing tasks (classification and data extraction). Azure Document Intelligence is NOT required.

---

## 1. Azure OpenAI Service

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "Azure OpenAI"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Create new or select existing
   - **Region**: East US or Sweden Central (GPT-4 availability)
   - **Name**: `bajaj-openai-service`
   - **Pricing Tier**: Standard

### Deploy Models
After creation, go to Azure OpenAI Studio:

1. **GPT-4 Deployment** (Required for document processing)
   - Model: `gpt-4` or `gpt-4-turbo` (with vision capabilities)
   - Deployment name: `gpt-4`
   - Tokens per minute: 10K (adjust based on needs)
   - **Note**: This single deployment handles both text and vision tasks

2. **Embedding Model Deployment** (Required for semantic search)
   - Model: `text-embedding-ada-002`
   - Deployment name: `text-embedding-ada-002`
   - Tokens per minute: 120K

### Get Configuration Values
- Navigate to: Resource → Keys and Endpoint
- Copy:
  - **Endpoint**: `https://bajaj-openai-service.openai.azure.com/`
  - **API Key**: (Key 1 or Key 2)
  - **Deployment Names**: gpt-4, text-embedding-ada-002

### Document Processing with GPT-4 Vision
The system uses GPT-4 Vision for:
- **Document Classification**: Identifying document types (PO, Invoice, Cost Summary, Photo, Additional)
- **Data Extraction**: Extracting structured data from documents using vision + structured prompts
- **Photo Analysis**: Analyzing activity photos and extracting metadata

No custom model training is required - GPT-4 Vision handles all document types out of the box.

---

## 2. Azure Blob Storage

### Create Storage Account
1. Navigate to Azure Portal → Create a resource
2. Search for "Storage account"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Storage account name**: `bajajdocumentstorage` (must be globally unique)
   - **Region**: Same as other resources
   - **Performance**: Standard
   - **Redundancy**: LRS (or GRS for production)

### Create Containers
After creation:
1. Navigate to: Storage account → Containers
2. Create the following containers:
   - **documents** (Private access)
   - **purchase-orders** (Private access)
   - **invoices** (Private access)
   - **cost-summaries** (Private access)
   - **photos** (Private access)
   - **additional-documents** (Private access)

### Configure CORS (if needed for direct upload)
1. Navigate to: Storage account → Resource sharing (CORS)
2. Add rule for Blob service:
   - **Allowed origins**: Your frontend domain or `*` for development
   - **Allowed methods**: GET, POST, PUT
   - **Allowed headers**: `*`
   - **Exposed headers**: `*`
   - **Max age**: 3600

### Get Configuration Values
- Navigate to: Storage account → Access keys
- Copy:
  - **Connection String**: (Connection string for key1)
  - **Storage Account Name**: `bajajdocumentstorage`
  - **Storage Account Key**: (key1)

---

## 3. Azure AI Search (Cognitive Search)

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "Azure AI Search" or "Cognitive Search"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Service name**: `bajaj-search-service`
   - **Location**: Same as other resources
   - **Pricing Tier**: Basic (or Standard for production)

### Create Index
Use Azure Portal or REST API:

1. Navigate to: Search service → Indexes → Add index
2. Index name: `analytics-embeddings`
3. Define fields:
   ```json
   {
     "name": "id",
     "type": "Edm.String",
     "key": true
   },
   {
     "name": "content",
     "type": "Edm.String",
     "searchable": true
   },
   {
     "name": "contentVector",
     "type": "Collection(Edm.Single)",
     "dimensions": 1536,
     "vectorSearchProfile": "default"
   },
   {
     "name": "state",
     "type": "Edm.String",
     "filterable": true
   },
   {
     "name": "submissionCount",
     "type": "Edm.Int32",
     "filterable": true
   },
   {
     "name": "approvalRate",
     "type": "Edm.Double",
     "filterable": true
   },
   {
     "name": "timestamp",
     "type": "Edm.DateTimeOffset",
     "filterable": true
   }
   ```

4. Configure vector search:
   - Algorithm: HNSW
   - Metric: Cosine similarity

### Get Configuration Values
- Navigate to: Search service → Keys
- Copy:
  - **Endpoint**: `https://bajaj-search-service.search.windows.net`
  - **Admin Key**: (Primary admin key)
  - **Index Name**: `analytics-embeddings`

---

## 4. Azure Communication Services

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "Communication Services"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Resource name**: `bajaj-communication-service`
   - **Data location**: United States (or your region)

### Configure Email Domain
1. Navigate to: Communication service → Email → Domains
2. Option A - Use Azure Managed Domain:
   - Click "Add domain"
   - Select "Azure Managed Domain"
   - Choose subdomain name: `bajaj-notifications`
   - Domain will be: `bajaj-notifications.azurecomm.net`

3. Option B - Use Custom Domain (Production):
   - Add your custom domain
   - Verify DNS records (TXT, SPF, DKIM)
   - Wait for verification

### Configure Sender Address
1. Navigate to: Email → Sender addresses
2. Add sender:
   - **Display name**: Bajaj Document Processing
   - **Email address**: `noreply@bajaj-notifications.azurecomm.net`
   - **Reply-to**: Your support email

### Get Configuration Values
- Navigate to: Communication service → Keys
- Copy:
  - **Connection String**: (Primary connection string)
  - **Endpoint**: `https://bajaj-communication-service.communication.azure.com`

---

## 5. Azure SQL Database

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "SQL Database"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Database name**: `BajajDocumentProcessing`
   - **Server**: Create new
     - **Server name**: `bajaj-sql-server` (must be globally unique)
     - **Location**: Same as other resources
     - **Authentication**: SQL authentication
     - **Admin login**: `sqladmin`
     - **Password**: (Strong password)
   - **Compute + storage**: 
     - Service tier: Standard S2 (or adjust based on needs)
     - Storage: 250 GB

### Configure Firewall
1. Navigate to: SQL server → Security → Networking
2. Add firewall rules:
   - **Allow Azure services**: Yes
   - **Add client IP**: Add your development machine IP
   - **Add App Service IP**: (After deploying backend)

### Get Configuration Values
- Connection string format:
  ```
  Server=tcp:bajaj-sql-server.database.windows.net,1433;
  Initial Catalog=BajajDocumentProcessing;
  Persist Security Info=False;
  User ID=sqladmin;
  Password={your_password};
  MultipleActiveResultSets=False;
  Encrypt=True;
  TrustServerCertificate=False;
  Connection Timeout=30;
  ```

---

## 6. Azure Key Vault

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "Key Vault"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Key vault name**: `bajaj-keyvault` (must be globally unique)
   - **Region**: Same as other resources
   - **Pricing tier**: Standard

### Configure Access Policies
1. Navigate to: Key Vault → Access policies
2. Add access policy:
   - **Secret permissions**: Get, List
   - **Select principal**: Your App Service managed identity (after deployment)

### Add Secrets
Navigate to: Key Vault → Secrets → Generate/Import

Add the following secrets:
1. **AzureOpenAI--ApiKey**: (OpenAI API key)
2. **AzureOpenAI--Endpoint**: (OpenAI endpoint)
3. **BlobStorage--ConnectionString**: (Storage connection string)
4. **AzureSearch--ApiKey**: (Search admin key)
5. **AzureSearch--Endpoint**: (Search endpoint)
6. **CommunicationServices--ConnectionString**: (ACS connection string)
7. **ConnectionStrings--DefaultConnection**: (SQL connection string)
8. **Jwt--SecretKey**: (Generate strong random key, min 32 chars)

### Get Configuration Values
- **Key Vault URI**: `https://bajaj-keyvault.vault.azure.net/`

---

## 7. Azure App Service (Backend API)

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "App Service"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Name**: `bajaj-api` (must be globally unique)
   - **Publish**: Code
   - **Runtime stack**: .NET 8 (LTS)
   - **Operating System**: Linux
   - **Region**: Same as other resources
   - **Pricing Plan**: 
     - Development: B1 Basic
     - Production: P1V2 Premium or higher

### Configure Settings
After creation:

1. **Enable Managed Identity**
   - Navigate to: App Service → Identity
   - System assigned: On
   - Copy Object (principal) ID

2. **Configure Application Settings**
   - Navigate to: App Service → Configuration → Application settings
   - Add Key Vault references:
     ```
     AzureOpenAI__ApiKey = @Microsoft.KeyVault(SecretUri=https://bajaj-keyvault.vault.azure.net/secrets/AzureOpenAI--ApiKey/)
     AzureOpenAI__Endpoint = @Microsoft.KeyVault(SecretUri=https://bajaj-keyvault.vault.azure.net/secrets/AzureOpenAI--Endpoint/)
     ```
   - Repeat for all secrets

3. **Configure CORS**
   - Navigate to: App Service → CORS
   - Add allowed origins:
     - Development: `http://localhost:*`
     - Production: Your Flutter web app URL

### Get Configuration Values
- **App Service URL**: `https://bajaj-api.azurewebsites.net`

---

## 8. Azure Static Web Apps (Flutter Frontend)

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "Static Web Apps"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Name**: `bajaj-frontend`
   - **Plan type**: Free (or Standard for production)
   - **Region**: Auto
   - **Source**: GitHub (or Azure DevOps)
   - **Repository**: Link your Flutter repo
   - **Build preset**: Custom
   - **App location**: `/`
   - **Output location**: `build/web`

### Configure Settings
After creation:

1. **Configure Environment Variables**
   - Navigate to: Static Web App → Configuration
   - Add:
     ```
     API_BASE_URL = https://bajaj-api.azurewebsites.net
     ```

2. **Configure Custom Domain** (Optional)
   - Navigate to: Static Web App → Custom domains
   - Add your domain
   - Configure DNS records

### Get Configuration Values
- **Static Web App URL**: `https://[random-name].azurestaticapps.net`

---

## 9. Azure Content Safety (Optional but Recommended)

### Create Resource
1. Navigate to Azure Portal → Create a resource
2. Search for "Content Safety"
3. Click Create
4. Configure:
   - **Subscription**: Select your subscription
   - **Resource Group**: Same as above
   - **Region**: Same as other resources
   - **Name**: `bajaj-content-safety`
   - **Pricing Tier**: Standard S0

### Get Configuration Values
- Navigate to: Resource → Keys and Endpoint
- Copy:
  - **Endpoint**: `https://bajaj-content-safety.cognitiveservices.azure.com/`
  - **API Key**: (Key 1 or Key 2)

---

## Configuration Summary

After completing all steps, update your `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tcp:bajaj-sql-server.database.windows.net,1433;Initial Catalog=BajajDocumentProcessing;..."
  },
  "AzureOpenAI": {
    "Endpoint": "https://bajaj-openai-service.openai.azure.com/",
    "ApiKey": "your-api-key",
    "DeploymentName": "gpt-4",
    "EmbeddingDeploymentName": "text-embedding-ada-002"
  },
  "BlobStorage": {
    "ConnectionString": "DefaultEndpointsProtocol=https;AccountName=bajajdocumentstorage;...",
    "ContainerName": "documents"
  },
  "AzureSearch": {
    "Endpoint": "https://bajaj-search-service.search.windows.net",
    "ApiKey": "your-admin-key",
    "IndexName": "analytics-embeddings"
  },
  "CommunicationServices": {
    "ConnectionString": "endpoint=https://bajaj-communication-service.communication.azure.com/;...",
    "SenderEmail": "noreply@bajaj-notifications.azurecomm.net"
  },
  "ContentSafety": {
    "Endpoint": "https://bajaj-content-safety.cognitiveservices.azure.com/",
    "ApiKey": "your-api-key"
  },
  "Jwt": {
    "SecretKey": "your-secret-key-minimum-32-characters",
    "Issuer": "BajajDocumentProcessing",
    "Audience": "BajajDocumentProcessing",
    "ExpiryMinutes": 30
  },
  "KeyVault": {
    "VaultUri": "https://bajaj-keyvault.vault.azure.net/"
  }
}
```

---

## Cost Estimation (Monthly)

### Development Environment
- Azure OpenAI: ~$50-100 (based on usage)
- Blob Storage: ~$5-10
- AI Search (Basic): ~$75
- Communication Services: ~$10-20
- SQL Database (S2): ~$150
- App Service (B1): ~$13
- Static Web Apps (Free): $0
- Key Vault: ~$1
- **Total: ~$304-369/month**

### Production Environment
- Azure OpenAI: ~$200-500 (based on usage)
- Blob Storage: ~$20-50
- AI Search (Standard): ~$250
- Communication Services: ~$50-100
- SQL Database (P1): ~$465
- App Service (P1V2): ~$146
- Static Web Apps (Standard): ~$9
- Key Vault: ~$1
- Content Safety: ~$20-50
- **Total: ~$1,161-1,571/month**

---

## Next Steps

1. ✅ Create all Azure resources
2. ✅ Configure services and get credentials
3. ✅ Update `appsettings.json` with all values
4. ✅ Store secrets in Azure Key Vault
5. ✅ Run database migrations
6. ✅ Deploy backend to App Service
7. ✅ Deploy frontend to Static Web Apps
8. ✅ Test end-to-end workflows
9. ✅ Configure monitoring and alerts
10. ✅ Set up backup and disaster recovery

---

## Support Resources

- Azure OpenAI: https://learn.microsoft.com/azure/ai-services/openai/
- Azure AI Search: https://learn.microsoft.com/azure/search/
- Communication Services: https://learn.microsoft.com/azure/communication-services/
- App Service: https://learn.microsoft.com/azure/app-service/
