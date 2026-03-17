# Flutter Pages & API Endpoints

This document lists all pages in the Flutter application and the backend APIs they consume.

**Base URL:** `http://localhost:5000/api`

---

## Authentication Pages

### 1. Login Page (Active)
**File:** `lib/features/auth/presentation/pages/login_page.dart`  
**Role:** All users  
**State Management:** Riverpod

**APIs:**
- `POST /auth/login` - User login with email/password
- `GET /auth/me` - Check current authentication status

---

### 2. New Login Page (Legacy)
**File:** `lib/features/auth/presentation/pages/new_login_page.dart`  
**Role:** All users  
**State Management:** Direct Dio

**APIs:**
- `POST /auth/login` - User login with email/password

---

## Agency Pages

### 3. Agency Dashboard
**File:** `lib/features/submission/presentation/pages/agency_dashboard_page.dart`  
**Role:** Agency users  
**Description:** View all submissions with status filtering and search

**APIs:**
- `GET /submissions` - Load all submissions for the logged-in agency user

---

### 4. Agency Submission Detail
**File:** `lib/features/submission/presentation/pages/agency_submission_detail_page.dart`  
**Role:** Agency users  
**Description:** View detailed submission information with documents

**APIs:**
- `GET /submissions/{id}` - Load full submission details
- `GET /hierarchical/{id}/structure` - Load campaign/photo/cost/activity documents
- `GET /documents/{id}` - Download document by ID

---

### 5. Agency Upload Page (Wizard)
**File:** `lib/features/submission/presentation/pages/agency_upload_page.dart`  
**Role:** Agency users  
**Description:** 3-step wizard for creating/editing submissions

**APIs:**
- `GET /pos` - Load available Purchase Orders (with optional `?search=` parameter)
- `GET /pos/states` - Load Indian states dropdown
- `GET /submissions/{id}` - Pre-populate wizard in edit mode
- `POST /submissions` - Create new package from selected PO
- `POST /documents/upload` - Upload PO, Invoice, and additional documents
- `POST /hierarchical/{packageId}/campaigns` - Create a team/campaign
- `POST /hierarchical/{packageId}/campaigns/{campaignId}/photos` - Upload photos for a campaign
- `POST /hierarchical/{packageId}/campaigns/{campaignId}/cost-summary` - Upload cost summary
- `POST /hierarchical/{packageId}/campaigns/{campaignId}/activity-summary` - Upload activity summary
- `POST /hierarchical/{packageId}/enquiry-doc` - Upload enquiry document
- `POST /submissions/{packageId}/process-async` - Trigger background processing (new submission)
- `PATCH /submissions/{packageId}/resubmit` - Resubmit after rejection (edit mode)

---

### 6. Document Upload Page (Legacy)
**File:** `lib/features/submission/presentation/pages/document_upload_page.dart`  
**Role:** Agency users  
**State Management:** Riverpod  
**Status:** Largely superseded by Agency Upload Page

**APIs:**
- `POST /documents/upload` - Upload documents via SubmissionNotifier

---

### 7. Conversational Submission Page
**File:** `lib/features/conversational_submission/presentation/pages/conversational_submission_page.dart`  
**Role:** Agency users  
**Description:** Chat-based submission flow with AI assistant

**APIs:**
- `POST /conversation/message` - Start/continue conversation with AI
- `POST /documents/upload` - Upload files per step (Invoice, ActivitySummary, CostSummary, Photo, EnquiryDump, AdditionalDocument)
- **SignalR Hub:** `/hubs/submission` - Real-time processing updates

---

### 8. My Submissions Page
**File:** `lib/features/conversational_submission/presentation/pages/my_submissions_page.dart`  
**Role:** Agency users  
**Description:** List user's conversational submissions

**APIs:**
- `GET /submissions` - List all submissions for the current user

---

## ASM (Area Sales Manager) Pages

### 9. ASM Review Page
**File:** `lib/features/approval/presentation/pages/asm_review_page.dart`  
**Role:** ASM users  
**Description:** Dashboard showing submissions pending ASM approval

**APIs:**
- `GET /submissions` - List all submissions
- `GET /analytics/quarterly-fap?quarter={Q1-Q4}&year={YYYY}` - Load quarterly KPI data

---

### 10. ASM Review Detail Page
**File:** `lib/features/approval/presentation/pages/asm_review_detail_page.dart`  
**Role:** ASM users  
**Description:** Detailed review page with approve/reject actions

**APIs:**
- `GET /submissions/{id}` - Load full submission details
- `GET /hierarchical/{id}/structure` - Load campaign/photo/cost/activity documents
- `PATCH /submissions/{id}/asm-approve` - Approve submission with optional notes
- `PATCH /submissions/{id}/asm-reject` - Reject submission with reason (required)
- `GET /documents/{id}` - Download document by ID

---

## HQ/RA (Regional Authority) Pages

### 11. HQ Review Page
**File:** `lib/features/approval/presentation/pages/hq_review_page.dart`  
**Role:** HQ/RA users  
**Description:** Dashboard showing submissions pending HQ approval

**APIs:**
- `GET /submissions` - List all submissions
- `GET /analytics/quarterly-fap?quarter={Q1-Q4}&year={YYYY}` - Load quarterly KPI data

---

### 12. HQ Review Detail Page
**File:** `lib/features/approval/presentation/pages/hq_review_detail_page.dart`  
**Role:** HQ/RA users  
**Description:** Final approval page with approve/reject actions

