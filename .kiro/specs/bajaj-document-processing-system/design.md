# Design Document: Bajaj Document Processing System

## Overview

The Bajaj Document Processing System is a multi-agent application that automates document processing workflows for purchase orders, invoices, cost summaries, and supporting documentation. The system architecture follows a microservices pattern with specialized AI agents handling distinct responsibilities: document classification, validation, scoring, recommendations, email generation, analytics, notifications, and conversational assistance.

The system serves three user roles with distinct capabilities:
- **Agency**: Submit document packages and track status
- **ASM (Area Sales Manager)**: Review, approve, or reject submissions with AI-powered recommendations
- **HQ (Headquarters)**: Access analytics dashboards and conversational AI insights

### Technology Stack

- **Frontend**: Flutter (cross-platform mobile/web)
  - **State Management**: Riverpod (recommended) or BLoC pattern
  - **Architecture**: Clean Architecture with feature-based structure
  - **HTTP Client**: Dio with interceptors for auth and logging
  - **Local Storage**: Hive or SharedPreferences for caching
  - **Dependency Injection**: Riverpod providers or GetIt
  - **Navigation**: GoRouter for declarative routing
  - **Testing**: flutter_test, mockito, integration_test
- **Backend**: .NET 8 Web API
- **Database**: SQL Server (Azure SQL or on-premises)
- **AI Orchestration**: Semantic Kernel for AI workflow orchestration and plugin management
- **AI Services**: 
  - Azure OpenAI GPT-4 for natural language processing
  - Azure OpenAI text-embedding-ada-002 for vector embeddings
  - Azure Document Intelligence for document extraction
  - Azure Content Safety for guardrails
- **Vector Database**: Azure AI Search for semantic search over analytics embeddings
- **Communication**: Azure Communication Services (ACS) for email
- **Storage**: Azure Blob Storage for document files
- **Caching**: Redis for KPI caching (5-minute TTL)

### Design Principles

1. **Agent Specialization**: Each agent has a single, well-defined responsibility
2. **Asynchronous Processing**: Long-running operations (extraction, validation) execute asynchronously
3. **Idempotency**: All operations can be safely retried without side effects
4. **Audit Trail**: Every state change is logged with user attribution and timestamps
5. **Graceful Degradation**: External service failures don't block core workflows
6. **AI Safety**: Multi-layer guardrails prevent unauthorized access and harmful outputs
7. **Semantic Search**: Vector database enables natural language queries over structured data

### Semantic Kernel Integration

Semantic Kernel is the core orchestration framework for all AI operations in the system:

**Usage Areas**:

1. **ChatService**: Primary use case for conversational analytics
   - Plugin system for analytics functions
   - Automatic planning for multi-step queries
   - Memory management for conversation context
   
2. **RecommendationAgent**: Evidence generation using Semantic Kernel prompts
   - Structured prompts for consistent evidence format
   - Function calling for validation result retrieval
   
3. **EmailAgent**: Email content generation using Semantic Kernel templates
   - Scenario-based prompt templates
   - Dynamic content insertion based on validation results

**Benefits**:
- Consistent AI interaction patterns across all agents
- Built-in prompt management and versioning
- Automatic retry and error handling
- Telemetry and observability for AI operations

### Vector Database Architecture

**Purpose**: Enable semantic search over analytics data for natural language queries

**Implementation**: Azure AI Search

**Data Model**:

```json
{
  "id": "unique-id",
  "content": "Maharashtra had 150 submissions in January 2024 with 87% approval rate and average confidence score of 84",
  "contentVector": [0.123, 0.456, ...],  // 1536-dimensional embedding
  "metadata": {
    "state": "Maharashtra",
    "timeRange": "2024-01",
    "submissionCount": 150,
    "approvalRate": 0.87,
    "avgConfidence": 84,
    "campaigns": ["Campaign A", "Campaign B"]
  }
}
```

**Indexing Pipeline**:

1. **Daily Aggregation Job** (runs at 2 AM):
   - Query SQL database for previous day's metrics
   - Aggregate by state, campaign, date
   - Generate natural language descriptions
   - Create embeddings using text-embedding-ada-002
   - Upsert to Azure AI Search index

2. **Real-Time Updates** (optional):
   - On significant events (e.g., 100 new submissions), trigger immediate index update
   - Ensures ChatService has near-real-time data

**Search Configuration**:

- **Hybrid Search**: Combine vector similarity with keyword matching
- **Filters**: Apply metadata filters for authorization (state, date range)
- **Top K**: Retrieve top 5 most relevant results
- **Similarity Threshold**: Minimum cosine similarity of 0.7

### Guardrails Architecture

**Multi-Layer Defense**:

```
User Query → Input Guardrails → Authorization → Vector Search → 
Semantic Kernel Processing → Output Guardrails → Response
```

**Layer 1: Input Guardrails**

```csharp
public class InputGuardrailService
{
    public async Task ValidateInputAsync(string query)
    {
        // 1. Length check
        if (query.Length > 500)
            throw new ValidationException("Query too long");
        
        // 2. Prompt injection detection
        var safetyResult = await _contentSafetyClient.AnalyzeTextAsync(query);
        if (safetyResult.JailbreakDetected)
            throw new SecurityException("Potential prompt injection detected");
        
        // 3. SQL injection patterns
        if (Regex.IsMatch(query, @"(DROP|DELETE|INSERT|UPDATE|SELECT)\s", RegexOptions.IgnoreCase))
            throw new SecurityException("Invalid query pattern");
        
        // 4. Rate limiting
        var userQueryCount = await _rateLimiter.GetCountAsync(userId, TimeSpan.FromMinutes(1));
        if (userQueryCount >= 10)
            throw new RateLimitException("Too many queries");
    }
}
```

**Layer 2: Authorization Guardrails**

```csharp
public class AuthorizationGuardrailService
{
    public async Task<DataScope> GetUserDataScopeAsync(Guid userId)
    {
        var user = await _userService.GetUserAsync(userId);
        
        // Only HQ users can access ChatService
        if (user.Role != UserRole.HQ)
            throw new UnauthorizedException("Only HQ users can access analytics chat");
        
        // Return data scope for filtering
        return new DataScope
        {
            States = user.AllowedStates,  // null = all states
            Campaigns = user.AllowedCampaigns,  // null = all campaigns
            DateRange = user.AllowedDateRange  // null = all dates
        };
    }
}
```

**Layer 3: Output Guardrails**

```csharp
public class OutputGuardrailService
{
    public async Task ValidateOutputAsync(string response, List<VectorSearchResult> sourceData)
    {
        // 1. Citation verification
        var citations = ExtractCitations(response);
        foreach (var citation in citations)
        {
            if (!sourceData.Any(d => d.Content.Contains(citation)))
                throw new HallucinationException("Response contains uncited information");
        }
        
        // 2. PII detection and redaction
        var piiResult = await _contentSafetyClient.DetectPIIAsync(response);
        if (piiResult.PIIDetected)
        {
            response = RedactPII(response, piiResult.PIILocations);
        }
        
        // 3. Harmful content detection
        var safetyResult = await _contentSafetyClient.AnalyzeTextAsync(response);
        if (safetyResult.IsHarmful)
            throw new ContentSafetyException("Response contains harmful content");
        
        // 4. Numeric verification
        var numbers = ExtractNumbers(response);
        foreach (var number in numbers)
        {
            if (!VerifyAgainstDatabase(number))
                throw new HallucinationException("Response contains incorrect numeric data");
        }
    }
}
```

**Layer 4: Semantic Kernel Guardrails**

```csharp
public class SemanticKernelGuardrailService
{
    public IKernel BuildSecureKernel()
    {
        var kernel = Kernel.CreateBuilder()
            .AddAzureOpenAIChatCompletion("gpt-4", endpoint, apiKey)
            .Build();
        
        // Only allow approved plugins
        kernel.ImportPluginFromObject(new AnalyticsPlugin(_analyticsService));
        
        // Add function calling filter
        kernel.FunctionInvocationFilters.Add(new FunctionCallGuardrail());
        
        // Add prompt rendering filter
        kernel.PromptRenderingFilters.Add(new PromptInjectionGuardrail());
        
        // Set execution timeout
        kernel.FunctionInvocationFilters.Add(new TimeoutGuardrail(TimeSpan.FromSeconds(30)));
        
        return kernel;
    }
}
```

## Architecture


### System Architecture Diagram

```mermaid
graph TB
    subgraph "Flutter Frontend"
        UI[User Interface]
        AuthModule[Auth Module]
        FileUpload[File Upload]
        Dashboard[Dashboard]
        Chat[Chat Interface]
    end
    
    subgraph ".NET API Backend"
        API[API Gateway]
        AuthService[Auth Service]
        FileService[File Service]
        WorkflowOrchestrator[Workflow Orchestrator]
    end
    
    subgraph "AI Agents"
        DocAgent[Document Agent]
        ValAgent[Validation Agent]
        ConfService[Confidence Score Service]
        RecAgent[Recommendation Agent]
        EmailAgent[Email Agent]
        AnalyticsAgent[Analytics Agent]
        NotifAgent[Notification Agent]
        ChatService[Chat Service]
    end
    
    subgraph "Data Layer"
        SQL[(SQL Database)]
        BlobStorage[(Blob Storage)]
        VectorDB[(Vector Database)]
    end
    
    subgraph "External Services"
        SAP[SAP System]
        ACS[Azure Communication Services]
        AzureAI[Azure OpenAI]
        DocIntel[Azure Document Intelligence]
    end
    
    UI --> API
    API --> AuthService
    API --> FileService
    API --> WorkflowOrchestrator
    
    WorkflowOrchestrator --> DocAgent
    WorkflowOrchestrator --> ValAgent
    WorkflowOrchestrator --> ConfService
    WorkflowOrchestrator --> RecAgent
    WorkflowOrchestrator --> EmailAgent
    WorkflowOrchestrator --> NotifAgent
    
    Dashboard --> AnalyticsAgent
    Chat --> ChatService
    
    DocAgent --> DocIntel
    DocAgent --> AzureAI
    ValAgent --> SAP
    EmailAgent --> ACS
    NotifAgent --> ACS
    ChatService --> VectorDB
    ChatService --> AzureAI
    AnalyticsAgent --> SQL
    
    FileService --> BlobStorage
    WorkflowOrchestrator --> SQL
    AuthService --> SQL
```

### Processing Flow


```mermaid
sequenceDiagram
    participant Agency
    participant API
    participant FileService
    participant Orchestrator
    participant DocAgent
    participant ValAgent
    participant ConfService
    participant RecAgent
    participant EmailAgent
    participant NotifAgent
    participant ASM
    
    Agency->>API: Upload Document Package
    API->>FileService: Store files in Blob Storage
    FileService-->>API: File URLs
    API->>Orchestrator: Initiate Processing
    Orchestrator-->>Agency: Submission Accepted (202)
    
    Orchestrator->>DocAgent: Extract & Classify Documents
    DocAgent->>DocAgent: Process each document
    DocAgent-->>Orchestrator: Extracted Data
    
    Orchestrator->>ValAgent: Validate Package
    ValAgent->>ValAgent: Cross-document validation
    ValAgent->>ValAgent: SAP verification
    ValAgent-->>Orchestrator: Validation Results
    
    Orchestrator->>ConfService: Calculate Confidence
    ConfService-->>Orchestrator: Confidence Score
    
    Orchestrator->>RecAgent: Generate Recommendation
    RecAgent-->>Orchestrator: Recommendation + Evidence
    
    Orchestrator->>EmailAgent: Generate Email
    EmailAgent-->>Orchestrator: Email Sent
    
    Orchestrator->>NotifAgent: Send Notifications
    NotifAgent-->>ASM: In-app + Email Notification
    NotifAgent-->>Agency: Status Update
```

### Workflow States

A Document Package progresses through these states:

1. **UPLOADED**: Files received, awaiting processing
2. **EXTRACTING**: DocumentAgent processing documents
3. **VALIDATING**: ValidationAgent checking consistency
4. **SCORING**: ConfidenceScoreService calculating score
5. **RECOMMENDING**: RecommendationAgent generating recommendation
6. **PENDING_APPROVAL**: Awaiting ASM decision
7. **APPROVED**: ASM approved the package
8. **REJECTED**: ASM rejected the package
9. **REUPLOAD_REQUESTED**: ASM requested corrections

## Components and Interfaces


### 1. API Gateway

**Responsibility**: Route requests, authenticate users, validate inputs

**Endpoints**:

```
POST   /api/auth/login
POST   /api/auth/logout
GET    /api/auth/me

POST   /api/submissions
GET    /api/submissions/{id}
GET    /api/submissions
PATCH  /api/submissions/{id}/approve
PATCH  /api/submissions/{id}/reject
PATCH  /api/submissions/{id}/request-reupload

POST   /api/documents/upload
GET    /api/documents/{id}

GET    /api/analytics/kpis
GET    /api/analytics/state-roi
GET    /api/analytics/campaign-breakdown
POST   /api/analytics/export

POST   /api/chat/message
GET    /api/chat/history

GET    /api/notifications
PATCH  /api/notifications/{id}/read
```

**Authentication**: JWT tokens with role claims (Agency, ASM, HQ)

**Request Validation**: FluentValidation for all DTOs

**Error Handling**: Global exception middleware returning standardized error responses

### 2. Document Agent

**Responsibility**: Classify documents and extract structured fields

**Technology**: Azure Document Intelligence (Form Recognizer) + Azure OpenAI for classification

**Processing Pipeline**:

1. **Classification**: Use Azure OpenAI GPT-4 Vision to classify document type
2. **Extraction**: Use Azure Document Intelligence custom models for each document type
3. **Confidence Calculation**: Per-field confidence from Document Intelligence
4. **Persistence**: Store extracted data in SQL database

**Document Type Models**:

- **PO Model**: Extract PO number, vendor, date, line items, amounts
- **Invoice Model**: Extract invoice number, date, line items, amounts, tax
- **Cost Summary Model**: Extract campaign details, cost breakdowns, totals
- **Photo Model**: Extract EXIF metadata (timestamp, location, device)

**Interface**:

```csharp
public interface IDocumentAgent
{
    Task<DocumentClassification> ClassifyAsync(string blobUrl);
    Task<POData> ExtractPOAsync(string blobUrl);
    Task<InvoiceData> ExtractInvoiceAsync(string blobUrl);
    Task<CostSummaryData> ExtractCostSummaryAsync(string blobUrl);
    Task<PhotoMetadata> ExtractPhotoMetadataAsync(string blobUrl);
}
```

### 3. Validation Agent

**Responsibility**: Cross-document validation and SAP verification

**Validation Rules**:


