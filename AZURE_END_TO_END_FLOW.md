# Azure Services End-to-End Flow Guide
## Bajaj Document Processing System

This document maps each step of the document processing workflow to the specific Azure services required, providing a complete understanding of how Azure services enable the end-to-end flow.

---

## Overview of User Workflows

1. **Agency Submission Flow**: Agency uploads documents → System processes → Validation → Notification
2. **ASM Review Flow**: ASM receives notification → Reviews with AI recommendations → Approves/Rejects
3. **HQ Analytics Flow**: HQ accesses dashboard → Queries analytics → Uses chatbot for insights
4. **Chatbot Service Flow**: User asks question → Semantic search → AI generates response

---

## 1. Agency Submission Flow

### Step 1.1: Document Upload
**User Action**: Agency user uploads PO, Invoice, Cost Summary, Photos, and Additional Documents

**Azure Services Used**:
- **Azure Blob Storage**: Stores uploaded files
  - Container: `documents`
  - Files organized by package ID and document type
  - Generates secure blob URLs for processing

**Configuration Required**:
```json
"AzureBlobStorage": {
  "ConnectionString": "DefaultEndpointsProtocol=https;AccountName=...",
  "ContainerName": "documents"
}
```

**Code Reference**: `FileStorageService.cs` → `UploadFileAsync()`

---

### Step 1.2: Malware Scanning
**System Action**: Scans uploaded files for malware

**Azure Services Used**:
- **Azure Blob Storage**: Retrieves file for scanning
- **Built-in scanning** or **Azure Defender for Storage** (optional)

**Configuration Required**:
- Enable Azure Defender for Storage (optional but recommended for production)

**Code Reference**: `MalwareScanService.cs` → `ScanFileAsync()`

---

### Step 1.3: Document Classification
**System Action**: AI classifies each document into type (PO, Invoice, Cost Summary, Photo, Additional)

**Azure Services Used**:
- **Azure OpenAI Service (GPT-4 Vision)**:
  - Model: `gpt-4` or `gpt-4-vision-preview`
  - Analyzes document images
  - Returns classification with confidence score

**Configuration Required**:
```json
"AzureOpenAI": {
  "Endpoint": "https://your-resource.openai.azure.com/",
  "ApiKey": "your-api-key",
  "DeploymentName": "gpt-4"
}
```

**API Call Flow**:
1. System sends blob URL to GPT-4 Vision
2. GPT-4 analyzes document structure and content
3. Returns: `{ "type": "PO", "confidence": 0.95, "reasoning": "..." }`

**Code Reference**: `DocumentAgent.cs` → `ClassifyAsync()`

---

### Step 1.4: Data Extraction
**System Action**: Extracts structured data from each document type

**Azure Services Used**:
- **Azure Document Intelligence (Form Recognizer)**:
  - **For PO**: Uses `prebuilt-invoice` model
    - Extracts: PO Number, Vendor, Date, Line Items, Total Amount
  - **For Invoice**: Uses `prebuilt-invoice` model
    - Extracts: Invoice Number, Vendor, Date, Line Items, Tax, Total
  - **For Cost Summary**: Uses `prebuilt-document` model
    - Extracts: Key-value pairs, tables, campaign details
  - **For Photos**: Uses EXIF metadata extraction
    - Extracts: Timestamp, GPS location, device info

**Configuration Required**:
```json
"AzureDocumentIntelligence": {
  "Endpoint": "https://your-resource.cognitiveservices.azure.com/",
  "ApiKey": "your-api-key"
}
```

**API Call Flow**:
1. System sends blob URL to Document Intelligence
2. Document Intelligence analyzes document
3. Returns structured JSON with extracted fields and confidence scores

**Code Reference**: 
- `DocumentAgent.cs` → `ExtractPOAsync()`
- `DocumentAgent.cs` → `ExtractInvoiceAsync()`
- `DocumentAgent.cs` → `ExtractCostSummaryAsync()`
- `DocumentAgent.cs` → `ExtractPhotoMetadataAsync()`

---

### Step 1.5: Cross-Document Validation
**System Action**: Validates extracted data across documents and against SAP

**Azure Services Used**:
- **Azure SQL Database**: Stores extracted data for validation
- **SAP Integration** (External): Validates PO numbers, vendor names, amounts
- **Azure OpenAI Service (GPT-4)**: Performs intelligent validation logic

