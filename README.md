# Bajaj Document Processing System

An intelligent multi-agent document processing system for automating purchase order, invoice, and cost summary validation workflows.

## Overview

The Bajaj Document Processing System automates the processing, validation, and approval workflow for business documents. It uses AI-powered agents to classify documents, extract data, validate consistency, calculate confidence scores, and generate approval recommendations.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Frontend                          │
│  (Mobile & Web - Agency, ASM, HQ User Interfaces)          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    .NET 8 Web API                           │
│              (RESTful API with JWT Auth)                    │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  AI Agents   │   │   Database   │   │   External   │
│              │   │              │   │   Services   │
│ • Document   │   │ SQL Server   │   │ • Azure AI   │
│ • Validation │   │              │   │ • SAP        │
│ • Confidence │   │              │   │ • ACS Email  │
│ • Recommend  │   │              │   │ • Blob Store │
│ • Email      │   │              │   │ • AI Search  │
│ • Analytics  │   │              │   │              │
│ • Notify     │   │              │   │              │
│ • Chat       │   │              │   │              │
└──────────────┘   └──────────────┘   └──────────────┘
```

## Key Features

### For Agency Users
- Upload documents (PO, Invoice, Cost Summary, Photos, Additional Documents)
- Track submission status in real-time
- Receive email notifications on approval/rejection
- View validation results and confidence scores

### For ASM (Area Sales Manager) Users
- Review submitted document packages
- View AI-powered recommendations with evidence
- Approve, reject, or request re-upload
- Access detailed validation results

### For HQ (Headquarters) Users
- View KPI dashboards with analytics
- Export data to Excel
- Chat with AI assistant for analytics queries
- Monitor system performance and ROI

## Technology Stack

### Backend
- **.NET 8 Web API**: RESTful API with Clean Architecture
- **Entity Framework Core 8**: ORM for SQL Server
- **Semantic Kernel**: AI orchestration framework
- **Azure OpenAI GPT-4**: Natural language processing
- **Azure Document Intelligence**: Document extraction
- **Azure AI Search**: Vector database for semantic search
- **Azure Communication Services**: Email delivery
- **Azure Blob Storage**: Document storage
- **Redis**: Caching layer

### Frontend
- **Flutter 3.2+**: Cross-platform mobile and web
- **Riverpod**: State management
- **Dio**: HTTP client
- **GoRouter**: Navigation
- **fl_chart**: Data visualization
- **Hive**: Local caching

### Testing
- **xUnit + FsCheck**: Property-based testing for .NET
- **Flutter Test**: Widget and integration testing

## User Roles

1. **Agency**: Submit documents and track status
2. **ASM (Area Sales Manager)**: Review and approve/reject submissions
3. **HQ (Headquarters)**: Access analytics and insights

## AI Agents

### 1. Document Agent
- Classifies documents using Azure OpenAI GPT-4 Vision
- Extracts structured data using Azure Document Intelligence
- Calculates per-document confidence scores

### 2. Validation Agent
- Verifies PO data against SAP system
- Validates cross-document consistency
- Performs 11-item completeness check

### 3. Confidence Score Service
- Calculates weighted confidence scores
- Weights: PO (30%), Invoice (30%), Cost Summary (20%), Activity (10%), Photos (10%)

### 4. Recommendation Agent
- Generates APPROVE/REVIEW/REJECT recommendations
- Provides plain-English evidence summaries using Semantic Kernel

### 5. Email Agent
- Generates scenario-based emails using Semantic Kernel
- Sends notifications via Azure Communication Services

### 6. Analytics Agent
- Calculates KPIs and ROI metrics
- Generates AI narratives using Azure OpenAI
- Exports data to Excel

### 7. Notification Agent
- Manages in-app notifications
- Sends email notifications

### 8. Chat Service
- Conversational AI assistant using Semantic Kernel
- Semantic search over analytics data
- Multi-layer guardrails for security

## Project Structure

```
bajaj-document-processing/
├── backend/                    # .NET 8 Web API
│   ├── src/
│   │   ├── BajajDocumentProcessing.API/
│   │   ├── BajajDocumentProcessing.Application/
│   │   ├── BajajDocumentProcessing.Domain/
│   │   └── BajajDocumentProcessing.Infrastructure/
│   └── tests/
│       └── BajajDocumentProcessing.Tests/
├── frontend/                   # Flutter App
│   ├── lib/
│   │   ├── core/
│   │   ├── features/
│   │   └── main.dart
│   └── test/
└── .kiro/specs/               # Specification documents
    └── bajaj-document-processing-system/
        ├── requirements.md
        ├── design.md
        └── tasks.md
```

## Getting Started

### Prerequisites
- .NET 8 SDK
- Flutter 3.2+
- SQL Server
- Azure account with configured services
- Redis (optional)

### Backend Setup
```bash
cd backend
dotnet restore
dotnet ef database update --project src/BajajDocumentProcessing.API
dotnet run --project src/BajajDocumentProcessing.API
```

### Frontend Setup
```bash
cd frontend
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

## Configuration

### Backend Configuration
Update `backend/src/BajajDocumentProcessing.API/appsettings.json`:
- Database connection string
- Azure service credentials
- SAP connection details
- Redis connection string

### Frontend Configuration
Update `frontend/lib/core/constants/api_constants.dart`:
- Backend API base URL

## Testing

### Backend Tests
```bash
cd backend
dotnet test
```

### Frontend Tests
```bash
cd frontend
flutter test
```

## Branding

The application follows Bajaj brand guidelines:
- **Primary Color**: Dark Blue (#003087)
- **Secondary Color**: Light Blue (#00A3E0)
- **Background**: White (#FFFFFF)

## Security Features

- JWT-based authentication
- Role-based access control
- TLS 1.3 encryption in transit
- AES-256 encryption at rest
- Multi-layer AI guardrails
- Audit logging
- Malware scanning for uploads

## License

Proprietary - Bajaj Auto Limited

## Support

For support and questions, contact the development team.