1. **SAP PO Verification**: Query SAP OData API to verify PO exists and matches extracted data
2. **Amount Consistency**: Invoice total matches Cost Summary total (±2% tolerance)
3. **Line Item Matching**: All PO line items appear in Invoice
4. **Completeness Check**: All 11 required items present (PO, Invoice, Cost Summary, Activity records, Photos, etc.)
5. **Date Validation**: Invoice date >= PO date, Invoice date <= Submission date
6. **Vendor Matching**: PO vendor matches Invoice vendor

**SAP Integration**:

- Use SAP OData API for PO lookup
- Implement circuit breaker pattern for SAP failures
- Queue validation requests when SAP unavailable
- Retry with exponential backoff (3 attempts)

**Interface**:

```csharp
public interface IValidationAgent
{
    Task<ValidationResult> ValidatePackageAsync(Guid packageId);
    Task<SAPVerificationResult> VerifySAPPOAsync(string poNumber);
    Task<bool> ValidateAmountConsistencyAsync(decimal invoiceTotal, decimal costSummaryTotal);
    Task<bool> ValidateLineItemsAsync(List<POLineItem> poItems, List<InvoiceLineItem> invoiceItems);
    Task<CompletenessResult> ValidateCompletenessAsync(DocumentPackage package);
}
```

### 4. Confidence Score Service

**Responsibility**: Calculate weighted confidence scores

**Scoring Formula**:

```
OverallConfidence = (PO_Confidence × 0.30) + 
                    (Invoice_Confidence × 0.30) + 
                    (CostSummary_Confidence × 0.20) + 
                    (Activity_Confidence × 0.10) + 
                    (Photos_Confidence × 0.10)
```

**Per-Document Confidence**:

- Average of all field-level confidences from Document Intelligence
- Minimum threshold: 60% per field
- Missing required fields: 0% confidence for that document

**Interface**:

```csharp
public interface IConfidenceScoreService
{
    Task<ConfidenceScore> CalculateAsync(Guid packageId);
    double CalculateDocumentConfidence(Dictionary<string, double> fieldConfidences);
}
```

### 5. Recommendation Agent

**Responsibility**: Generate approval recommendations with evidence

**Decision Logic**:

```
IF Confidence >= 85 AND Validation.AllPassed THEN APPROVE
ELSE IF Confidence >= 70 AND Confidence < 85 THEN REVIEW
ELSE IF Confidence < 70 OR Validation.AnyFailed THEN REJECT
```

**Evidence Generation**:

Use Azure OpenAI GPT-4 to generate natural language evidence summary:

- Input: Validation results, confidence scores, field-level details
- Output: Plain-English summary with specific citations
- Example: "PO #12345 verified in SAP. Invoice total ($10,500) matches Cost Summary within tolerance. All line items present. High confidence (92%) across all documents."

**Interface**:

```csharp
public interface IRecommendationAgent
{
    Task<Recommendation> GenerateAsync(Guid packageId);
}

public class Recommendation
{
    public RecommendationType Type { get; set; } // APPROVE, REVIEW, REJECT
    public string Evidence { get; set; }
    public List<string> ValidationIssues { get; set; }
    public double ConfidenceScore { get; set; }
}
```

### 6. Email Agent

**Responsibility**: Generate and send scenario-based emails

**Email Scenarios**:


1. **Data Failure - Re-upload Request**: Sent to Agency when validation fails
   - Include specific fields needing correction
   - Provide clear instructions
   
2. **Data Pass - ASM Approval**: Sent to ASM when validation passes
   - Include confidence score and recommendation
   - Link to approval interface
   
3. **Approved**: Sent to Agency when ASM approves
   - Confirmation message
   - Next steps
   
4. **Rejected**: Sent to Agency when ASM rejects
   - Reason for rejection
   - Re-submission instructions

**Template Generation**:

Use Azure OpenAI to generate personalized email content based on:
- Scenario type
- Validation results
- User role
- Specific field issues

**Delivery**:

- Azure Communication Services (ACS) for email delivery
- Retry logic: 3 attempts with exponential backoff (1s, 2s, 4s)
- Store delivery status in database
- Alert administrators on persistent failures

**Interface**:

```csharp
public interface IEmailAgent
{
    Task<EmailResult> SendDataFailureEmailAsync(Guid packageId, List<ValidationIssue> issues);
    Task<EmailResult> SendDataPassEmailAsync(Guid packageId, string asmEmail);
    Task<EmailResult> SendApprovedEmailAsync(Guid packageId, string agencyEmail);
    Task<EmailResult> SendRejectedEmailAsync(Guid packageId, string agencyEmail, string reason);
}
```

### 7. Analytics Agent

**Responsibility**: Generate KPIs, dashboards, and AI narratives

**KPI Calculations**:

1. **Total Submissions**: Count of all Document Packages
2. **Approval Rate**: (Approved / Total) × 100
3. **Average Processing Time**: Mean time from submission to decision
4. **Auto-Approval Rate**: Packages approved without ASM intervention
5. **Confidence Distribution**: Histogram of confidence scores
6. **State-Level ROI**: ROI metrics grouped by state
7. **Campaign Performance**: Submission counts and approval rates by campaign

**Data Aggregation**:

- Real-time queries against SQL database
- Materialized views for expensive aggregations
- Caching layer (Redis) for frequently accessed metrics (5-minute TTL)

**AI Narrative Generation**:

Use Azure OpenAI GPT-4 to generate insights:

```
Input: KPI data, trends, anomalies
Output: "This week saw a 15% increase in submissions from Maharashtra, 
         with an approval rate of 87%, up from 82% last week. 
         The average confidence score improved to 84, indicating 
         better document quality from agencies."
```

**Export Functionality**:

- Generate Excel files using EPPlus library
- Include all KPIs, state breakdowns, campaign data
- Format with Bajaj branding (colors, logo)

**Interface**:

```csharp
public interface IAnalyticsAgent
{
    Task<KPIDashboard> GetKPIsAsync(DateRange range);
    Task<List<StateROI>> GetStateROIAsync(DateRange range);
    Task<List<CampaignBreakdown>> GetCampaignBreakdownAsync(DateRange range);
    Task<byte[]> ExportToExcelAsync(DateRange range);
    Task<string> GenerateNarrativeAsync(KPIDashboard kpis);
}
```

### 8. Notification Agent

**Responsibility**: Manage in-app and email notifications

**Notification Types**:


1. **Submission Received** (to ASM): New package awaiting review
2. **Flagged for Review** (to ASM): Low confidence or validation issues
3. **Approved** (to Agency): Package approved by ASM
4. **Rejected** (to Agency): Package rejected by ASM
5. **Re-upload Requested** (to Agency): Corrections needed

**Delivery Channels**:

- **In-App**: Store in database, display in notification inbox
- **Email**: Send via ACS with retry logic

**Notification Storage**:

```sql
Notifications Table:
- Id (GUID)
- UserId (GUID)
- Type (enum)
- Title (string)
- Message (string)
- IsRead (bool)
- CreatedAt (datetime)
- ReadAt (datetime, nullable)
- RelatedEntityId (GUID, nullable)
```

**Interface**:

```csharp
public interface INotificationAgent
{
    Task SendNotificationAsync(Guid userId, NotificationType type, string title, string message, Guid? relatedEntityId = null);
    Task<List<Notification>> GetUserNotificationsAsync(Guid userId, bool unreadOnly = false);
    Task MarkAsReadAsync(Guid notificationId);
}
```

### 9. Chat Service

**Responsibility**: Conversational AI assistant for analytics queries

**Technology Stack**:

- **Semantic Kernel**: Orchestration framework for AI workflows
- **Azure OpenAI GPT-4**: Language model for natural language understanding and generation
- **Vector Database**: Azure AI Search for semantic search over analytics embeddings
- **Embeddings**: text-embedding-ada-002 for analytics data vectorization

**Semantic Kernel Architecture**:

The ChatService is built entirely on Semantic Kernel, which provides:

1. **Plugin System**: Modular functions for analytics queries
2. **Planner**: Automatic orchestration of multi-step queries
3. **Memory**: Conversation context management
4. **Connectors**: Integration with Azure OpenAI and Vector Database

**Semantic Kernel Plugins**:

```csharp
public class AnalyticsPlugin
{
    [KernelFunction, Description("Get KPI metrics for a date range")]
    public async Task<string> GetKPIs(string startDate, string endDate) { ... }
    
    [KernelFunction, Description("Get state-level ROI data")]
    public async Task<string> GetStateROI(string state) { ... }
    
    [KernelFunction, Description("Get campaign performance data")]
    public async Task<string> GetCampaignData(string campaignName) { ... }
    
    [KernelFunction, Description("Search analytics data semantically")]
    public async Task<string> SearchAnalytics(string query) { ... }
}
```

**Vector Database Implementation**:

1. **Embedding Pipeline**: Nightly job to vectorize analytics data
   - Aggregate daily/weekly/monthly metrics from SQL database
   - Generate text descriptions of data points (e.g., "Maharashtra had 150 submissions in January 2024 with 87% approval rate")
   - Create embeddings using text-embedding-ada-002
   - Store embeddings in Azure AI Search with metadata (date range, state, campaign, metrics)
   
2. **Vector Search**:
   - User query is embedded using the same model
   - Cosine similarity search in Azure AI Search
   - Retrieve top 5 most relevant analytics data points
   - Pass retrieved context to Semantic Kernel for response generation

**Guardrails Implementation**:

The ChatService implements multiple layers of guardrails to ensure safe and authorized operation:

1. **Input Guardrails**:
   - **Prompt Injection Detection**: Use Azure Content Safety API to detect jailbreak attempts
   - **Input Sanitization**: Remove special characters and SQL injection patterns
   - **Query Length Limits**: Maximum 500 characters per query
   - **Rate Limiting**: Maximum 10 queries per minute per user

2. **Authorization Guardrails**:
   - **Role Verification**: Only HQ users can access ChatService (checked before every query)
   - **Data Scope Filtering**: Filter vector search results to only include data the user has permission to view
   - **State-Level Access**: If user has state-specific permissions, filter results to that state

3. **Output Guardrails**:
   - **Response Validation**: Ensure responses only cite data from vector search results
   - **PII Redaction**: Scan responses for personal information and redact if found
   - **Hallucination Detection**: Verify all numeric claims against actual database values
   - **Content Safety**: Use Azure Content Safety API to check for harmful content in responses

4. **Semantic Kernel Guardrails**:
   - **Function Calling Restrictions**: Only allow calls to approved AnalyticsPlugin functions
   - **Parameter Validation**: Validate all function parameters before execution
   - **Execution Timeout**: Maximum 30 seconds per query execution
   - **Error Handling**: Catch and sanitize all errors before returning to user

**Query Processing Flow with Semantic Kernel**:

```csharp
public async Task<ChatResponse> ProcessQueryAsync(Guid userId, string query, Guid? conversationId)
{
    // 1. Input Guardrails
    await _guardrailService.ValidateInputAsync(query);
    
    // 2. Authorization Check
    var user = await _userService.GetUserAsync(userId);
    if (user.Role != UserRole.HQ)
        throw new UnauthorizedException("Only HQ users can access analytics chat");
    
    // 3. Vector Search
    var embedding = await _embeddingService.GenerateEmbeddingAsync(query);
    var relevantData = await _vectorDatabase.SearchAsync(embedding, topK: 5, filter: user.DataScope);
    
    // 4. Semantic Kernel Processing
    var kernel = _kernelBuilder
        .AddAzureOpenAIChatCompletion("gpt-4", endpoint, apiKey)
        .Build();
    
    kernel.ImportPluginFromObject(new AnalyticsPlugin(_analyticsService));
    
    var context = string.Join("\n", relevantData.Select(d => d.Text));
    var prompt = $@"
        You are an analytics assistant for the Bajaj Document Processing System.
        Answer the user's question using ONLY the provided context.
        Always cite specific data sources and time ranges.
        
        Context:
        {context}
        
        User Question: {query}
    ";
    
    var result = await kernel.InvokePromptAsync(prompt);
    
    // 5. Output Guardrails
    var response = result.ToString();
    await _guardrailService.ValidateOutputAsync(response, relevantData);
    
    // 6. Store Conversation
    await _conversationService.SaveMessageAsync(conversationId, query, response);
    
    return new ChatResponse
    {
        Message = response,
        Citations = relevantData.Select(d => new DataCitation { Source = d.Source, TimeRange = d.TimeRange }).ToList(),
        ConversationId = conversationId ?? Guid.NewGuid()
    };
}
```

**Conversation Context Management**:

- Semantic Kernel Memory stores last 10 messages
- Context is passed to each query for continuity
- Conversations stored in SQL database for audit
- Clear context on new session or user request

**Interface**:

```csharp
public interface IChatService
{
    Task<ChatResponse> ProcessQueryAsync(Guid userId, string query, Guid? conversationId = null);
    Task<List<ChatMessage>> GetConversationHistoryAsync(Guid conversationId);
    Task ClearConversationAsync(Guid conversationId);
}

public class ChatResponse
{
    public string Message { get; set; }
    public List<DataCitation> Citations { get; set; }
    public Guid ConversationId { get; set; }
}

public class DataCitation
{
    public string Source { get; set; }
    public string TimeRange { get; set; }
    public Dictionary<string, object> Metrics { get; set; }
}
```

### 10. Workflow Orchestrator

**Responsibility**: Coordinate agent execution and manage state transitions

**Orchestration Pattern**: Saga pattern with compensation

**Processing Steps**:


```csharp
public async Task ProcessSubmissionAsync(Guid packageId)
{
    try
    {
        // Step 1: Extract documents
        await UpdateStateAsync(packageId, PackageState.EXTRACTING);
        var extractionResults = await _documentAgent.ExtractAllAsync(packageId);
        
        // Step 2: Validate package
        await UpdateStateAsync(packageId, PackageState.VALIDATING);
        var validationResults = await _validationAgent.ValidatePackageAsync(packageId);
        
        // Step 3: Calculate confidence
        await UpdateStateAsync(packageId, PackageState.SCORING);
        var confidenceScore = await _confidenceScoreService.CalculateAsync(packageId);
        
        // Step 4: Generate recommendation
        await UpdateStateAsync(packageId, PackageState.RECOMMENDING);
        var recommendation = await _recommendationAgent.GenerateAsync(packageId);
        
        // Step 5: Send notifications
        await UpdateStateAsync(packageId, PackageState.PENDING_APPROVAL);
        
        if (validationResults.AllPassed)
        {
            await _emailAgent.SendDataPassEmailAsync(packageId, asmEmail);
            await _notificationAgent.SendNotificationAsync(asmUserId, NotificationType.SubmissionReceived, ...);
        }
        else
        {
            await _emailAgent.SendDataFailureEmailAsync(packageId, validationResults.Issues);
            await _notificationAgent.SendNotificationAsync(agencyUserId, NotificationType.ReuploadRequested, ...);
        }
    }
    catch (Exception ex)
    {
        await HandleErrorAsync(packageId, ex);
    }
}
```