**Configuration Required**:
```json
"ConnectionStrings": {
  "DefaultConnection": "Server=tcp:your-server.database.windows.net,1433;..."
},
"SAP": {
  "BaseUrl": "https://sap-api.example.com",
  "ApiKey": "your-sap-key"
}
```

**Validation Checks**:
1. **PO vs Invoice**: Vendor names match, amounts align
2. **Invoice vs Cost Summary**: Total amounts match
3. **SAP Validation**: PO exists in SAP, vendor is valid
4. **Photo Validation**: Timestamp within campaign dates, GPS location valid

**Code Reference**: `ValidationAgent.cs` → `ValidatePackageAsync()`

---

### Step 1.6: Confidence Score Calculation
**System Action**: Calculates weighted confidence score

**Azure Services Used**:
- **Azure SQL Database**: Retrieves confidence scores from extraction
- **Local Calculation**: Weighted average (PO 30%, Invoice 30%, Cost Summary 20%, Activity 10%, Photos 10%)

**Configuration Required**: None (uses extracted confidence scores)

**Code Reference**: `ConfidenceScoreService.cs` → `CalculateConfidenceScoreAsync()`

---

### Step 1.7: AI Recommendation Generation
**System Action**: Generates APPROVE/REVIEW/REJECT recommendation with evidence

**Azure Services Used**:
- **Azure OpenAI Service (GPT-4)**:
  - Analyzes validation results, confidence scores, and extracted data
  - Generates recommendation with reasoning
  - Provides evidence-based justification

**Configuration Required**:
```json
"AzureOpenAI": {
  "Endpoint": "https://your-resource.openai.azure.com/",
  "ApiKey": "your-api-key",
  "DeploymentName": "gpt-4"
}
```

**API Call Flow**:
1. System sends validation results and confidence scores to GPT-4
2. GPT-4 analyzes data and generates recommendation
3. Returns: `{ "recommendation": "APPROVE", "confidence": 0.92, "evidence": [...] }`

**Code Reference**: `RecommendationAgent.cs` → `GenerateRecommendationAsync()`

---

### Step 1.8: Email Notification (Data Failure)
**System Action**: If validation fails, sends email to agency with issues

**Azure Services Used**:
- **Azure Communication Services (Email)**:
  - Sends HTML email with validation issues
  - Includes retry logic with exponential backoff

**Configuration Required**:
```json
"AzureCommunicationServices": {
  "ConnectionString": "endpoint=https://your-resource.communication.azure.com/;..."
}
```

**Email Content**:
- Subject: "Action Required: Document Validation Failed"
- Body: List of validation issues with expected vs actual values
- Call to action: Re-upload corrected documents

**Code Reference**: `EmailAgent.cs` → `SendDataFailureEmailAsync()`

---

### Step 1.9: Email Notification (Data Pass)
**System Action**: If validation passes, sends email to ASM for review

**Azure Services Used**:
- **Azure Communication Services (Email)**:
  - Sends notification to ASM
  - Includes package ID, confidence score, AI recommendation

**Configuration Required**: Same as Step 1.8

**Email Content**:
- Subject: "New Document Package Ready for Review"
- Body: Package details, confidence score, AI recommendation
- Call to action: Log in to review and approve/reject

**Code Reference**: `EmailAgent.cs` → `SendDataPassEmailAsync()`

---

### Step 1.10: In-App Notification
**System Action**: Creates in-app notification for ASM

**Azure Services Used**:
- **Azure SQL Database**: Stores notification record
- **SignalR** (optional): Real-time push notification

**Configuration Required**:
```json
"ConnectionStrings": {
  "DefaultConnection": "Server=tcp:your-server.database.windows.net,1433;..."
}
```

**Code Reference**: `NotificationAgent.cs` → `CreateNotificationAsync()`

---

## 2. ASM Review Flow

### Step 2.1: View Pending Submissions
**User Action**: ASM logs in and views pending submissions

**Azure Services Used**:
- **Azure SQL Database**: Queries submissions with state = "PendingReview"
- **Azure Blob Storage**: Retrieves document thumbnails

**Configuration Required**: Database connection string

**Code Reference**: `SubmissionsController.cs` → `GetPendingSubmissions()`

