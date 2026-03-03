# Bajaj Document Processing System - Architecture Diagram

## System Architecture Overview

```mermaid
graph TB
    subgraph "Client Layer"
        Flutter[Flutter Web/Mobile App]
    end

    subgraph "API Gateway Layer"
        API[ASP.NET Core 8 Web API]
        Swagger[Swagger/OpenAPI]
    end

    subgraph "Application Layer"
        Auth[Authentication Service]
        DocService[Document Service]
        WorkflowOrch[Workflow Orchestrator]
    end

    subgraph "AI Agent Layer"
        DocAgent[Document Agent]
        ValidationAgent[Validation Agent]
        ConfidenceAgent[Confidence Score Service]
        RecommendationAgent[Recommendation Agent]
        EmailAgent[Email Agent]
        NotificationAgent[Notification Agent]
        AnalyticsAgent[Analytics Agent]
        ChatAgent[Chat Service]
    end

    subgraph "Infrastructure Layer"
        FileStorage[File Storage Service]
        MalwareScan[Malware Scan Service]
        VectorSearch[Vector Search Service]
        EmbeddingService[Embedding Service]
        GuardrailServices[Guardrail Services]
    end

    subgraph "Azure Services"
        AzureOpenAI[Azure OpenAI<br/>GPT-4 Vision & Embeddings]
        AzureBlobStorage[Azure Blob Storage]
        AzureAISearch[Azure AI Search]
        AzureComm[Azure Communication Services]
        AzureSQL[Azure SQL Database]
    end

    subgraph "External Systems"
        SAP[SAP System]
    end

    Flutter --> API
    API --> Swagger
    API --> Auth
    API --> DocService
    API --> WorkflowOrch

    WorkflowOrch --> DocAgent
    WorkflowOrch --> ValidationAgent
    WorkflowOrch --> ConfidenceAgent
    WorkflowOrch --> RecommendationAgent
    WorkflowOrch --> EmailAgent
    WorkflowOrch --> NotificationAgent

    DocService --> FileStorage
    DocService --> MalwareScan

    ChatAgent --> VectorSearch
    ChatAgent --> EmbeddingService
    ChatAgent --> GuardrailServices

    AnalyticsAgent --> EmbeddingService
    AnalyticsAgent --> VectorSearch

    DocAgent --> AzureOpenAI
    ValidationAgent --> SAP
    ValidationAgent --> AzureSQL
    EmailAgent --> AzureComm
    FileStorage --> AzureBlobStorage
    VectorSearch --> AzureAISearch
    EmbeddingService --> AzureOpenAI

    Auth --> AzureSQL
    DocService --> AzureSQL
    WorkflowOrch --> AzureSQL

    style Flutter fill:#e1f5ff
    style API fill:#fff4e1
    style AzureOpenAI fill:#d4edda
    style AzureBlobStorage fill:#d4edda
    style AzureAISearch fill:#d4edda
    style AzureComm fill:#d4edda
    style AzureSQL fill:#d4edda
    style SAP fill:#f8d7da
```

## Clean Architecture Layers

```mermaid
graph LR
    subgraph "Presentation Layer"
        Controllers[API Controllers]
        Middleware[Middleware]
    end

    subgraph "Application Layer"
        Interfaces[Service Interfaces]
        DTOs[Data Transfer Objects]
    end

    subgraph "Domain Layer"
        Entities[Domain Entities]
        Enums[Enumerations]
    end

    subgraph "Infrastructure Layer"
        Services[Service Implementations]
        Persistence[Database Context]
        AzureIntegrations[Azure Integrations]
    end

    Controllers --> Interfaces
    Middleware --> Interfaces
    Interfaces --> Entities
    Services --> Interfaces
    Services --> Persistence
    Services --> AzureIntegrations
    Persistence --> Entities

    style Controllers fill:#fff4e1
    style Interfaces fill:#e1f5ff
    style Entities fill:#d4edda
    style Services fill:#f8d7da
```

## Document Processing Workflow

```mermaid
sequenceDiagram
    participant Agency
    participant API
    participant FileStorage
    participant MalwareScan
    participant DocAgent
    participant ValidationAgent
    participant ConfidenceAgent
    participant RecommendationAgent
    participant EmailAgent
    participant ASM

    Agency->>API: Upload Documents
    API->>FileStorage: Store Files
    FileStorage->>MalwareScan: Scan for Malware
    MalwareScan-->>API: Scan Result
    
    API->>DocAgent: Classify Documents
    DocAgent->>Azure OpenAI: GPT-4 Vision
    Azure OpenAI-->>DocAgent: Classification
    
    DocAgent->>Azure Doc Intel: Extract Data
    Azure Doc Intel-->>DocAgent: Structured Data
    
    API->>ValidationAgent: Validate Package
    ValidationAgent->>SAP: Verify PO/Vendor
    SAP-->>ValidationAgent: Validation Result
    
    alt Validation Failed
        ValidationAgent-->>EmailAgent: Send Failure Email
        EmailAgent->>Agency: Validation Failed
    else Validation Passed
        ValidationAgent->>ConfidenceAgent: Calculate Score
        ConfidenceAgent->>RecommendationAgent: Generate Recommendation
        RecommendationAgent-->>EmailAgent: Send Success Email
        EmailAgent->>ASM: Review Required
    end
```