**Error Handling**:

- Transient failures: Retry with exponential backoff
- Permanent failures: Mark package as ERROR state, notify administrators
- Compensation: Rollback state changes on critical failures

**Idempotency**:

- Each step checks if already completed before executing
- Use database transactions for state updates
- Store operation results to prevent duplicate processing

## Data Models

### Hierarchical Structure

The database follows a hierarchical structure for document organization:

```
FAP (DocumentPackage)
  └── 1 PO (Document where Type=PO)
        └── Multiple Invoices
              └── Multiple Campaigns (per Invoice)
                    └── Multiple Photos (per Campaign)
```

### Core Entities

**DocumentPackage** (FAP - Field Activity Package):

```csharp
public class DocumentPackage
{
    public Guid Id { get; set; }
    public Guid AgencyUserId { get; set; }
    public Guid? AssignedASMId { get; set; }
    public PackageState State { get; set; }
    public DateTime SubmittedAt { get; set; }
    public DateTime? ProcessedAt { get; set; }
    public DateTime? DecisionAt { get; set; }
    
    // Navigation properties
    public List<Document> Documents { get; set; }  // Contains the single PO document
    public List<Invoice> Invoices { get; set; }    // Multiple invoices linked to PO
    public List<Campaign> Campaigns { get; set; }  // All campaigns (for easier querying)
    public List<CampaignPhoto> CampaignPhotos { get; set; }  // All photos (for easier querying)
    public ValidationResult ValidationResult { get; set; }
    public ConfidenceScore ConfidenceScore { get; set; }
    public Recommendation Recommendation { get; set; }
}

public enum PackageState
{
    UPLOADED,
    EXTRACTING,
    VALIDATING,
    SCORING,
    RECOMMENDING,
    PENDING_APPROVAL,
    APPROVED,
    REJECTED,
    REUPLOAD_REQUESTED,
    ERROR
}
```

**Document** (PO Document):

```csharp
public class Document
{
    public Guid Id { get; set; }
    public Guid PackageId { get; set; }
    public DocumentType Type { get; set; }
    public string BlobUrl { get; set; }
    public string FileName { get; set; }
    public long FileSizeBytes { get; set; }
    public DateTime UploadedAt { get; set; }
    
    // Extracted data (JSON columns)
    public string ExtractedDataJson { get; set; }
    public double? ExtractionConfidence { get; set; }
    
    // Navigation for linked invoices (only for PO documents)
    public List<Invoice> LinkedInvoices { get; set; }
}

public enum DocumentType
{
    PO,
    Invoice,
    CostSummary,
    Photo,
    AdditionalDocument,
    ActivityRecord
}
```

**Invoice** (linked to PO):

```csharp
public class Invoice
{
    public Guid Id { get; set; }
    public Guid PackageId { get; set; }
    public Guid PODocumentId { get; set; }
    
    // Invoice data
    public string InvoiceNumber { get; set; }
    public DateTime? InvoiceDate { get; set; }
    public string VendorName { get; set; }
    public string GSTNumber { get; set; }
    public decimal? SubTotal { get; set; }
    public decimal? TaxAmount { get; set; }
    public decimal? TotalAmount { get; set; }
    
    // File info
    public string FileName { get; set; }
    public string BlobUrl { get; set; }
    public long FileSizeBytes { get; set; }
    public string ContentType { get; set; }
    public string ExtractedDataJson { get; set; }
    public double? ExtractionConfidence { get; set; }
    public bool IsFlaggedForReview { get; set; }
    
    // Navigation
    public DocumentPackage Package { get; set; }
    public Document PODocument { get; set; }
    public List<Campaign> Campaigns { get; set; }
}
```

**Campaign** (linked to Invoice):

```csharp
public class Campaign
{
    public Guid Id { get; set; }
    public Guid InvoiceId { get; set; }
    public Guid PackageId { get; set; }
    
    // Campaign details
    public string CampaignName { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int? WorkingDays { get; set; }
    public string DealershipName { get; set; }
    public string DealershipAddress { get; set; }
    public string GPSLocation { get; set; }
    public string State { get; set; }
    public decimal? TotalCost { get; set; }
    public string CostBreakdownJson { get; set; }
    public string TeamsJson { get; set; }
    
    // Cost Summary document (optional)
    public string CostSummaryFileName { get; set; }
    public string CostSummaryBlobUrl { get; set; }
    public string CostSummaryExtractedDataJson { get; set; }
    public double? CostSummaryExtractionConfidence { get; set; }
    
    // Navigation
    public Invoice Invoice { get; set; }
    public DocumentPackage Package { get; set; }
    public List<CampaignPhoto> Photos { get; set; }
}
```

**CampaignPhoto** (linked to Campaign):

```csharp
public class CampaignPhoto
{
    public Guid Id { get; set; }
    public Guid CampaignId { get; set; }
    public Guid PackageId { get; set; }
    
    // File info
    public string FileName { get; set; }
    public string BlobUrl { get; set; }
    public long FileSizeBytes { get; set; }
    public string ContentType { get; set; }
    public string Caption { get; set; }
    
    // EXIF metadata
    public DateTime? PhotoTimestamp { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string DeviceModel { get; set; }
    public string ExtractedMetadataJson { get; set; }
    public double? ExtractionConfidence { get; set; }
    public bool IsFlaggedForReview { get; set; }
    public int DisplayOrder { get; set; }
    
    // Navigation
    public Campaign Campaign { get; set; }
    public DocumentPackage Package { get; set; }
}
```

**POData** (stored as JSON in Document.ExtractedDataJson):

```csharp
public class POData
{
    public string PONumber { get; set; }
    public string VendorName { get; set; }
    public DateTime PODate { get; set; }
    public List<POLineItem> LineItems { get; set; }
    public decimal TotalAmount { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; }
}

public class POLineItem
{
    public string ItemCode { get; set; }
    public string Description { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
}
```

**InvoiceData** (stored as JSON):


```csharp
public class InvoiceData
{
    public string InvoiceNumber { get; set; }
    public string VendorName { get; set; }
    public DateTime InvoiceDate { get; set; }
    public List<InvoiceLineItem> LineItems { get; set; }
    public decimal SubTotal { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; }
}

public class InvoiceLineItem
{
    public string ItemCode { get; set; }
    public string Description { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
}
```

**CostSummaryData** (stored as JSON):

```csharp
public class CostSummaryData
{
    public string CampaignName { get; set; }
    public string State { get; set; }
    public DateTime CampaignStartDate { get; set; }
    public DateTime CampaignEndDate { get; set; }
    public List<CostBreakdown> CostBreakdowns { get; set; }
    public decimal TotalCost { get; set; }
    public Dictionary<string, double> FieldConfidences { get; set; }
}

public class CostBreakdown
{
    public string Category { get; set; }
    public decimal Amount { get; set; }
}
```

**ValidationResult**:

```csharp
public class ValidationResult
{
    public Guid Id { get; set; }
    public Guid PackageId { get; set; }
    public bool AllPassed { get; set; }
    public DateTime ValidatedAt { get; set; }
    
    public bool SAPVerificationPassed { get; set; }
    public bool AmountConsistencyPassed { get; set; }
    public bool LineItemMatchingPassed { get; set; }
    public bool CompletenessCheckPassed { get; set; }
    public bool DateValidationPassed { get; set; }
    public bool VendorMatchingPassed { get; set; }
    
    public List<ValidationIssue> Issues { get; set; }
}

public class ValidationIssue
{
    public string Field { get; set; }
    public string IssueType { get; set; }
    public string Description { get; set; }
    public string ExpectedValue { get; set; }
    public string ActualValue { get; set; }
}
```

**ConfidenceScore**:

```csharp
public class ConfidenceScore
{
    public Guid Id { get; set; }
    public Guid PackageId { get; set; }
    public double OverallScore { get; set; }
    public double POConfidence { get; set; }
    public double InvoiceConfidence { get; set; }
    public double CostSummaryConfidence { get; set; }
    public double ActivityConfidence { get; set; }
    public double PhotosConfidence { get; set; }
    public DateTime CalculatedAt { get; set; }
}
```

**Recommendation**:

```csharp
public class Recommendation
{
    public Guid Id { get; set; }
    public Guid PackageId { get; set; }
    public RecommendationType Type { get; set; }
    public string Evidence { get; set; }
    public DateTime GeneratedAt { get; set; }
}

public enum RecommendationType
{
    APPROVE,
    REVIEW,
    REJECT
}
```

**User**:

```csharp
public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; }
    public string PasswordHash { get; set; }
    public UserRole Role { get; set; }
    public string FullName { get; set; }
    public string State { get; set; } // For Agency and ASM users
    public DateTime CreatedAt { get; set; }
    public DateTime? LastLoginAt { get; set; }
}

public enum UserRole
{
    Agency,
    ASM,
    HQ
}
```

**Notification**:

```csharp
public class Notification
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; }
    public string Message { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ReadAt { get; set; }
    public Guid? RelatedEntityId { get; set; }
}

public enum NotificationType
{
    SubmissionReceived,
    FlaggedForReview,
    Approved,
    Rejected,
    ReuploadRequested
}
```

### Database Schema


```sql
-- Users table
CREATE TABLE Users (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Email NVARCHAR(255) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    Role NVARCHAR(50) NOT NULL,
    FullName NVARCHAR(255) NOT NULL,
    State NVARCHAR(100),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    LastLoginAt DATETIME2
);

-- DocumentPackages table
CREATE TABLE DocumentPackages (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AgencyUserId UNIQUEIDENTIFIER NOT NULL,
    AssignedASMId UNIQUEIDENTIFIER,
    State NVARCHAR(50) NOT NULL,
    SubmittedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ProcessedAt DATETIME2,
    DecisionAt DATETIME2,
    FOREIGN KEY (AgencyUserId) REFERENCES Users(Id),
    FOREIGN KEY (AssignedASMId) REFERENCES Users(Id)
);

-- Documents table
CREATE TABLE Documents (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PackageId UNIQUEIDENTIFIER NOT NULL,
    Type NVARCHAR(50) NOT NULL,
    BlobUrl NVARCHAR(1000) NOT NULL,
    FileName NVARCHAR(255) NOT NULL,
    FileSizeBytes BIGINT NOT NULL,
    UploadedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ExtractedDataJson NVARCHAR(MAX),
    ExtractionConfidence FLOAT,
    FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE CASCADE
);

-- ValidationResults table
CREATE TABLE ValidationResults (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PackageId UNIQUEIDENTIFIER NOT NULL UNIQUE,
    AllPassed BIT NOT NULL,
    ValidatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    SAPVerificationPassed BIT NOT NULL,
    AmountConsistencyPassed BIT NOT NULL,
    LineItemMatchingPassed BIT NOT NULL,
    CompletenessCheckPassed BIT NOT NULL,
    DateValidationPassed BIT NOT NULL,
    VendorMatchingPassed BIT NOT NULL,
    IssuesJson NVARCHAR(MAX),
    FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE CASCADE
);

-- ConfidenceScores table
CREATE TABLE ConfidenceScores (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PackageId UNIQUEIDENTIFIER NOT NULL UNIQUE,
    OverallScore FLOAT NOT NULL,
    POConfidence FLOAT NOT NULL,
    InvoiceConfidence FLOAT NOT NULL,
    CostSummaryConfidence FLOAT NOT NULL,
    ActivityConfidence FLOAT NOT NULL,
    PhotosConfidence FLOAT NOT NULL,
    CalculatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE CASCADE
);

-- Recommendations table
CREATE TABLE Recommendations (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PackageId UNIQUEIDENTIFIER NOT NULL UNIQUE,
    Type NVARCHAR(50) NOT NULL,
    Evidence NVARCHAR(MAX) NOT NULL,
    GeneratedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE CASCADE
);

-- Notifications table
CREATE TABLE Notifications (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL,
    Type NVARCHAR(50) NOT NULL,
    Title NVARCHAR(255) NOT NULL,
    Message NVARCHAR(MAX) NOT NULL,
    IsRead BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    ReadAt DATETIME2,
    RelatedEntityId UNIQUEIDENTIFIER,
    FOREIGN KEY (UserId) REFERENCES Users(Id) ON DELETE CASCADE
);

-- AuditLog table
CREATE TABLE AuditLog (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER,
    Action NVARCHAR(255) NOT NULL,
    EntityType NVARCHAR(100),
    EntityId UNIQUEIDENTIFIER,
    Details NVARCHAR(MAX),
    IPAddress NVARCHAR(50),
    Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    FOREIGN KEY (UserId) REFERENCES Users(Id)
);

-- Indexes
CREATE INDEX IX_DocumentPackages_AgencyUserId ON DocumentPackages(AgencyUserId);
CREATE INDEX IX_DocumentPackages_AssignedASMId ON DocumentPackages(AssignedASMId);
CREATE INDEX IX_DocumentPackages_State ON DocumentPackages(State);
CREATE INDEX IX_Documents_PackageId ON Documents(PackageId);
CREATE INDEX IX_Notifications_UserId_IsRead ON Notifications(UserId, IsRead);
CREATE INDEX IX_AuditLog_UserId ON AuditLog(UserId);
CREATE INDEX IX_AuditLog_Timestamp ON AuditLog(Timestamp);

-- =============================================
-- Hierarchical Structure Tables
-- FAP -> PO -> Invoices -> Campaigns -> Photos
-- =============================================

-- Invoices table (linked to PO document)
CREATE TABLE Invoices (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    PackageId UNIQUEIDENTIFIER NOT NULL,
    PODocumentId UNIQUEIDENTIFIER NOT NULL,
    InvoiceNumber NVARCHAR(100),
    InvoiceDate DATETIME2,
    VendorName NVARCHAR(500),
    GSTNumber NVARCHAR(50),
    SubTotal DECIMAL(18,2),
    TaxAmount DECIMAL(18,2),
    TotalAmount DECIMAL(18,2),
    FileName NVARCHAR(512) NOT NULL,
    BlobUrl NVARCHAR(2048) NOT NULL,
    FileSizeBytes BIGINT NOT NULL,
    ContentType NVARCHAR(128) NOT NULL,
    ExtractedDataJson NVARCHAR(MAX),
    ExtractionConfidence FLOAT,
    IsFlaggedForReview BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE CASCADE,
    FOREIGN KEY (PODocumentId) REFERENCES Documents(Id) ON DELETE NO ACTION
);

CREATE INDEX IX_Invoices_PackageId ON Invoices(PackageId);
CREATE INDEX IX_Invoices_PODocumentId ON Invoices(PODocumentId);
CREATE INDEX IX_Invoices_InvoiceNumber ON Invoices(InvoiceNumber);

-- Campaigns table (linked to Invoice)
CREATE TABLE Campaigns (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    InvoiceId UNIQUEIDENTIFIER NOT NULL,
    PackageId UNIQUEIDENTIFIER NOT NULL,
    CampaignName NVARCHAR(500),
    StartDate DATETIME2,
    EndDate DATETIME2,
    WorkingDays INT,
    DealershipName NVARCHAR(500),
    DealershipAddress NVARCHAR(1000),
    GPSLocation NVARCHAR(100),
    State NVARCHAR(100),
    TotalCost DECIMAL(18,2),
    CostBreakdownJson NVARCHAR(MAX),
    TeamsJson NVARCHAR(MAX),
    CostSummaryFileName NVARCHAR(512),
    CostSummaryBlobUrl NVARCHAR(2048),
    CostSummaryExtractedDataJson NVARCHAR(MAX),
    CostSummaryExtractionConfidence FLOAT,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (InvoiceId) REFERENCES Invoices(Id) ON DELETE CASCADE,
    FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE NO ACTION
);

CREATE INDEX IX_Campaigns_InvoiceId ON Campaigns(InvoiceId);
CREATE INDEX IX_Campaigns_PackageId ON Campaigns(PackageId);
CREATE INDEX IX_Campaigns_State ON Campaigns(State);
CREATE INDEX IX_Campaigns_CampaignName ON Campaigns(CampaignName);

-- CampaignPhotos table (linked to Campaign)
CREATE TABLE CampaignPhotos (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    CampaignId UNIQUEIDENTIFIER NOT NULL,
    PackageId UNIQUEIDENTIFIER NOT NULL,
    FileName NVARCHAR(512) NOT NULL,
    BlobUrl NVARCHAR(2048) NOT NULL,
    FileSizeBytes BIGINT NOT NULL,
    ContentType NVARCHAR(128) NOT NULL,
    Caption NVARCHAR(1000),
    PhotoTimestamp DATETIME2,
    Latitude FLOAT,
    Longitude FLOAT,
    DeviceModel NVARCHAR(200),
    ExtractedMetadataJson NVARCHAR(MAX),
    ExtractionConfidence FLOAT,
    IsFlaggedForReview BIT NOT NULL DEFAULT 0,
    DisplayOrder INT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    IsDeleted BIT NOT NULL DEFAULT 0,
    FOREIGN KEY (CampaignId) REFERENCES Campaigns(Id) ON DELETE CASCADE,
    FOREIGN KEY (PackageId) REFERENCES DocumentPackages(Id) ON DELETE NO ACTION
);

CREATE INDEX IX_CampaignPhotos_CampaignId ON CampaignPhotos(CampaignId);
CREATE INDEX IX_CampaignPhotos_PackageId ON CampaignPhotos(PackageId);
CREATE INDEX IX_CampaignPhotos_PhotoTimestamp ON CampaignPhotos(PhotoTimestamp);
```