---

### Step 2.2: View Submission Details
**User Action**: ASM clicks on a submission to view details

**Azure Services Used**:
- **Azure SQL Database**: Retrieves package, documents, validation results, confidence scores, recommendations
- **Azure Blob Storage**: Generates SAS tokens for secure document access

**Configuration Required**: Database and Blob Storage connection strings

**Code Reference**: `SubmissionsController.cs` → `GetSubmissionDetails()`

---

### Step 2.3: View AI Recommendation
**User Action**: ASM reviews AI-generated recommendation with evidence

**Azure Services Used**:
- **Azure SQL Database**: Retrieves recommendation record
- **Display**: Shows recommendation type, confidence, evidence list, reasoning

**Configuration Required**: Database connection string

**Code Reference**: Frontend displays data from `Recommendation` entity

---

### Step 2.4: Approve Submission
**User Action**: ASM approves the submission

**Azure Services Used**:
- **Azure SQL Database**: Updates package state to "Approved"
- **Azure Communication Services**: Sends approval email to agency
- **Azure SQL Database**: Creates audit log entry

**Configuration Required**: Database and ACS connection strings

**Email Content**:
- Subject: "Document Package Approved"
- Body: Congratulations message with package ID
- Next steps: Documents processed successfully

**Code Reference**: 
- `SubmissionsController.cs` → `ApproveSubmission()`
- `EmailAgent.cs` → `SendApprovedEmailAsync()`
- `AuditLogService.cs` → `LogAsync()`

---

### Step 2.5: Reject Submission
**User Action**: ASM rejects the submission with reason

**Azure Services Used**:
- **Azure SQL Database**: Updates package state to "Rejected"
- **Azure Communication Services**: Sends rejection email to agency with reason
- **Azure SQL Database**: Creates audit log entry

**Configuration Required**: Database and ACS connection strings

**Email Content**:
- Subject: "Document Package Rejected"
- Body: Rejection reason, feedback, instructions to resubmit
- Call to action: Correct issues and resubmit

**Code Reference**: 
- `SubmissionsController.cs` → `RejectSubmission()`
- `EmailAgent.cs` → `SendRejectedEmailAsync()`
- `AuditLogService.cs` → `LogAsync()`

---

## 3. HQ Analytics Flow

### Step 3.1: View Analytics Dashboard
**User Action**: HQ user accesses analytics dashboard

**Azure Services Used**:
- **Azure SQL Database**: Queries aggregated analytics data
  - Submission counts by state, time period
  - Approval rates by state, ASM
  - Average confidence scores
  - Top campaigns by cost

**Configuration Required**: Database connection string

**Code Reference**: `AnalyticsController.cs` → `GetDashboard()`

---

### Step 3.2: Generate AI Narrative
**System Action**: Generates natural language insights from analytics data

**Azure Services Used**:
- **Azure OpenAI Service (GPT-4)**:
  - Receives analytics data (KPIs, trends, comparisons)
  - Generates narrative insights
  - Highlights anomalies and recommendations

**Configuration Required**:
```json
"AzureOpenAI": {
  "Endpoint": "https://your-resource.openai.azure.com/",
  "ApiKey": "your-api-key",
  "DeploymentName": "gpt-4"
}
```

**API Call Flow**:
1. System sends analytics data to GPT-4
2. GPT-4 analyzes trends and patterns
3. Returns narrative: "In Q1 2024, Maharashtra showed a 15% increase in submissions..."

**Code Reference**: `AnalyticsAgent.cs` → `GenerateNarrativeAsync()`

---

### Step 3.3: Embedding Pipeline (Background Process)
**System Action**: Periodically generates embeddings for analytics data

**Azure Services Used**:
- **Azure SQL Database**: Queries analytics data
- **Azure OpenAI Service (Embeddings)**:
  - Model: `text-embedding-ada-002`
  - Generates 1536-dimensional vectors
- **Azure AI Search**: Stores embeddings in vector index

**Configuration Required**:
```json
"AzureOpenAI": {
  "EmbeddingDeploymentName": "text-embedding-ada-002"
},
"AzureAISearch": {
  "Endpoint": "https://your-service.search.windows.net",
  "ApiKey": "your-admin-key",
  "IndexName": "analytics-embeddings"
}
```