**APIs:**
- `GET /submissions/{id}` - Load full submission details
- `GET /hierarchical/{id}/structure` - Load campaign/photo/cost/activity documents
- `PATCH /submissions/{id}/hq-approve` - Final approval with optional notes
- `PATCH /submissions/{id}/hq-reject` - Reject submission with reason (min 10 characters)
- `GET /documents/{id}` - Download document by ID

---

### 13. Submission Review Page (Legacy)
**File:** `lib/features/approval/presentation/pages/submission_review_page.dart`  
**Role:** ASM/HQ users  
**State Management:** Riverpod  
**Status:** Legacy review page

**APIs:**
- `GET /submissions/{id}` - Load package details
- `POST /submissions/{id}/approve` - Approve package
- `POST /submissions/{id}/reject` - Reject with reason
- `POST /submissions/{id}/request-reupload` - Request reupload

---

## Analytics Pages

### 14. Analytics Dashboard Page (Legacy)
**File:** `lib/features/analytics/presentation/pages/analytics_dashboard_page.dart`  
**Role:** HQ users  
**State Management:** Riverpod  
**Status:** Legacy analytics page

**APIs:**
- `GET /analytics/kpis` - Load KPI dashboard data
- `GET /analytics/state-roi` - Load state-level ROI data
- `GET /analytics/campaign-breakdown` - Load campaign breakdown data
- `GET /analytics/export` - Export analytics to Excel

---

### 15. HQ Analytics Page
**File:** `lib/features/analytics/presentation/pages/hq_analytics_page.dart`  
**Role:** HQ users  
**Description:** Analytics dashboard with charts and trends

**APIs:**
- `GET /analytics/overview` - Load overview statistics and analytics data

---

## Chat/Assistant Pages

### 16. Chat Page
**File:** `lib/features/chat/presentation/pages/chat_page.dart`  
**Role:** All users  
**State Management:** Riverpod  
**Description:** AI-powered analytics chat assistant

**APIs:**
- `GET /chat/history` - Load conversation history
- `POST /chat/message` - Send message and receive AI response

---

## API Endpoints Summary

### Authentication
- `POST /auth/login` - User login
- `POST /auth/logout` - User logout
- `GET /auth/me` - Get current user

### Submissions
- `GET /submissions` - List submissions
- `GET /submissions/{id}` - Get submission details
- `POST /submissions` - Create new submission
- `PATCH /submissions/{id}/asm-approve` - ASM approval
- `PATCH /submissions/{id}/asm-reject` - ASM rejection
- `PATCH /submissions/{id}/hq-approve` - HQ approval
- `PATCH /submissions/{id}/hq-reject` - HQ rejection
- `PATCH /submissions/{id}/resubmit` - Resubmit after rejection
- `POST /submissions/{id}/process-async` - Trigger async processing
- `POST /submissions/{id}/approve` - Legacy approve
- `POST /submissions/{id}/reject` - Legacy reject
- `POST /submissions/{id}/request-reupload` - Legacy request reupload

### Documents
- `POST /documents/upload` - Upload document
- `GET /documents/{id}` - Download document

### Hierarchical Structure
- `GET /hierarchical/{id}/structure` - Get campaign structure
- `POST /hierarchical/{packageId}/campaigns` - Create campaign
- `POST /hierarchical/{packageId}/campaigns/{campaignId}/photos` - Upload photos
- `POST /hierarchical/{packageId}/campaigns/{campaignId}/cost-summary` - Upload cost summary
- `POST /hierarchical/{packageId}/campaigns/{campaignId}/activity-summary` - Upload activity summary
- `POST /hierarchical/{packageId}/enquiry-doc` - Upload enquiry document

### Purchase Orders
- `GET /pos` - List purchase orders (with optional `?search=` parameter)
- `GET /pos/states` - Get Indian states list

### Analytics
- `GET /analytics/overview` - Analytics overview
- `GET /analytics/kpis` - KPI dashboard
- `GET /analytics/state-roi` - State ROI data
- `GET /analytics/campaign-breakdown` - Campaign breakdown
- `GET /analytics/quarterly-fap` - Quarterly FAP KPIs (with `?quarter=` and `?year=` parameters)
- `GET /analytics/export` - Export analytics

### Chat
- `GET /chat/history` - Get chat history
- `POST /chat/message` - Send chat message

### Conversational Submission
- `POST /conversation/message` - Send conversation message

### SignalR Hubs
- `/hubs/submission` - Real-time submission updates

---

## Page Count by Role

- **Agency:** 6 pages (Dashboard, Detail, Upload, Document Upload, Conversational, My Submissions)
- **ASM:** 2 pages (Review List, Review Detail)
- **HQ/RA:** 3 pages (Review List, Review Detail, Analytics)
- **All Users:** 3 pages (Login, New Login, Chat)
- **Legacy:** 3 pages (Document Upload, Submission Review, Analytics Dashboard)

**Total:** 16 pages

---

## Notes

1. **Base URL:** All API calls use `http://localhost:5000/api` as the base URL
2. **Authentication:** Most endpoints require JWT token in `Authorization: Bearer {token}` header
3. **Legacy Pages:** Some pages are marked as legacy and may be superseded by newer implementations
4. **State Management:** Pages use either Riverpod (modern) or direct Dio calls (legacy)
5. **SignalR:** Real-time updates are handled via SignalR hub for conversational submissions
6. **File Uploads:** Use `multipart/form-data` with `MultipartFile` for document uploads
7. **Query Parameters:** Some endpoints support optional query parameters for filtering and search

---

*Last Updated: March 17, 2026*