## Correctness Properties


A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

### Property Reflection

After analyzing all acceptance criteria, several properties can be combined to eliminate redundancy:

- **File Upload Validation (1.2-1.6)**: All document types follow the same validation pattern (format and size checks). These can be combined into a single property about document upload validation rules.

- **Confidence Score Weights (4.2-4.6)**: All weight assignments are part of the same calculation formula. These should be combined into a single property about weighted score calculation.

- **Recommendation Logic (5.3-5.5)**: The three recommendation rules (APPROVE, REVIEW, REJECT) are mutually exclusive cases of the same decision logic. These should be combined into a single property about recommendation generation based on score and validation state.

- **Role-Based Access (10.3-10.5)**: The three role-based access rules follow the same pattern. These can be combined into a single property about role-based authorization.

- **Document Extraction (2.2-2.4)**: All document types follow the same extraction pattern (extract all required fields). These can be combined into a single property about extraction completeness.

### Properties

**Property 1: Document Upload Validation**

*For any* document upload with a specific document type, file format, and file size, the system should accept the upload if and only if the format is in the allowed list for that document type and the size is within the limit for that document type.

**Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**

**Property 2: Upload Confirmation Display**

*For any* successful file upload, the confirmation message should contain both the filename and file size of the uploaded document.

**Validates: Requirements 1.8**

**Property 3: Photo Upload Limit**

*For any* submission, the system should accept up to 20 photos and reject any attempt to upload more than 20 photos.

**Validates: Requirements 1.9**

**Property 4: Submit Button Enablement**

*For any* submission form state, the submit button should be enabled if and only if all required documents (PO, Invoice, Cost Summary) are uploaded.

**Validates: Requirements 1.10**

**Property 5: Document Classification**

*For any* uploaded document, the DocumentAgent should classify it as exactly one of the valid document types (PO, Invoice, Cost_Summary, Photo, or Additional_Document).

**Validates: Requirements 2.1**

**Property 6: Extraction Completeness**

*For any* classified document of a specific type, the extracted data should contain all required fields for that document type with non-null values.

**Validates: Requirements 2.2, 2.3, 2.4**

**Property 7: Photo Metadata Extraction**

*For any* classified photo, the extracted metadata should contain timestamp and location fields (location may be null if not available in EXIF data).

**Validates: Requirements 2.5**

**Property 8: Low Confidence Flagging**

*For any* document where classification confidence is below the threshold, the DocumentAgent should flag it for manual review.

**Validates: Requirements 2.6**

**Property 9: Extraction Persistence Round-Trip**

*For any* extracted document data, persisting it to the database and then retrieving it should produce equivalent data.

**Validates: Requirements 2.7**

**Property 10: SAP PO Verification**

*For any* Document Package with a PO, the ValidationAgent should verify that the PO number exists in SAP and that key fields (vendor, amount, date) match the SAP record.

**Validates: Requirements 3.1**

**Property 11: Amount Consistency Validation**

*For any* Document Package, if the absolute difference between Invoice total and Cost Summary total is within 2% of the Invoice total, the amount consistency validation should pass; otherwise it should fail.

**Validates: Requirements 3.2**

**Property 12: Line Item Matching**

*For any* Document Package, the line item validation should pass if and only if every PO line item (by item code) appears in the Invoice line items.

**Validates: Requirements 3.3**

**Property 13: Completeness Validation**

*For any* Document Package, the completeness validation should pass if and only if all 11 required items are present in the package.

**Validates: Requirements 3.4**

**Property 14: Validation Failure Recording**

*For any* validation that fails, the ValidationResult should contain a ValidationIssue with field name, issue type, description, expected value, and actual value.

**Validates: Requirements 3.5**

**Property 15: Validation Complete State**

*For any* Document Package where all validations pass, the package state should be marked as validation_complete.

**Validates: Requirements 3.6**

**Property 16: SAP Connection Failure Handling**

*For any* validation attempt when SAP connection fails, the system should log the error and mark SAP validation status as pending (not failed).

**Validates: Requirements 3.7**

**Property 17: Confidence Score Calculation**

*For any* Document Package with extracted documents, the overall confidence score should equal (PO_confidence × 0.30) + (Invoice_confidence × 0.30) + (CostSummary_confidence × 0.20) + (Activity_confidence × 0.10) + (Photos_confidence × 0.10).

**Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6**

**Property 18: Confidence Score Bounds**

*For any* calculated confidence score, the value should be between 0 and 100 (inclusive).

**Validates: Requirements 4.7**

**Property 19: Low Confidence Flagging**

*For any* Document Package with a confidence score below 70, the system should flag the package for mandatory review.

**Validates: Requirements 4.8**

**Property 20: Recommendation Generation**

*For any* Document Package that completes validation and scoring, the RecommendationAgent should generate exactly one recommendation of type APPROVE, REVIEW, or REJECT.

**Validates: Requirements 5.1**

**Property 21: Evidence Provision**

*For any* generated recommendation, the evidence field should be non-empty and contain plain-English text.

**Validates: Requirements 5.2**

**Property 22: Recommendation Logic**

*For any* Document Package, the recommendation should be APPROVE if confidence >= 85 and all validations passed, REVIEW if confidence is between 70 and 85, and REJECT if confidence < 70 or any validation failed.

**Validates: Requirements 5.3, 5.4, 5.5**

**Property 23: Evidence Citations**

*For any* generated evidence, the text should contain references to specific validation results (pass/fail status) and confidence factors (score values).

**Validates: Requirements 5.6**

**Property 24: Recommendation Persistence Round-Trip**

*For any* generated recommendation, persisting it to the database and then retrieving it should produce an equivalent recommendation.

**Validates: Requirements 5.7**

**Property 25: Data Failure Email Generation**

*For any* Document Package that fails validation, the EmailAgent should generate a data failure email containing the specific fields that need correction.

**Validates: Requirements 6.1, 6.2**

**Property 26: Data Pass Email Generation**

*For any* Document Package that passes validation, the EmailAgent should generate a data pass email addressed to the assigned ASM.

**Validates: Requirements 6.3**

**Property 27: Scenario-Based Email Templates**

*For any* email generation request, the EmailAgent should select a template that matches the scenario type (data failure, data pass, approved, rejected).

**Validates: Requirements 6.4**

**Property 28: Email Recipient Routing**

*For any* generated email, the recipient address should match the role appropriate for the scenario (Agency for failure/approval/rejection, ASM for data pass).

**Validates: Requirements 6.5**

**Property 29: Email Delivery Retry**

*For any* email delivery failure, the system should retry up to 3 times with exponentially increasing delays before marking as permanently failed.

**Validates: Requirements 6.6**

**Property 30: Email Delivery Logging**

*For any* successful email delivery, the system should create a log entry with delivery confirmation details.

**Validates: Requirements 6.7**

**Property 31: State-Level ROI Calculation**

*For any* analytics query with a date range, the AnalyticsAgent should calculate ROI metrics for each state that has submissions in that date range.

**Validates: Requirements 7.2**

**Property 32: Campaign Breakdown Analytics**

*For any* analytics query, the campaign breakdown should include submission count and approval rate for each campaign.

**Validates: Requirements 7.3**

**Property 33: Analytics Export Completeness**

*For any* analytics export request, the generated Excel file should contain all KPI data, state ROI data, and campaign breakdown data for the requested date range.

**Validates: Requirements 7.4**

**Property 34: AI Narrative Generation**

*For any* KPI dashboard data, the AnalyticsAgent should generate a non-empty AI narrative summarizing key insights.

**Validates: Requirements 7.5**

**Property 35: Real-Time KPI Data**

*For any* KPI calculation, the data should reflect the current state of the SQL database (no stale cached data older than 5 minutes).

**Validates: Requirements 7.6**

**Property 36: Submission Notification Creation**

*For any* Document Package submission, the NotificationAgent should create an in-app notification for the assigned ASM and send an email notification to the ASM's email address.

**Validates: Requirements 8.1, 8.2**

**Property 37: Flagged Package Notification**

*For any* Document Package flagged for review, the NotificationAgent should send both in-app and email notifications to the assigned ASM.

**Validates: Requirements 8.3**

**Property 38: Approval Notification**

*For any* Document Package approval by an ASM, the NotificationAgent should send both in-app and email notifications to the Agency user who submitted the package.

**Validates: Requirements 8.4**

**Property 39: Re-upload Request Notification**

*For any* re-upload request by an ASM, the notification to the Agency should include the specific requirements or fields that need correction.

**Validates: Requirements 8.5**

**Property 40: Unread Notifications First**

*For any* user's notification inbox, unread notifications should appear before read notifications in the display order.

**Validates: Requirements 8.6**

**Property 41: Notification Read State Update**

*For any* notification marked as read, the IsRead field should be set to true, the ReadAt timestamp should be set to the current time, and the user's unread count should decrease by 1.

**Validates: Requirements 8.7**

**Property 42: Chat Message Processing**

*For any* chat message from an HQ user, the ChatService should process it using Semantic Kernel and return a response.

**Validates: Requirements 9.1**

**Property 43: Vector Database Search**

*For any* chat query, the ChatService should perform a semantic search in the Vector Database and retrieve relevant analytics data.

**Validates: Requirements 9.2**

**Property 44: Unauthorized Data Access Prevention**

*For any* chat query requesting data outside the user's permissions, the ChatService should deny the request and return an explanation of why access was denied.

**Validates: Requirements 9.3, 9.4**

**Property 45: Response Citations**

*For any* chat response, the response should include citations with specific data sources and time ranges for the information provided.

**Validates: Requirements 9.5**

**Property 46: Latest Embeddings Usage**

*For any* chat query, if the Vector Database has been updated since the last query, the ChatService should use the latest embeddings in the search.

**Validates: Requirements 9.6**

**Property 47: Conversation Context Maintenance**

*For any* chat session with more than 10 messages, the ChatService should maintain context from all previous messages in the session when generating responses.

**Validates: Requirements 9.7**

**Property 48: Credential Authentication**

*For any* login attempt, the system should authenticate by verifying the provided credentials against the user database, returning success for valid credentials and failure for invalid credentials.

**Validates: Requirements 10.1**

**Property 49: Role Assignment**

*For any* successful authentication, the system should assign the user's role (Agency, ASM, or HQ) from the user database to the session.

**Validates: Requirements 10.2**

**Property 50: Role-Based Authorization**

*For any* user with a specific role, the system should grant access to exactly the features defined for that role (Agency: submission and status; ASM: approval workflows and validation; HQ: analytics and chat).

**Validates: Requirements 10.3, 10.4, 10.5**

**Property 51: Unauthorized Access Denial**

*For any* attempt to access a feature without proper authorization, the system should deny access and create an audit log entry with user ID, attempted action, and timestamp.

**Validates: Requirements 10.6**

**Property 52: Session Expiration**

*For any* user session inactive for 30 minutes, the next request should require re-authentication.

**Validates: Requirements 10.7**

**Property 53: Brand Color Usage**

*For any* UI element with color styling, the color should be one of the Bajaj brand colors (White, Light Blue, or Dark Blue).

**Validates: Requirements 11.1**

**Property 54: Responsive Layout**

*For any* screen size, the application should render a layout optimized for that screen size (mobile, tablet, or desktop breakpoints).

**Validates: Requirements 11.5**

**Property 55: Error Message Styling**

*For any* error message displayed to the user, the message should use Bajaj brand styling (colors, typography).

**Validates: Requirements 11.7**

**Property 56: Entity Persistence**