**Process Flow**:
1. Query analytics data (by state, time range, campaign)
2. Generate text summaries
3. Create embeddings using Azure OpenAI
4. Upsert to Azure AI Search vector index

**Code Reference**: `AnalyticsEmbeddingPipeline.cs` → `ProcessAnalyticsDataAsync()`

---

## 4. Chatbot Service Flow

### Step 4.1: User Asks Question
**User Action**: User types question in chat interface

**Azure Services Used**:
- **Azure SQL Database**: Creates conversation and message records
- **Input Guardrails**: Validates input for safety

**Configuration Required**: Database connection string

**Code Reference**: `ChatController.cs` → `SendMessage()`

---

### Step 4.2: Input Guardrails
**System Action**: Validates user input for safety and authorization

**Azure Services Used**:
- **Azure Content Safety** (optional): Checks for harmful content
- **Local Validation**: Checks for PII, SQL injection, prompt injection
- **Authorization Check**: Verifies user has access to requested data

**Configuration Required**:
```json
"ContentSafety": {
  "Endpoint": "https://your-resource.cognitiveservices.azure.com/",
  "ApiKey": "your-api-key"
}
```

**Code Reference**: 
- `InputGuardrailService.cs` → `ValidateInputAsync()`
- `AuthorizationGuardrailService.cs` → `ValidateAccessAsync()`

---

### Step 4.3: Generate Query Embedding
**System Action**: Converts user question to vector embedding

**Azure Services Used**:
- **Azure OpenAI Service (Embeddings)**:
  - Model: `text-embedding-ada-002`
  - Generates 1536-dimensional vector from question

**Configuration Required**:
```json
"AzureOpenAI": {
  "EmbeddingDeploymentName": "text-embedding-ada-002"
}
```

**API Call Flow**:
1. System sends user question to embedding model
2. Returns vector: `[0.123, -0.456, 0.789, ...]` (1536 dimensions)

**Code Reference**: `EmbeddingService.cs` → `GenerateEmbeddingAsync()`

---

### Step 4.4: Vector Search
**System Action**: Searches for relevant analytics data using semantic similarity

**Azure Services Used**:
- **Azure AI Search**:
  - Performs vector similarity search (cosine similarity)
  - Applies filters based on user role and context
  - Returns top K most relevant results

**Configuration Required**:
```json
"AzureAISearch": {
  "Endpoint": "https://your-service.search.windows.net",
  "ApiKey": "your-admin-key",
  "IndexName": "analytics-embeddings"
}
```

**Search Flow**:
1. System sends query vector to Azure AI Search
2. Azure AI Search performs HNSW vector search
3. Applies filters (state, time range, user role)
4. Returns top 5 most relevant analytics summaries

**Code Reference**: `AzureAISearchService.cs` → `SearchAsync()`

---

### Step 4.5: Generate AI Response
**System Action**: Generates natural language response using retrieved context

**Azure Services Used**:
- **Azure OpenAI Service (GPT-4)**:
  - Receives user question + retrieved context
  - Generates grounded response
  - Cites sources from analytics data

**Configuration Required**:
```json
"AzureOpenAI": {
  "DeploymentName": "gpt-4"
}
```

**API Call Flow**:
1. System constructs prompt with:
   - User question
   - Retrieved analytics context
   - System instructions (role, constraints)
2. GPT-4 generates response grounded in context
3. Returns answer with citations

**Code Reference**: `ChatService.cs` → `GenerateResponseAsync()`

---

### Step 4.6: Output Guardrails
**System Action**: Validates AI response before sending to user

**Azure Services Used**:
- **Azure Content Safety** (optional): Checks for harmful content
- **Local Validation**: Checks for PII leakage, hallucinations, unauthorized data

**Configuration Required**: Same as Step 4.2

**Code Reference**: `OutputGuardrailService.cs` → `ValidateOutputAsync()`

---

### Step 4.7: Return Response
**System Action**: Sends response to user and stores in database

**Azure Services Used**:
- **Azure SQL Database**: Stores assistant message in conversation
- **Frontend**: Displays response to user

**Configuration Required**: Database connection string

**Code Reference**: `ChatController.cs` → `SendMessage()` (returns response)

---

## Azure Services Summary by Feature