## Chat Service Architecture

```mermaid
graph TB
    subgraph "User Interface"
        User[User Query]
    end

    subgraph "Chat Service"
        InputGuard[Input Guardrails]
        QueryProc[Query Processor]
        OutputGuard[Output Guardrails]
    end

    subgraph "RAG Pipeline"
        Embedding[Embedding Service]
        VectorDB[Azure AI Search]
        ContextRetrieval[Context Retrieval]
    end

    subgraph "AI Generation"
        GPT4[Azure OpenAI GPT-4]
    end

    subgraph "Data Sources"
        Analytics[Analytics Data]
        Submissions[Submission History]
    end

    User --> InputGuard
    InputGuard --> QueryProc
    QueryProc --> Embedding
    Embedding --> VectorDB
    VectorDB --> ContextRetrieval
    ContextRetrieval --> GPT4
    
    Analytics --> VectorDB
    Submissions --> VectorDB
    
    GPT4 --> OutputGuard
    OutputGuard --> User

    style User fill:#e1f5ff
    style GPT4 fill:#d4edda
    style VectorDB fill:#d4edda
```

## Data Flow Architecture

```mermaid
graph LR
    subgraph "Frontend"
        FlutterApp[Flutter Application]
    end

    subgraph "Backend API"
        AuthController[Auth Controller]
        DocsController[Documents Controller]
        SubmissionsController[Submissions Controller]
        AnalyticsController[Analytics Controller]
        ChatController[Chat Controller]
    end

    subgraph "Database"
        Users[(Users)]
        Documents[(Documents)]
        Packages[(Document Packages)]
        Validations[(Validation Results)]
        Confidence[(Confidence Scores)]
        Recommendations[(Recommendations)]
        Conversations[(Conversations)]
        AuditLogs[(Audit Logs)]
    end

    FlutterApp --> AuthController
    FlutterApp --> DocsController
    FlutterApp --> SubmissionsController
    FlutterApp --> AnalyticsController
    FlutterApp --> ChatController

    AuthController --> Users
    DocsController --> Documents
    DocsController --> Packages
    SubmissionsController --> Packages
    SubmissionsController --> Validations
    SubmissionsController --> Confidence
    SubmissionsController --> Recommendations
    AnalyticsController --> Packages
    AnalyticsController --> Confidence
    ChatController --> Conversations

    style FlutterApp fill:#e1f5ff
    style Users fill:#d4edda
    style Documents fill:#d4edda
    style Packages fill:#d4edda
```

## Azure Services Integration

```mermaid
graph TB
    subgraph "Application Services"
        DocAgent[Document Agent]
        ValidationAgent[Validation Agent]
        EmailAgent[Email Agent]
        ChatService[Chat Service]
        AnalyticsAgent[Analytics Agent]
    end

    subgraph "Azure AI Services"
        OpenAI[Azure OpenAI<br/>- GPT-4<br/>- GPT-4 Vision<br/>- text-embedding-ada-002]
        DocIntel[Azure Document Intelligence<br/>- prebuilt-invoice<br/>- prebuilt-document]
        AISearch[Azure AI Search<br/>- Vector Search<br/>- HNSW Algorithm]
    end

    subgraph "Azure Data Services"
        BlobStorage[Azure Blob Storage<br/>- Document Storage<br/>- Container: documents]
        SQLDatabase[Azure SQL Database<br/>- Primary Data Store]
    end

    subgraph "Azure Communication"
        CommServices[Azure Communication Services<br/>- Email Delivery<br/>- Retry Logic]
    end

    DocAgent --> OpenAI
    DocAgent --> DocIntel
    ValidationAgent --> SQLDatabase
    EmailAgent --> CommServices
    ChatService --> OpenAI
    ChatService --> AISearch
    AnalyticsAgent --> OpenAI
    AnalyticsAgent --> AISearch
    
    DocAgent --> BlobStorage
    ValidationAgent --> BlobStorage

    style OpenAI fill:#d4edda
    style DocIntel fill:#d4edda
    style AISearch fill:#d4edda
    style BlobStorage fill:#d4edda
    style SQLDatabase fill:#d4edda
    style CommServices fill:#d4edda
```

## Security Architecture