*For any* entity creation or modification, the changes should be immediately persisted to the SQL database.

**Validates: Requirements 12.1**

**Property 57: Database Operation Retry**

*For any* database operation failure, the system should retry up to 3 times before reporting an error to the caller.

**Validates: Requirements 12.2**

**Property 58: Referential Integrity**

*For any* Document Package with related entities (documents, validation results, confidence scores, recommendations), all foreign key relationships should be valid and no orphaned records should exist.

**Validates: Requirements 12.3**

**Property 59: Soft Delete Preservation**

*For any* document deletion, the document record should remain in the database with a deleted flag set to true and a deletion timestamp, preserving audit history.

**Validates: Requirements 12.4**

**Property 60: Transaction Atomicity**

*For any* database transaction involving multiple operations, either all operations should succeed and be committed, or all should be rolled back on any failure.

**Validates: Requirements 12.5**

**Property 61: Audit Field Inclusion**

*For any* stored extracted document data, the record should include a timestamp and user ID indicating when and by whom the data was created.

**Validates: Requirements 12.6**

**Property 62: API Request Validation**

*For any* API request, the system should validate the request payload against the defined schema and reject invalid requests with a 400 Bad Request status code.

**Validates: Requirements 13.2**

**Property 63: API Error Status Codes**

*For any* API operation failure, the response should include an appropriate HTTP status code (400 for bad request, 401 for unauthorized, 403 for forbidden, 404 for not found, 500 for server error) and an error message.

**Validates: Requirements 13.3**

**Property 64: API Authentication Requirement**

*For any* API endpoint call (except login), the request should include a valid authentication token, and requests without valid tokens should be rejected with 401 Unauthorized.

**Validates: Requirements 13.4**

**Property 65: API Request Logging**

*For any* API request, the system should log the request method, path, payload, response status, and response body.

**Validates: Requirements 13.5**

**Property 66: Correlation ID Inclusion**

*For any* API response, the response headers should include a correlation ID that can be used to trace the request through the system.

**Validates: Requirements 13.6**

**Property 67: Multipart File Upload Support**

*For any* file upload API request, the system should accept multipart form data with files up to 50MB per file.

**Validates: Requirements 13.7**

**Property 68: Concurrent Request Queuing**

*For any* set of concurrent agent processing requests, the system should queue requests to prevent more than N concurrent operations (where N is the configured concurrency limit).

**Validates: Requirements 14.7**

**Property 69: Error Logging Completeness**

*For any* service error, the log entry should include error message, full context (request details, user ID, entity IDs), and stack trace.

**Validates: Requirements 15.1**

**Property 70: External Service Retry**

*For any* external service call failure (SAP, ACS, Azure AI), the system should retry with exponential backoff (1s, 2s, 4s) up to 3 times before reporting permanent failure.

**Validates: Requirements 15.2**

**Property 71: SAP Unavailability Queuing**

*For any* validation request when SAP is unavailable, the system should add the request to a queue for later processing when SAP becomes available.

**Validates: Requirements 15.3**

**Property 72: Email Failure Storage**

*For any* ACS email delivery failure, the system should store the email content for retry and send an alert notification to system administrators.

**Validates: Requirements 15.4**

**Property 73: Document Processing Failure Handling**

*For any* document processing failure in DocumentAgent, the system should notify the user of the failure and preserve the uploaded file in blob storage.

**Validates: Requirements 15.5**

**Property 74: Database Reconnection**

*For any* lost database connection, the system should attempt to reconnect before failing the current request.

**Validates: Requirements 15.6**

**Property 75: Critical Error Alerting**

*For any* critical error (database unavailable, all external services down, unhandled exception), the system should send an alert to system administrators via configured channels.

**Validates: Requirements 15.7**

**Property 76: Data Encryption at Rest**

*For any* sensitive data stored in the database, the data should be encrypted using AES-256 encryption before persistence.

**Validates: Requirements 16.1**

**Property 77: Password Hashing**

*For any* user password storage, the password should be hashed using bcrypt with at least 12 rounds before storing in the database.

**Validates: Requirements 16.3**

**Property 78: Malware Scanning**

*For any* document file upload, the system should scan the file for malware before persisting it to blob storage.

**Validates: Requirements 16.4**

**Property 79: Audit Event Logging**

*For any* audit event (login, document submission, approval, rejection), the system should create an audit log entry with user ID, action, timestamp, and IP address.

**Validates: Requirements 16.5**

**Property 80: Personal Data Access Logging**

*For any* access to personal data (user details, document contents), the system should create a log entry for compliance auditing.

**Validates: Requirements 16.6**

**Property 81: Secure Secret Storage**

*For any* API key or secret, the system should store it using a secure key management service (Azure Key Vault) rather than in plain text configuration.

**Validates: Requirements 16.7**

## Error Handling


### Error Categories

1. **Validation Errors**: User input doesn't meet requirements (400 Bad Request)
2. **Authentication Errors**: Invalid or missing credentials (401 Unauthorized)
3. **Authorization Errors**: User lacks permission (403 Forbidden)
4. **Not Found Errors**: Requested resource doesn't exist (404 Not Found)
5. **External Service Errors**: SAP, ACS, Azure AI unavailable (503 Service Unavailable)
6. **Database Errors**: Connection lost, query timeout (500 Internal Server Error)
7. **Processing Errors**: Document extraction fails, validation fails (500 Internal Server Error)

### Error Handling Strategy

**Transient Errors** (network timeouts, temporary service unavailability):
- Retry with exponential backoff (1s, 2s, 4s)
- Maximum 3 retry attempts
- Log each retry attempt
- Return 503 Service Unavailable if all retries fail

**Permanent Errors** (invalid input, authorization failure):
- No retry
- Return appropriate HTTP status code immediately
- Include detailed error message for client
- Log error with full context

**Critical Errors** (database unavailable, unhandled exceptions):
- Log error with stack trace
- Send alert to administrators
- Return 500 Internal Server Error with generic message (don't expose internals)
- Preserve system state (no partial updates)

### Circuit Breaker Pattern

For external services (SAP, ACS, Azure AI):

- **Closed State**: Normal operation, requests pass through
- **Open State**: Service unavailable, fail fast without calling service
- **Half-Open State**: Test if service recovered, allow limited requests

**Thresholds**:
- Open circuit after 5 consecutive failures
- Keep circuit open for 60 seconds
- Allow 1 test request in half-open state
- Close circuit after 2 successful test requests

### Compensation Actions

When a workflow step fails after previous steps succeeded:

1. **Document Extraction Failure**: Mark package as ERROR, notify user, preserve uploaded files
2. **Validation Failure**: Store partial validation results, notify user of specific issues
3. **Email Delivery Failure**: Queue email for retry, continue workflow
4. **Database Transaction Failure**: Rollback all changes, return error to client

## Testing Strategy

### Dual Testing Approach

The system requires both unit testing and property-based testing for comprehensive coverage:

- **Unit Tests**: Verify specific examples, edge cases, and error conditions
- **Property Tests**: Verify universal properties across all inputs

Both approaches are complementary and necessary. Unit tests catch concrete bugs in specific scenarios, while property tests verify general correctness across a wide range of inputs.

### Unit Testing

**Focus Areas**:
- Specific examples demonstrating correct behavior
- Integration points between components (API → Service → Database)
- Edge cases (empty lists, null values, boundary conditions)
- Error conditions (network failures, invalid input, authorization failures)

**Example Unit Tests**:
- Test that a valid PO document with known fields extracts correctly
- Test that amount validation fails when invoice total is 10% higher than cost summary
- Test that unauthorized API requests return 401 status code
- Test that email retry logic stops after 3 failures

**Testing Framework**: xUnit for .NET, Flutter Test for Flutter

### Property-Based Testing

**Focus Areas**:
- Universal properties that hold for all inputs
- Comprehensive input coverage through randomization
- Invariants that must be maintained across operations

**Configuration**:
- Minimum 100 iterations per property test (due to randomization)
- Each property test must reference its design document property
- Tag format: `// Feature: bajaj-document-processing-system, Property {number}: {property_text}`

**Property Testing Library**: FsCheck for .NET

**Example Property Tests**:

```csharp
// Feature: bajaj-document-processing-system, Property 17: Confidence Score Calculation
[Property]
public Property ConfidenceScoreCalculation()
{
    return Prop.ForAll(
        Arb.From<double>().Where(x => x >= 0 && x <= 100),
        Arb.From<double>().Where(x => x >= 0 && x <= 100),
        Arb.From<double>().Where(x => x >= 0 && x <= 100),
        Arb.From<double>().Where(x => x >= 0 && x <= 100),
        Arb.From<double>().Where(x => x >= 0 && x <= 100),
        (po, invoice, cost, activity, photos) =>
        {
            var expected = (po * 0.30) + (invoice * 0.30) + (cost * 0.20) + 
                          (activity * 0.10) + (photos * 0.10);
            var actual = _confidenceScoreService.Calculate(po, invoice, cost, activity, photos);
            return Math.Abs(expected - actual) < 0.01;
        });
}

// Feature: bajaj-document-processing-system, Property 22: Recommendation Logic
[Property]
public Property RecommendationLogic()
{
    return Prop.ForAll(
        Arb.From<double>().Where(x => x >= 0 && x <= 100),
        Arb.From<bool>(),
        (confidence, allValidationsPassed) =>
        {
            var recommendation = _recommendationAgent.Generate(confidence, allValidationsPassed);
            
            if (confidence >= 85 && allValidationsPassed)
                return recommendation.Type == RecommendationType.APPROVE;
            else if (confidence >= 70 && confidence < 85)
                return recommendation.Type == RecommendationType.REVIEW;
            else
                return recommendation.Type == RecommendationType.REJECT;
        });
}
```

### Integration Testing

**Focus Areas**:
- End-to-end workflows (submission → extraction → validation → recommendation → notification)
- Database transactions and rollbacks
- External service integration (SAP, ACS, Azure AI)
- API endpoint behavior

**Test Environment**:
- Use test database with known seed data
- Mock external services (SAP, ACS, Azure AI) for predictable behavior
- Use test Azure storage account for file uploads

### Performance Testing

**Focus Areas**:
- Concurrent user load (100 users)
- Document processing time (< 30 seconds per document)
- API response times (< 2 seconds)
- Database query performance (< 1 second with 1M records)

**Tools**: Apache JMeter or k6 for load testing

### Security Testing

**Focus Areas**:
- Authentication and authorization
- SQL injection prevention
- XSS prevention
- CSRF protection
- Malware scanning
- Encryption at rest and in transit

**Tools**: OWASP ZAP for vulnerability scanning



## Flutter Best Practices and Implementation Guidelines

### Architecture Patterns

The Flutter frontend follows Clean Architecture principles with a feature-based folder structure to ensure maintainability, testability, and scalability.

#### Recommended Architecture: Clean Architecture with Riverpod

**Layer Structure**:

```
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   ├── errors/
│   └── network/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       └── widgets/
│   ├── submission/
│   ├── approval/
│   ├── analytics/
│   └── chat/
└── main.dart
```

**Layer Responsibilities**:

1. **Domain Layer**: Business logic and entities (pure Dart, no Flutter dependencies)
   - Entities: Core business objects (User, DocumentPackage, ValidationResult)
   - Repositories: Abstract interfaces for data operations
   - Use Cases: Single-responsibility business operations (SubmitDocuments, ApprovePackage)

2. **Data Layer**: Data sources and repository implementations
   - Models: JSON serialization/deserialization
   - Data Sources: API clients, local storage
   - Repositories: Concrete implementations of domain repositories

3. **Presentation Layer**: UI and state management
   - Providers: Riverpod state management
   - Screens: Full-page widgets
   - Widgets: Reusable UI components


### State Management with Riverpod

**Why Riverpod**: Type-safe, compile-time safe, testable, no BuildContext required, excellent for dependency injection.

**Provider Types**:

1. **Provider**: For immutable values (configuration, constants)
2. **StateProvider**: For simple state (counters, toggles)
3. **StateNotifierProvider**: For complex state with business logic
4. **FutureProvider**: For async operations
5. **StreamProvider**: For real-time data streams

**Example Implementation**:

```dart
// Domain Entity
class DocumentPackage {
  final String id;
  final PackageState state;
  final List<Document> documents;
  
  DocumentPackage({required this.id, required this.state, required this.documents});
}

// State Notifier
class SubmissionNotifier extends StateNotifier<AsyncValue<DocumentPackage?>> {
  final SubmitDocumentsUseCase _submitUseCase;
  
  SubmissionNotifier(this._submitUseCase) : super(const AsyncValue.data(null));
  
  Future<void> submitDocuments(List<File> files) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _submitUseCase.execute(files));
  }
}

// Provider
final submissionProvider = StateNotifierProvider<SubmissionNotifier, AsyncValue<DocumentPackage?>>((ref) {
  final submitUseCase = ref.watch(submitDocumentsUseCaseProvider);
  return SubmissionNotifier(submitUseCase);
});
```


### Widget Composition and Reusability

**Principles**:
- Single Responsibility: Each widget does one thing well
- Composition over Inheritance: Build complex UIs from simple widgets
- Const Constructors: Use `const` wherever possible for performance
- Extract Reusable Widgets: Don't repeat widget trees

**Example Structure**:

```dart
// Reusable Button Widget
class BajajPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  
  const BajajPrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: BajajColors.darkBlue,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}

// Document Upload Card Widget
class DocumentUploadCard extends StatelessWidget {
  final String documentType;
  final String? fileName;
  final VoidCallback onUpload;
  
  const DocumentUploadCard({
    Key? key,
    required this.documentType,
    this.fileName,
    required this.onUpload,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          fileName != null ? Icons.check_circle : Icons.upload_file,
          color: fileName != null ? Colors.green : BajajColors.lightBlue,
        ),
        title: Text(documentType),
        subtitle: fileName != null ? Text(fileName!) : const Text('Tap to upload'),
        trailing: IconButton(
          icon: const Icon(Icons.add),
          onPressed: onUpload,
        ),
      ),
    );
  }
}
```


### Performance Optimization

**1. Const Constructors**:
- Use `const` for all immutable widgets
- Reduces widget rebuilds and improves performance
- Flutter can reuse const widgets across rebuilds

```dart
// Good
const Text('Submit', style: TextStyle(fontSize: 16))

// Bad
Text('Submit', style: TextStyle(fontSize: 16))
```

**2. Widget Keys**:
- Use keys when widget order changes (lists, animations)
- ValueKey for unique values, ObjectKey for objects, UniqueKey for truly unique widgets

```dart
ListView.builder(
  itemCount: documents.length,
  itemBuilder: (context, index) {
    final doc = documents[index];
    return DocumentCard(
      key: ValueKey(doc.id),  // Preserves state when list reorders
      document: doc,
    );
  },
)
```

**3. Lazy Loading**:
- Use ListView.builder for long lists (not ListView with children)
- Implement pagination for large datasets
- Load images lazily with CachedNetworkImage

```dart
// Good: Lazy loading
ListView.builder(
  itemCount: submissions.length,
  itemBuilder: (context, index) => SubmissionCard(submission: submissions[index]),
)

// Bad: Loads all widgets at once
ListView(
  children: submissions.map((s) => SubmissionCard(submission: s)).toList(),
)
```

**4. Image Optimization**:
- Use cached_network_image package for remote images
- Specify image dimensions to avoid layout shifts
- Use appropriate image formats (WebP for web)

```dart
CachedNetworkImage(
  imageUrl: document.thumbnailUrl,
  width: 100,
  height: 100,
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
)
```

**5. Build Method Optimization**:
- Keep build methods pure (no side effects)
- Extract complex widgets to separate classes
- Use const constructors for static widgets
- Avoid creating objects in build methods


### Responsive Design Patterns

**Breakpoints**:
```dart
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}
```

**Responsive Layout Builder**:

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;
  
  const ResponsiveLayout({
    Key? key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.desktop) {
          return desktop;
        } else if (constraints.maxWidth >= Breakpoints.tablet) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

// Usage
ResponsiveLayout(
  mobile: SubmissionListMobile(),
  tablet: SubmissionListTablet(),
  desktop: SubmissionListDesktop(),
)
```

**Responsive Padding and Spacing**:

```dart
class ResponsiveSpacing {
  static double getPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.desktop) return 32.0;
    if (width >= Breakpoints.tablet) return 24.0;
    return 16.0;
  }
}
```


### Navigation Patterns

**GoRouter for Declarative Routing**:

```dart
final goRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final isAuthenticated = ref.read(authProvider).value?.isAuthenticated ?? false;
    final isLoginRoute = state.location == '/login';
    
    if (!isAuthenticated && !isLoginRoute) return '/login';
    if (isAuthenticated && isLoginRoute) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'submission/:id',
          builder: (context, state) {
            final id = state.params['id']!;
            return SubmissionDetailScreen(submissionId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
  ],
);