### Document Processing
- **Azure Blob Storage**: File storage
- **Azure OpenAI (GPT-4 Vision)**: Document classification
- **Azure Document Intelligence**: Data extraction
- **Azure OpenAI (GPT-4)**: Validation logic, recommendations

### Email Notifications
- **Azure Communication Services**: Email delivery
- **Azure SQL Database**: Notification tracking

### Analytics
- **Azure SQL Database**: Data aggregation
- **Azure OpenAI (GPT-4)**: Narrative generation
- **Azure OpenAI (Embeddings)**: Vector generation
- **Azure AI Search**: Vector storage and search

### Chatbot
- **Azure OpenAI (Embeddings)**: Query vectorization
- **Azure AI Search**: Semantic search
- **Azure OpenAI (GPT-4)**: Response generation
- **Azure Content Safety**: Input/output validation

### Infrastructure
- **Azure SQL Database**: Primary data store
- **Azure Key Vault**: Secrets management
- **Azure App Service**: Backend API hosting
- **Azure Static Web Apps**: Frontend hosting
- **Azure Monitor**: Logging and monitoring

---

## Required Azure Resources Checklist

### Core Services (Required)
- [ ] Azure OpenAI Service
  - [ ] GPT-4 deployment
  - [ ] text-embedding-ada-002 deployment
- [ ] Azure Document Intelligence
- [ ] Azure Blob Storage
- [ ] Azure AI Search
- [ ] Azure Communication Services
- [ ] Azure SQL Database

### Hosting Services (Required for Production)
- [ ] Azure App Service (Backend API)
- [ ] Azure Static Web Apps (Frontend)
- [ ] Azure Key Vault (Secrets)

### Optional Services (Recommended)
- [ ] Azure Content Safety (Input/output validation)
- [ ] Azure Monitor (Logging and alerts)
- [ ] Azure Application Insights (Performance monitoring)
- [ ] Azure Cache for Redis (Performance optimization)
- [ ] Azure Defender for Storage (Security)

---

## Configuration Priority

### Phase 1: Core Processing (Agency Submission)
1. Azure Blob Storage
2. Azure OpenAI Service (GPT-4)
3. Azure Document Intelligence
4. Azure SQL Database
5. Azure Communication Services

### Phase 2: Review Workflow (ASM)
1. Azure SQL Database (already configured)
2. Azure Communication Services (already configured)

### Phase 3: Analytics (HQ)
1. Azure OpenAI Service (already configured)
2. Azure SQL Database (already configured)

### Phase 4: Chatbot
1. Azure OpenAI Service (Embeddings)
2. Azure AI Search
3. Azure Content Safety (optional)

---

## Testing Each Flow

### Test Agency Submission
```bash
# Upload documents via API
POST /api/documents/upload
# Check: Blob Storage, Document Intelligence, OpenAI, SQL Database, Email
```

### Test ASM Review
```bash
# Get pending submissions
GET /api/submissions/pending
# Approve submission
POST /api/submissions/{id}/approve
# Check: SQL Database, Email
```

### Test HQ Analytics
```bash
# Get dashboard
GET /api/analytics/dashboard
# Check: SQL Database, OpenAI (narrative)
```

### Test Chatbot
```bash
# Send chat message
POST /api/chat/conversations/{id}/messages
# Check: OpenAI (embeddings), AI Search, OpenAI (GPT-4)
```

---

## Cost Optimization Tips

1. **Use caching**: Cache frequently accessed data (Redis)
2. **Batch processing**: Process embeddings in batches
3. **Optimize prompts**: Reduce token usage in GPT-4 calls
4. **Use appropriate tiers**: Start with Basic/Standard, scale up as needed
5. **Monitor usage**: Set up cost alerts in Azure Portal
6. **Use reserved capacity**: For predictable workloads

---

## Next Steps

1. Review this flow document to understand Azure service dependencies
2. Follow `AZURE_CONFIGURATION_GUIDE.md` to create and configure each service
3. Update `appsettings.json` with all configuration values
4. Test each flow independently
5. Test end-to-end workflows
6. Monitor and optimize

---

## Support

For Azure-specific issues:
- Azure Support Portal: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
- Azure Documentation: https://learn.microsoft.com/azure/

For application-specific issues:
- Check application logs in Azure App Service
- Review Application Insights for errors
- Check Azure Monitor for service health