```mermaid
graph TB
    subgraph "Client"
        User[User]
    end

    subgraph "Authentication"
        Login[Login Endpoint]
        JWT[JWT Token Generation]
    end

    subgraph "Authorization"
        RoleCheck[Role-Based Access Control]
        Policies[Authorization Policies<br/>- AgencyOnly<br/>- ASMOnly<br/>- HQOnly<br/>- ASMOrHQ]
    end

    subgraph "Guardrails"
        InputGuard[Input Guardrails<br/>- PII Detection<br/>- SQL Injection<br/>- Prompt Injection]
        AuthzGuard[Authorization Guardrails<br/>- Data Access Control]
        OutputGuard[Output Guardrails<br/>- PII Leakage<br/>- Hallucination Check]
    end

    subgraph "Audit"
        AuditLog[Audit Logging Middleware]
        AuditDB[(Audit Logs Database)]
    end

    User --> Login
    Login --> JWT
    JWT --> RoleCheck
    RoleCheck --> Policies
    Policies --> InputGuard
    InputGuard --> AuthzGuard
    AuthzGuard --> OutputGuard
    OutputGuard --> AuditLog
    AuditLog --> AuditDB

    style JWT fill:#d4edda
    style Policies fill:#fff4e1
    style InputGuard fill:#f8d7da
    style AuthzGuard fill:#f8d7da
    style OutputGuard fill:#f8d7da
```

## Deployment Architecture

```mermaid
graph TB
    subgraph "Client Tier"
        Browser[Web Browser]
        Mobile[Mobile Device]
    end

    subgraph "Azure Static Web Apps"
        FlutterWeb[Flutter Web App<br/>Port: 8080]
    end

    subgraph "Azure App Service"
        APIService[.NET 8 Web API<br/>Port: 5000/5001]
    end

    subgraph "Azure Services"
        KeyVault[Azure Key Vault<br/>Secrets Management]
        AppInsights[Application Insights<br/>Monitoring & Logging]
        Monitor[Azure Monitor<br/>Alerts & Metrics]
    end

    subgraph "Data Tier"
        SQLServer[Azure SQL Database]
        BlobStore[Azure Blob Storage]
        SearchIndex[Azure AI Search Index]
    end

    Browser --> FlutterWeb
    Mobile --> FlutterWeb
    FlutterWeb --> APIService
    
    APIService --> KeyVault
    APIService --> SQLServer
    APIService --> BlobStore
    APIService --> SearchIndex
    
    APIService --> AppInsights
    AppInsights --> Monitor

    style FlutterWeb fill:#e1f5ff
    style APIService fill:#fff4e1
    style KeyVault fill:#d4edda
    style SQLServer fill:#d4edda
```

## Technology Stack Summary

### Frontend
- **Framework**: Flutter 3.2+ (Dart 3.2+)
- **State Management**: Riverpod
- **HTTP Client**: Dio
- **Navigation**: GoRouter
- **Storage**: Flutter Secure Storage, Hive

### Backend
- **Framework**: ASP.NET Core 8 (C# .NET 8)
- **Architecture**: Clean Architecture
- **ORM**: Entity Framework Core 8
- **Database**: Azure SQL Database
- **Authentication**: JWT Bearer Tokens

### AI & Azure Services
- **AI Orchestration**: Semantic Kernel
- **LLM**: Azure OpenAI (GPT-4, GPT-4 Vision)
- **Embeddings**: text-embedding-ada-002
- **Document Processing**: Azure Document Intelligence
- **Vector Database**: Azure AI Search
- **File Storage**: Azure Blob Storage
- **Email**: Azure Communication Services

### Testing
- **Unit Testing**: xUnit
- **Property-Based Testing**: FsCheck
- **Mocking**: Moq

---

## Key Design Patterns

1. **Clean Architecture**: Separation of concerns with Domain, Application, Infrastructure, and API layers
2. **Multi-Agent System**: Specialized AI agents for different tasks
3. **Repository Pattern**: Data access abstraction
4. **Dependency Injection**: Loose coupling and testability
5. **CQRS-lite**: Separation of read and write operations
6. **Retry Pattern**: Resilient external service calls
7. **Circuit Breaker**: Fault tolerance for Azure services
8. **RAG (Retrieval-Augmented Generation)**: Context-aware AI responses

---

## Scalability Considerations

1. **Horizontal Scaling**: Azure App Service can scale out
2. **Caching**: Redis for frequently accessed data
3. **Async Processing**: Background jobs for document processing
4. **CDN**: Static assets served via Azure CDN
5. **Database Optimization**: Indexed queries, connection pooling
6. **Rate Limiting**: API throttling to prevent abuse

---

## Security Measures

1. **Authentication**: JWT tokens with expiration
2. **Authorization**: Role-based access control (RBAC)
3. **Data Encryption**: TLS in transit, encryption at rest
4. **Input Validation**: Guardrails for malicious input
5. **Output Filtering**: PII detection and removal
6. **Audit Logging**: Complete audit trail
7. **Secrets Management**: Azure Key Vault
8. **Malware Scanning**: File upload validation

---

*Last Updated: March 3, 2026*