// Navigation
context.go('/home/submission/123');
context.push('/analytics');
```

**Deep Linking Support**:
- Configure deep links in AndroidManifest.xml and Info.plist
- Handle incoming links with GoRouter
- Support web URLs for web platform


### Error Handling and Validation

**Form Validation**:

```dart
class SubmissionFormValidator {
  static String? validatePO(File? file) {
    if (file == null) return 'PO document is required';
    if (!file.path.endsWith('.pdf')) return 'PO must be a PDF file';
    if (file.lengthSync() > 10 * 1024 * 1024) return 'PO file size must be less than 10MB';
    return null;
  }
  
  static String? validateInvoice(File? file) {
    if (file == null) return 'Invoice is required';
    if (!file.path.endsWith('.pdf')) return 'Invoice must be a PDF file';
    if (file.lengthSync() > 10 * 1024 * 1024) return 'Invoice file size must be less than 10MB';
    return null;
  }
}

// Usage in Form
TextFormField(
  validator: (value) => SubmissionFormValidator.validateEmail(value),
  decoration: const InputDecoration(labelText: 'Email'),
)
```

**Error State Handling with Riverpod**:

```dart
class SubmissionScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionState = ref.watch(submissionProvider);
    
    return submissionState.when(
      data: (package) => SubmissionSuccessView(package: package),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.refresh(submissionProvider),
      ),
    );
  }
}
```

**Global Error Handling**:

```dart
class ErrorHandler {
  static void handleError(Object error, StackTrace stack) {
    if (error is NetworkException) {
      // Show network error dialog
      showErrorDialog('Network error. Please check your connection.');
    } else if (error is AuthException) {
      // Redirect to login
      navigateToLogin();
    } else {
      // Log to crash reporting service
      FirebaseCrashlytics.instance.recordError(error, stack);
      showErrorDialog('An unexpected error occurred.');
    }
  }
}
```


### Testing Strategies

**1. Widget Tests**:

```dart
void main() {
  testWidgets('Login button is disabled when fields are empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );
    
    final loginButton = find.byType(ElevatedButton);
    expect(tester.widget<ElevatedButton>(loginButton).enabled, false);
  });
  
  testWidgets('Submission form shows all required document upload cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SubmissionScreen()),
    );
    
    expect(find.text('Purchase Order'), findsOneWidget);
    expect(find.text('Invoice'), findsOneWidget);
    expect(find.text('Cost Summary'), findsOneWidget);
  });
}
```

**2. Integration Tests**:

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('Complete submission flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Login
    await tester.enterText(find.byKey(const Key('emailField')), 'test@example.com');
    await tester.enterText(find.byKey(const Key('passwordField')), 'password123');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    
    // Navigate to submission
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    
    // Upload documents (mocked)
    await tester.tap(find.text('Upload PO'));
    await tester.pumpAndSettle();
    
    // Submit
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    
    // Verify success
    expect(find.text('Submission successful'), findsOneWidget);
  });
}
```

**3. Unit Tests for Business Logic**:

```dart
void main() {
  group('SubmitDocumentsUseCase', () {
    late SubmitDocumentsUseCase useCase;
    late MockDocumentRepository mockRepo;
    
    setUp(() {
      mockRepo = MockDocumentRepository();
      useCase = SubmitDocumentsUseCase(mockRepo);
    });
    
    test('should submit documents successfully', () async {
      when(mockRepo.submitDocuments(any))
          .thenAnswer((_) async => Right(DocumentPackage(id: '123')));
      
      final result = await useCase.execute([mockFile1, mockFile2]);
      
      expect(result.isRight(), true);
      verify(mockRepo.submitDocuments(any)).called(1);
    });
  });
}
```


### Code Organization and Folder Structure

**Feature-Based Structure**:

```
lib/
├── core/
│   ├── constants/
│   │   ├── api_constants.dart
│   │   ├── app_constants.dart
│   │   └── storage_keys.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── bajaj_colors.dart
│   │   └── text_styles.dart
│   ├── utils/
│   │   ├── date_formatter.dart
│   │   ├── file_validator.dart
│   │   └── responsive_helper.dart
│   ├── errors/
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   ├── network/
│   │   ├── dio_client.dart
│   │   ├── api_interceptor.dart
│   │   └── network_info.dart
│   └── widgets/
│       ├── bajaj_button.dart
│       ├── bajaj_text_field.dart
│       └── loading_indicator.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── user_model.dart
│   │   │   │   └── login_response_model.dart
│   │   │   ├── datasources/
│   │   │   │   ├── auth_remote_datasource.dart
│   │   │   │   └── auth_local_datasource.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── login_usecase.dart
│   │   │       └── logout_usecase.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart
│   │       ├── screens/
│   │       │   └── login_screen.dart
│   │       └── widgets/
│   │           └── login_form.dart
│   ├── submission/
│   ├── approval/
│   ├── analytics/
│   └── chat/
└── main.dart
```

**Naming Conventions**:
- Files: snake_case (user_model.dart)
- Classes: PascalCase (UserModel)
- Variables/Functions: camelCase (getUserData)
- Constants: SCREAMING_SNAKE_CASE (API_BASE_URL)
- Private members: prefix with underscore (_privateMethod)


### Dependency Injection with Riverpod

**Provider Hierarchy**:

```dart
// Core Providers
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(LoggingInterceptor());
  return dio;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Data Source Providers
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(dioProvider));
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(secureStorageProvider));
});

// Repository Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

// Use Case Providers
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

// State Providers
final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(
    loginUseCase: ref.watch(loginUseCaseProvider),
    logoutUseCase: ref.watch(logoutUseCaseProvider),
  );
});
```

**Benefits**:
- Compile-time safety
- Easy testing (override providers in tests)
- No BuildContext required
- Automatic disposal
- Lazy initialization


### API Integration Patterns

**Dio HTTP Client Configuration**:

```dart
class DioClient {
  late final Dio _dio;
  
  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    _dio.interceptors.addAll([
      AuthInterceptor(),
      LoggingInterceptor(),
      ErrorInterceptor(),
    ]);
  }
  
  Dio get dio => _dio;
}

// Auth Interceptor
class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  
  AuthInterceptor(this._storage);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: StorageKeys.authToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired, refresh or logout
      await _handleTokenExpiration();
    }
    handler.next(err);
  }
}

// Error Interceptor
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = _handleError(err);
    handler.reject(DioException(
      requestOptions: err.requestOptions,
      error: error,
    ));
  }
  
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('Connection timeout');
      case DioExceptionType.badResponse:
        return ServerException(error.response?.data['message'] ?? 'Server error');
      default:
        return NetworkException('Network error');
    }
  }
}
```

**Repository Pattern**:

```dart
abstract class DocumentRepository {
  Future<Either<Failure, DocumentPackage>> submitDocuments(List<File> files);
  Future<Either<Failure, DocumentPackage>> getSubmission(String id);
  Future<Either<Failure, List<DocumentPackage>>> getSubmissions();
}

class DocumentRepositoryImpl implements DocumentRepository {
  final DocumentRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;
  
  DocumentRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });
  
  @override
  Future<Either<Failure, DocumentPackage>> submitDocuments(List<File> files) async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure('No internet connection'));
    }
    
    try {
      final result = await remoteDataSource.submitDocuments(files);
      return Right(result.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    }
  }
}
```


### Secure Storage for Tokens

**FlutterSecureStorage for Sensitive Data**:

```dart
class SecureStorageService {
  final FlutterSecureStorage _storage;
  
  SecureStorageService(this._storage);
  
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: StorageKeys.authToken, value: token);
  }
  
  Future<String?> getAuthToken() async {
    return await _storage.read(key: StorageKeys.authToken);
  }
  
  Future<void> deleteAuthToken() async {
    await _storage.delete(key: StorageKeys.authToken);
  }
  
  Future<void> saveUserData(User user) async {
    await _storage.write(key: StorageKeys.userId, value: user.id);
    await _storage.write(key: StorageKeys.userEmail, value: user.email);
    await _storage.write(key: StorageKeys.userRole, value: user.role.toString());
  }
  
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

// Storage Keys
class StorageKeys {
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userRole = 'user_role';
}
```

**Hive for Local Caching**:

```dart
// For non-sensitive data caching
class CacheService {
  late Box<dynamic> _box;
  
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox('app_cache');
  }
  
  Future<void> cacheSubmissions(List<DocumentPackage> submissions) async {
    await _box.put('submissions', submissions.map((s) => s.toJson()).toList());
  }
  
  List<DocumentPackage>? getCachedSubmissions() {
    final data = _box.get('submissions');
    if (data == null) return null;
    return (data as List).map((json) => DocumentPackage.fromJson(json)).toList();
  }
  
  Future<void> clearCache() async {
    await _box.clear();
  }
}
```


### Asset Management

**Asset Organization**:

```
assets/
├── images/
│   ├── logo/
│   │   ├── bajaj_logo.png
│   │   ├── bajaj_logo@2x.png
│   │   └── bajaj_logo@3x.png
│   ├── icons/
│   │   ├── document_icon.png
│   │   └── upload_icon.png
│   └── illustrations/
│       ├── empty_state.svg
│       └── error_state.svg
├── fonts/
│   ├── Roboto-Regular.ttf
│   ├── Roboto-Medium.ttf
│   └── Roboto-Bold.ttf
└── animations/
    └── loading.json
```

**pubspec.yaml Configuration**:

```yaml
flutter:
  assets:
    - assets/images/logo/
    - assets/images/icons/
    - assets/images/illustrations/
    - assets/animations/
  
  fonts:
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
        - asset: assets/fonts/Roboto-Medium.ttf
          weight: 500
        - asset: assets/fonts/Roboto-Bold.ttf
          weight: 700
```

**Asset Constants**:

```dart
class Assets {
  static const String logo = 'assets/images/logo/bajaj_logo.png';
  static const String documentIcon = 'assets/images/icons/document_icon.png';
  static const String emptyState = 'assets/images/illustrations/empty_state.svg';
  static const String loadingAnimation = 'assets/animations/loading.json';
}

// Usage
Image.asset(Assets.logo, width: 120, height: 40)
```


### Localization Readiness

**Setup for Future Localization**:

```dart
// l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart

// lib/l10n/app_en.arb
{
  "@@locale": "en",
  "appTitle": "Bajaj Document Processing",
  "login": "Login",
  "email": "Email",
  "password": "Password",
  "submit": "Submit",
  "uploadDocument": "Upload Document",
  "purchaseOrder": "Purchase Order",
  "invoice": "Invoice",
  "costSummary": "Cost Summary"
}

// Usage in code
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Text(AppLocalizations.of(context)!.login)

// MaterialApp configuration
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  // ...
)
```

**String Externalization**:
- All user-facing strings should use localization
- No hardcoded strings in UI code
- Use descriptive keys in ARB files
- Prepare for Hindi localization (future requirement)


### Accessibility Guidelines

**Semantic Labels**:

```dart
// Add semantic labels for screen readers
Semantics(
  label: 'Upload purchase order document',
  button: true,
  child: IconButton(
    icon: const Icon(Icons.upload),
    onPressed: _uploadPO,
  ),
)

// Exclude decorative images from semantics
Semantics(
  excludeSemantics: true,
  child: Image.asset(Assets.decorativePattern),
)
```

**Color Contrast**:
- Ensure minimum 4.5:1 contrast ratio for normal text
- Ensure minimum 3:1 contrast ratio for large text
- Test with color blindness simulators
- Don't rely solely on color to convey information

```dart
// Good: Uses both color and icon
Row(
  children: [
    Icon(Icons.check_circle, color: Colors.green),
    Text('Approved', style: TextStyle(color: Colors.green)),
  ],
)

// Bad: Color only
Text('Approved', style: TextStyle(color: Colors.green))
```

**Touch Targets**:
- Minimum 48x48 logical pixels for touch targets
- Add padding if visual size is smaller

```dart
// Ensure minimum touch target size
InkWell(
  onTap: _onTap,
  child: Container(
    padding: const EdgeInsets.all(12), // Ensures 48x48 minimum
    child: Icon(Icons.info, size: 24),
  ),
)
```

**Focus Management**:
- Support keyboard navigation
- Provide visible focus indicators
- Logical tab order

```dart
Focus(
  onFocusChange: (hasFocus) {
    setState(() => _isFocused = hasFocus);
  },
  child: TextField(
    decoration: InputDecoration(
      border: OutlineInputBorder(
        borderSide: BorderSide(
          color: _isFocused ? BajajColors.darkBlue : Colors.grey,
          width: _isFocused ? 2 : 1,
        ),
      ),
    ),
  ),
)
```

**Screen Reader Support**:
- Test with TalkBack (Android) and VoiceOver (iOS)
- Provide meaningful labels for all interactive elements
- Announce dynamic content changes

```dart
// Announce loading state changes
if (_isLoading) {
  Semantics(
    liveRegion: true,
    child: const Text('Loading submissions...'),
  );
}
```


### Flutter Best Practices Summary

**Key Principles**:

1. **Architecture**: Use Clean Architecture with feature-based structure
2. **State Management**: Riverpod for type-safe, testable state management
3. **Performance**: Const constructors, keys, lazy loading, image optimization
4. **Responsive Design**: LayoutBuilder, MediaQuery, breakpoint-based layouts
5. **Navigation**: GoRouter for declarative, type-safe routing
6. **Error Handling**: Comprehensive validation, error states, global error handling
7. **Testing**: Widget tests, integration tests, unit tests for business logic
8. **Code Organization**: Feature-based folders, clear separation of concerns
9. **Dependency Injection**: Riverpod providers for all dependencies
10. **API Integration**: Dio with interceptors, repository pattern, Either for error handling
11. **Security**: FlutterSecureStorage for tokens, Hive for non-sensitive caching
12. **Assets**: Organized structure, multiple resolutions, SVG support
13. **Localization**: ARB files, externalized strings, ready for multi-language
14. **Accessibility**: Semantic labels, color contrast, touch targets, screen reader support

**Required Packages**:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  
  # Navigation
  go_router: ^12.0.0
  
  # HTTP Client
  dio: ^5.4.0
  
  # Storage
  flutter_secure_storage: ^9.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # Functional Programming
  dartz: ^0.10.1
  
  # Image Handling
  cached_network_image: ^3.3.0
  image_picker: ^1.0.4
  
  # File Handling
  file_picker: ^6.1.1
  path_provider: ^2.1.1
  
  # UI
  flutter_svg: ^2.0.9
  lottie: ^2.7.0
  
  # Utilities
  intl: ^0.18.1
  equatable: ^2.0.5
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  
  # Code Generation
  build_runner: ^2.4.6
  riverpod_generator: ^2.3.0
  
  # Testing
  mockito: ^5.4.3
  integration_test:
    sdk: flutter
  
  # Linting
  flutter_lints: ^3.0.0
```

This comprehensive Flutter implementation will ensure a maintainable, performant, and accessible mobile application that follows industry best practices.


## UI Design: PO Field Display and Auto-Population

### Overview

The Agency submission form will display four dedicated input fields for PO data that automatically populate after the PO document is uploaded and processed by the DocumentAgent. This provides immediate visual feedback to users and allows them to verify or correct extracted data before submission.

### Component Design

**Component Name**: POFieldsSection

**Location**: Agency submission form (agency_dashboard_page.dart), displayed after PO document upload card

**Layout**: 2x2 grid on desktop/tablet, vertical stack on mobile

### Field Specifications

1. **PO Number Field**
   - Type: Text input
   - Placeholder: "Enter PO number"
   - Position: Top-left (grid) / First (mobile)
   - Validation: Required, alphanumeric
   - Auto-population source: `POData.PONumber` from extracted JSON

2. **PO Amount Field**
   - Type: Currency input
   - Placeholder: "Enter amount"
   - Position: Top-right (grid) / Second (mobile)
   - Format: ₹ symbol prefix, comma-separated thousands, 2 decimal places (e.g., "₹ 10,500.00")
   - Validation: Required, positive number
   - Auto-population source: `POData.TotalAmount` from extracted JSON

3. **PO Date Field**
   - Type: Date picker input
   - Placeholder: "dd-mm-yyyy"
   - Position: Bottom-left (grid) / Third (mobile)
   - Format: dd-mm-yyyy (e.g., "15-03-2024")
   - Validation: Required, valid date, not in future
   - Auto-population source: `POData.Date` from extracted JSON

4. **Vendor Name Field**
   - Type: Text input
   - Placeholder: "Enter vendor name"
   - Position: Bottom-right (grid) / Fourth (mobile)
   - Validation: Required, max 100 characters
   - Auto-population source: `POData.VendorName` from extracted JSON

### Visual Design

**Grid Layout (Desktop/Tablet ≥600px)**:
```
┌─────────────────────────────┬─────────────────────────────┐
│  PO Number                  │  PO Amount (₹)              │
│  [Enter PO number]          │  [Enter amount]             │
└─────────────────────────────┴─────────────────────────────┘
┌─────────────────────────────┬─────────────────────────────┐
│  PO Date                    │  Vendor Name                │
│  [dd-mm-yyyy]               │  [Enter vendor name]        │
└─────────────────────────────┴─────────────────────────────┘
```

**Stack Layout (Mobile <600px)**:
```
┌───────────────────────────────────────────────────────────┐
│  PO Number                                                │
│  [Enter PO number]                                        │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  PO Amount (₹)                                            │
│  [Enter amount]                                           │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  PO Date                                                  │
│  [dd-mm-yyyy]                                             │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  Vendor Name                                              │
│  [Enter vendor name]                                      │
└───────────────────────────────────────────────────────────┘
```

### Styling

- **Field Container**: Card with elevation 1, 8px border radius, 16px padding
- **Label**: Dark Blue (#003087), 14px font size, medium weight
- **Input**: 16px font size, regular weight, Light Blue (#00A3E0) focus border
- **Placeholder**: Gray (#9E9E9E), 16px font size, regular weight
- **Spacing**: 16px between fields (grid), 12px between fields (mobile)
- **Section Margin**: 24px top margin from PO upload card

### Behavior

**Initial State (No PO Uploaded)**:
- All four fields displayed with empty values
- Placeholders visible
- Fields are editable
- No visual indication of auto-population

**After PO Upload and Extraction**:
1. DocumentAgent processes PO document
2. Extracted POData is stored in Document.ExtractedDataJson
3. Frontend receives extraction complete event (via polling or state update)
4. POFieldsSection reads POData from submission state
5. Fields auto-populate with formatted values:
   - PO Number: Direct string value
   - PO Amount: Formatted as "₹ 10,500.00"
   - PO Date: Formatted as "15-03-2024"
   - Vendor Name: Direct string value
6. Fields remain editable for manual corrections

**Manual Edit Behavior**:
- User can click/tap any field to edit
- Edited values are preserved in local state
- If PO document is re-uploaded, edited fields are NOT overwritten
- Track "manually edited" flag per field to prevent overwriting

**Incomplete Extraction**:
- If POData field is null/empty, leave corresponding input field empty
- Show placeholder text
- User can manually enter value

### Data Flow

```
1. User uploads PO document
   ↓
2. DocumentAgent.ExtractPOAsync() processes document
   ↓
3. POData stored in Document.ExtractedDataJson
   ↓
4. Frontend polls/watches submission state
   ↓
5. SubmissionNotifier updates with extracted POData
   ↓
6. POFieldsSection widget rebuilds with new data
   ↓
7. TextEditingController values updated (if not manually edited)
   ↓
8. User sees auto-populated fields
   ↓
9. User can edit any field
   ↓
10. On submit, current field values (auto or manual) sent to API
```

### Implementation Notes

**State Management**:
- Use Riverpod StateNotifier to manage PO field values
- Track "manually edited" flags for each field
- Separate state for extracted data vs. current field values

**Widget Structure**:
```dart
class POFieldsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poData = ref.watch(submissionProvider).poData;
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isDesktop
            ? _buildGridLayout(poData)
            : _buildStackLayout(poData),
      ),
    );
  }
  
  Widget _buildGridLayout(POData? poData) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: PONumberField(initialValue: poData?.poNumber)),
            const SizedBox(width: 16),
            Expanded(child: POAmountField(initialValue: poData?.totalAmount)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: PODateField(initialValue: poData?.date)),
            const SizedBox(width: 16),
            Expanded(child: VendorNameField(initialValue: poData?.vendorName)),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStackLayout(POData? poData) {
    return Column(
      children: [
        PONumberField(initialValue: poData?.poNumber),
        const SizedBox(height: 12),
        POAmountField(initialValue: poData?.totalAmount),
        const SizedBox(height: 12),
        PODateField(initialValue: poData?.date),
        const SizedBox(height: 12),
        VendorNameField(initialValue: poData?.vendorName),
      ],
    );
  }
}
```

**Field Widgets**:
- Each field is a separate widget (PONumberField, POAmountField, etc.)
- Use TextEditingController to manage field values
- Implement formatters for currency and date fields
- Add validation logic per field

**Currency Formatting**:
```dart
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Format as ₹ 10,500.00
    final number = double.tryParse(newValue.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (number == null) return oldValue;
    
    final formatted = NumberFormat.currency(
      symbol: '₹ ',
      decimalDigits: 2,
      locale: 'en_IN',
    ).format(number);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
```

**Date Formatting**:
```dart
String formatDateToDDMMYYYY(DateTime date) {
  return DateFormat('dd-MM-yyyy').format(date);
}

DateTime? parseDDMMYYYY(String dateStr) {
  try {
    return DateFormat('dd-MM-yyyy').parse(dateStr);
  } catch (e) {
    return null;
  }
}
```

### Accessibility

- Add semantic labels to all fields: "PO Number input", "PO Amount input", etc.
- Ensure 48x48 minimum touch targets
- Provide clear error messages for validation failures
- Support keyboard navigation (tab order: PO Number → PO Amount → PO Date → Vendor Name)
- Announce auto-population to screen readers: "PO fields auto-populated from document"

### Testing

**Widget Tests**:
1. Test initial empty state renders correctly
2. Test grid layout on desktop breakpoint
3. Test stack layout on mobile breakpoint
4. Test auto-population when POData is provided
5. Test manual edit preserves user input
6. Test currency formatting for PO Amount
7. Test date formatting for PO Date
8. Test validation errors display correctly

**Integration Tests**:
1. Upload PO document → verify fields auto-populate
2. Edit auto-populated field → re-upload PO → verify edit is preserved
3. Submit form with auto-populated values → verify values sent to API
4. Submit form with manually edited values → verify edited values sent to API

### Validation Rules

**PO Number**:
- Required: "PO Number is required"
- Pattern: Alphanumeric, max 50 characters
- Error: "Invalid PO Number format"

**PO Amount**:
- Required: "PO Amount is required"
- Positive number: "Amount must be greater than zero"
- Max: 10,000,000 (₹ 1 crore)
- Error: "Invalid amount"

**PO Date**:
- Required: "PO Date is required"
- Valid date format: dd-mm-yyyy
- Not in future: "PO Date cannot be in the future"
- Error: "Invalid date format"

**Vendor Name**:
- Required: "Vendor Name is required"
- Max length: 100 characters
- Error: "Vendor Name is too long"

### Error Handling

**Extraction Failure**:
- If DocumentAgent fails to extract PO data, fields remain empty
- Show info message: "Unable to extract PO data automatically. Please enter manually."
- User can manually fill all fields

**Partial Extraction**:
- If some fields extracted, others empty, populate available fields
- Show info message: "Some PO data extracted. Please verify and complete missing fields."

**Network Failure**:
- If extraction status cannot be fetched, show loading state
- Retry button to fetch extraction results
- Fallback to manual entry if retry fails

This design ensures a smooth user experience with automatic data population while maintaining full user control and data accuracy.


## UI Design: Invoice Field Display and Auto-Population

### Overview

The Agency submission form will display five dedicated input fields for Invoice data that automatically populate after the Invoice document is uploaded and processed by the DocumentAgent. Additionally, a cross-validation section will display PO numbers from both Invoice and PO documents to help users verify consistency.

### Component Design

**Component Name**: InvoiceFieldsSection

**Location**: Agency submission form (agency_dashboard_page.dart), displayed after Invoice document upload card

**Layout**: 2-column grid on desktop/tablet, vertical stack on mobile

### Field Specifications

1. **Invoice No Field**
   - Type: Text input
   - Placeholder: "Enter invoice number"
   - Position: Row 1, Left column
   - Validation: Required, alphanumeric, max 50 characters
   - Auto-population source: `InvoiceData.InvoiceNumber` from extracted JSON

2. **Invoice Date Field**
   - Type: Date picker input
   - Placeholder: "dd-mm-yyyy"
   - Position: Row 1, Right column
   - Format: dd-mm-yyyy (e.g., "15-03-2024")
   - Validation: Required, valid date, not in future
   - Auto-population source: `InvoiceData.Date` from extracted JSON

3. **Invoice Amount Field**
   - Type: Currency input
   - Placeholder: "Enter amount"
   - Position: Row 2, Left column
   - Format: ₹ symbol prefix, comma-separated thousands, 2 decimal places (e.g., "₹ 10,500.00")
   - Validation: Required, positive number
   - Auto-population source: `InvoiceData.TotalAmount` from extracted JSON

4. **GSTIN Field**
   - Type: Text input
   - Placeholder: "Enter GSTIN"
   - Position: Row 2, Right column
   - Validation: Required, GSTIN format (15 characters alphanumeric)
   - Auto-population source: `InvoiceData.GSTIN` from extracted JSON

5. **Vendor Name Field**
   - Type: Text input
   - Placeholder: "Enter vendor name"
   - Position: Row 3, Full width
   - Validation: Required, max 100 characters
   - Auto-population source: `InvoiceData.VendorName` from extracted JSON

### Cross-Validation Section

**Component Name**: POCrossValidationSection

**Purpose**: Display PO numbers from both Invoice and PO documents for visual verification

**Fields**:

1. **PO Number (from Invoice)**
   - Type: Read-only text field
   - Placeholder: "-"
   - Position: Left column
   - Auto-population source: `InvoiceData.POReference` from extracted JSON
   - Style: Gray background, non-editable

2. **PO Number (from PO Document)**
   - Type: Read-only text field
   - Placeholder: "-"
   - Position: Right column
   - Auto-population source: `POData.PONumber` from PO fields section
   - Style: Gray background, non-editable

**Validation Indicator**:
- Green checkmark icon + "PO numbers match" when values are equal
- Red warning icon + "PO numbers do not match. Please verify." when values differ
- No indicator when either field is empty

### Visual Design

**Grid Layout (Desktop/Tablet ≥600px)**:
```
┌─────────────────────────────┬─────────────────────────────┐
│  Invoice No                 │  Invoice Date               │
│  [Enter invoice number]     │  [dd-mm-yyyy]          📅   │
└─────────────────────────────┴─────────────────────────────┘
┌─────────────────────────────┬─────────────────────────────┐
│  Invoice Amount (₹)         │  GSTIN                      │
│  [Enter amount]             │  [Enter GSTIN]              │
└─────────────────────────────┴─────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  Vendor Name                                              │
│  [Enter vendor name]                                      │
└───────────────────────────────────────────────────────────┘

Cross-Validation with PO Document
┌─────────────────────────────┬─────────────────────────────┐
│  PO Number (from Invoice)   │  PO Number (from PO Doc)    │
│  [Read-only value]          │  [Read-only value]          │
└─────────────────────────────┴─────────────────────────────┘
✓ PO numbers match  OR  ⚠ PO numbers do not match. Please verify.
```

**Stack Layout (Mobile <600px)**:
```
┌───────────────────────────────────────────────────────────┐
│  Invoice No                                               │
│  [Enter invoice number]                                   │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  Invoice Date                                        📅   │
│  [dd-mm-yyyy]                                             │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  Invoice Amount (₹)                                       │
│  [Enter amount]                                           │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  GSTIN                                                    │
│  [Enter GSTIN]                                            │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  Vendor Name                                              │
│  [Enter vendor name]                                      │
└───────────────────────────────────────────────────────────┘

Cross-Validation with PO Document
┌───────────────────────────────────────────────────────────┐
│  PO Number (from Invoice)                                 │
│  [Read-only value]                                        │
└───────────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────────┐
│  PO Number (from PO Document)                             │
│  [Read-only value]                                        │
└───────────────────────────────────────────────────────────┘
✓ PO numbers match  OR  ⚠ PO numbers do not match. Please verify.
```

### Styling

**Invoice Fields Section**:
- **Field Container**: Card with elevation 1, 8px border radius, 16px padding
- **Label**: Dark Blue (#003087), 14px font size, medium weight
- **Input**: 16px font size, regular weight, Light Blue (#00A3E0) focus border
- **Placeholder**: Gray (#9E9E9E), 16px font size, regular weight
- **Spacing**: 16px between fields (grid), 12px between fields (mobile)
- **Section Margin**: 24px top margin from Invoice upload card

**Cross-Validation Section**:
- **Section Header**: "Cross-Validation with PO Document", Dark Blue (#003087), 16px font size, medium weight
- **Field Container**: Card with gray background (#F5F5F5), 8px border radius, 12px padding
- **Read-only Fields**: Gray background (#EEEEEE), non-editable appearance
- **Match Indicator**: Green (#4CAF50) checkmark icon + text
- **Mismatch Indicator**: Red (#F44336) warning icon + text
- **Section Margin**: 16px top margin from Vendor Name field

### Behavior

**Initial State (No Invoice Uploaded)**:
- All five fields displayed with empty values
- Placeholders visible
- Fields are editable
- Cross-validation section hidden (only shown when both PO and Invoice uploaded)

**After Invoice Upload and Extraction**:
1. DocumentAgent processes Invoice document
2. Extracted InvoiceData is stored in Document.ExtractedDataJson
3. Frontend receives extraction complete event
4. InvoiceFieldsSection reads InvoiceData from submission state
5. Fields auto-populate with formatted values:
   - Invoice No: Direct string value
   - Invoice Date: Formatted as "15-03-2024"
   - Invoice Amount: Formatted as "₹ 10,500.00"
   - GSTIN: Direct string value
   - Vendor Name: Direct string value
6. Fields remain editable for manual corrections

**Cross-Validation Behavior**:
1. Cross-validation section appears only when BOTH PO and Invoice documents are uploaded
2. "PO Number (from Invoice)" auto-populates from InvoiceData.POReference
3. "PO Number (from PO Document)" auto-populates from POData.PONumber
4. System compares the two values:
   - If equal: Show green checkmark + "PO numbers match"
   - If different: Show red warning + "PO numbers do not match. Please verify."
   - If either is empty: Show no indicator
5. Both fields are read-only (user cannot edit)
6. If user edits PO Number in PO fields section, cross-validation updates in real-time

**Manual Edit Behavior**:
- User can click/tap any editable field to modify
- Edited values are preserved in local state
- If Invoice document is re-uploaded, edited fields are NOT overwritten
- Track "manually edited" flag per field to prevent overwriting

**Incomplete Extraction**:
- If InvoiceData field is null/empty, leave corresponding input field empty
- Show placeholder text
- User can manually enter value

### Data Flow

```
1. User uploads Invoice document
   ↓
2. DocumentAgent.ExtractInvoiceAsync() processes document
   ↓
3. InvoiceData stored in Document.ExtractedDataJson
   ↓
4. Frontend polls/watches submission state
   ↓
5. SubmissionNotifier updates with extracted InvoiceData
   ↓
6. InvoiceFieldsSection widget rebuilds with new data
   ↓
7. TextEditingController values updated (if not manually edited)
   ↓
8. User sees auto-populated fields
   ↓
9. If PO also uploaded, POCrossValidationSection appears
   ↓
10. Cross-validation compares PO numbers and shows indicator
   ↓
11. User can edit any field
   ↓
12. On submit, current field values (auto or manual) sent to API
```

### Implementation Notes

**State Management**:
- Use Riverpod StateNotifier to manage Invoice field values
- Track "manually edited" flags for each field
- Separate state for extracted data vs. current field values
- Watch both POData and InvoiceData for cross-validation

**Widget Structure**:
```dart
class InvoiceFieldsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceData = ref.watch(submissionProvider).invoiceData;
    final poData = ref.watch(submissionProvider).poData;
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? _buildGridLayout(invoiceData)
                : _buildStackLayout(invoiceData),
          ),
        ),
        if (invoiceData != null && poData != null)
          const SizedBox(height: 16),
        if (invoiceData != null && poData != null)
          POCrossValidationSection(
            poFromInvoice: invoiceData.poReference,
            poFromPODoc: poData.poNumber,
          ),
      ],
    );
  }
  
  Widget _buildGridLayout(InvoiceData? invoiceData) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: InvoiceNoField(initialValue: invoiceData?.invoiceNumber)),
            const SizedBox(width: 16),
            Expanded(child: InvoiceDateField(initialValue: invoiceData?.date)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: InvoiceAmountField(initialValue: invoiceData?.totalAmount)),
            const SizedBox(width: 16),
            Expanded(child: GSTINField(initialValue: invoiceData?.gstin)),
          ],
        ),
        const SizedBox(height: 16),
        VendorNameField(initialValue: invoiceData?.vendorName),
      ],
    );
  }
  
  Widget _buildStackLayout(InvoiceData? invoiceData) {
    return Column(
      children: [
        InvoiceNoField(initialValue: invoiceData?.invoiceNumber),
        const SizedBox(height: 12),
        InvoiceDateField(initialValue: invoiceData?.date),
        const SizedBox(height: 12),
        InvoiceAmountField(initialValue: invoiceData?.totalAmount),
        const SizedBox(height: 12),
        GSTINField(initialValue: invoiceData?.gstin),
        const SizedBox(height: 12),
        VendorNameField(initialValue: invoiceData?.vendorName),
      ],
    );
  }
}
```

**Cross-Validation Widget**:
```dart
class POCrossValidationSection extends StatelessWidget {
  final String? poFromInvoice;
  final String? poFromPODoc;
  
  const POCrossValidationSection({
    Key? key,
    this.poFromInvoice,
    this.poFromPODoc,
  }) : super(key: key);
  
  bool get isMatch => 
    poFromInvoice != null && 
    poFromPODoc != null && 
    poFromInvoice == poFromPODoc;
  
  bool get hasMismatch => 
    poFromInvoice != null && 
    poFromPODoc != null && 
    poFromInvoice != poFromPODoc;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cross-Validation with PO Document',
              style: TextStyle(
                color: BajajColors.darkBlue,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(
                    'PO Number (from Invoice)',
                    poFromInvoice ?? '-',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildReadOnlyField(
                    'PO Number (from PO Document)',
                    poFromPODoc ?? '-',
                  ),
                ),
              ],
            ),
            if (isMatch || hasMismatch) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isMatch ? Icons.check_circle : Icons.warning,
                    color: isMatch ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMatch 
                      ? 'PO numbers match' 
                      : 'PO numbers do not match. Please verify.',
                    style: TextStyle(
                      color: isMatch ? Colors.green : Colors.red,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BajajColors.darkBlue,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
```

**GSTIN Validation**:
```dart
String? validateGSTIN(String? value) {
  if (value == null || value.isEmpty) {
    return 'GSTIN is required';
  }
  
  // GSTIN format: 15 characters alphanumeric
  final gstinRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
  
  if (!gstinRegex.hasMatch(value)) {
    return 'Invalid GSTIN format';
  }
  
  return null;
}
```

### Accessibility

- Add semantic labels to all fields: "Invoice Number input", "Invoice Date input", etc.
- Add semantic label to cross-validation section: "PO number cross-validation"
- Ensure 48x48 minimum touch targets
- Provide clear error messages for validation failures
- Support keyboard navigation (tab order: Invoice No → Invoice Date → Invoice Amount → GSTIN → Vendor Name)
- Announce auto-population to screen readers: "Invoice fields auto-populated from document"
- Announce cross-validation result to screen readers: "PO numbers match" or "PO numbers do not match"

### Testing

**Widget Tests**:
1. Test initial empty state renders correctly
2. Test grid layout on desktop breakpoint
3. Test stack layout on mobile breakpoint
4. Test auto-population when InvoiceData is provided
5. Test manual edit preserves user input
6. Test currency formatting for Invoice Amount
7. Test date formatting for Invoice Date
8. Test GSTIN validation
9. Test cross-validation section appears when both PO and Invoice uploaded
10. Test cross-validation shows match indicator when PO numbers equal
11. Test cross-validation shows mismatch indicator when PO numbers differ
12. Test cross-validation hidden when only one document uploaded

**Integration Tests**:
1. Upload Invoice document → verify fields auto-populate
2. Edit auto-populated field → re-upload Invoice → verify edit is preserved
3. Upload PO then Invoice → verify cross-validation section appears
4. Upload Invoice with matching PO reference → verify green checkmark
5. Upload Invoice with non-matching PO reference → verify red warning
6. Submit form with auto-populated values → verify values sent to API

### Validation Rules

**Invoice No**:
- Required: "Invoice Number is required"
- Pattern: Alphanumeric, max 50 characters
- Error: "Invalid Invoice Number format"

**Invoice Date**:
- Required: "Invoice Date is required"
- Valid date format: dd-mm-yyyy
- Not in future: "Invoice Date cannot be in the future"
- Error: "Invalid date format"

**Invoice Amount**:
- Required: "Invoice Amount is required"
- Positive number: "Amount must be greater than zero"
- Max: 10,000,000 (₹ 1 crore)
- Error: "Invalid amount"

**GSTIN**:
- Required: "GSTIN is required"
- Format: 15 characters, specific pattern (2 digits + 5 letters + 4 digits + 1 letter + 1 alphanumeric + Z + 1 alphanumeric)
- Error: "Invalid GSTIN format"

**Vendor Name**:
- Required: "Vendor Name is required"
- Max length: 100 characters
- Error: "Vendor Name is too long"

### Error Handling

**Extraction Failure**:
- If DocumentAgent fails to extract Invoice data, fields remain empty
- Show info message: "Unable to extract Invoice data automatically. Please enter manually."
- User can manually fill all fields

**Partial Extraction**:
- If some fields extracted, others empty, populate available fields
- Show info message: "Some Invoice data extracted. Please verify and complete missing fields."

**Cross-Validation Unavailable**:
- If PO reference not extracted from Invoice, show "-" in cross-validation field
- If PO document not uploaded, hide cross-validation section entirely

**Network Failure**:
- If extraction status cannot be fetched, show loading state
- Retry button to fetch extraction results
- Fallback to manual entry if retry fails

This design ensures a smooth user experience with automatic data population, real-time cross-validation, and full user control over data accuracy.


## Design: Requirement 22-24 - Hierarchical Structure and Campaign Details Improvements

### Data Model Changes

#### Correct Hierarchy: Campaign → Invoice

The document structure follows this hierarchy:
- **DocumentPackage (FAP)** - Root container
  - **PO Document** (1:1) - Single Purchase Order
  - **Campaigns** (1:Many) - Multiple campaigns per PO
    - **Invoices** (1:Many per Campaign) - Multiple invoices per campaign
    - **Photos** (1:Many per Campaign) - Up to 50 photos per campaign
    - **Cost Summary** (1:1 per Campaign) - Single cost summary
    - **Activity Summary** (1:1 per Campaign) - Single activity summary
  - **Additional Documents** (at PO level)
    - **Enquiry Document** (0:1) - Optional single enquiry doc
    - **Other Documents** (0:Many) - Optional additional docs

#### Campaign Data Model

```dart
class CampaignData {
  final String id;
  String campaignName;        // NEW: Required field
  String startDate;
  String endDate;
  String workingDays;         // Auto-calculated
  String dealershipName;
  String dealershipAddress;
  // REMOVED: gpsLocation - No longer needed
  String state;
  String totalCost;
  PlatformFile? costSummaryFile;
  PlatformFile? activitySummaryFile;
  List<PlatformFile> photos;  // Max 50 photos
  List<InvoiceData> invoices; // Invoices are children of Campaign
}
```

### UI Changes

#### Step 2: Campaigns (not "Invoices & Campaigns")

1. **Add Campaign** button at top level
2. Each Campaign contains:
   - Campaign Name field (NEW, required)
   - Activity Duration (Start Date, End Date, Working Days)
   - Dealership Details (Name, Address) - GPS REMOVED
   - Invoices section (Add Invoice button within campaign)
   - Photos section (max 50)
   - Cost Summary upload
   - Activity Summary upload

#### Removed Features
- GPS Location field and Capture GPS button
- "Campaign 1", "Campaign 2" numbered headers

#### Added Features
- Campaign Name text field (required)
- Photo limit increased from 20 to 50
- Calendar picker fix for date fields

### Validation Rules

| Field | Validation |
|-------|------------|
| Campaign Name | Required, non-empty |
| Start Date | Required, valid date format |
| End Date | Required, >= Start Date |
| Photos | At least 1, max 50 per campaign |
| Invoices | At least 1 per campaign |
| Cost Summary | Required per campaign |
| Activity Summary | Required per campaign |

### API Endpoint Changes

Step 2 endpoints now use Campaign as parent:
- `POST /api/hierarchical/{packageId}/campaigns` - Add campaign
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/invoices` - Add invoice to campaign
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/photos` - Add photos
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/cost-summary` - Upload cost summary
- `POST /api/hierarchical/{packageId}/campaigns/{campaignId}/activity-summary` - Upload activity summary
