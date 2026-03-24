# Rename Plan: ClaimsIQ → FieldIQ

## Scope
Flutter UI, PWA frontend, and backend user-facing strings only. No namespace/project renames.

---

## Flutter App (`frontend/lib/`)

| # | File | Current | New |
|---|------|---------|-----|
| 1 | `lib/main.dart` (line 23) | `title: 'ClaimsIQ'` | `title: 'FieldIQ'` |
| 2 | `lib/features/auth/presentation/pages/new_login_page.dart` (line 126) | `'ClaimsIQ'` | `'FieldIQ'` |
| 3 | `lib/features/assistant/presentation/widgets/assistant_header.dart` (line 29) | `'ClaimsIQ Assistant'` | `'FieldIQ Assistant'` |
| 4 | `lib/features/assistant/presentation/widgets/assistant_chat_panel.dart` (line 2030) | `'ClaimsIQ Assistant'` | `'FieldIQ Assistant'` |
| 5 | `lib/features/admin/presentation/pages/admin_dashboard_page.dart` (line 86) | `'ClaimsIQ — Admin Panel'` | `'FieldIQ — Admin Panel'` |
| 6 | `lib/features/conversational_submission/presentation/widgets/step_progress_bar.dart` (line 7) | `ClaimsIQ brand color` (dartdoc comment) | `FieldIQ brand color` |
| 7 | `lib/features/conversational_submission/presentation/widgets/user_message_bubble.dart` (line 7) | `ClaimsIQ brand color` (dartdoc comment) | `FieldIQ brand color` |

## Flutter Web (`frontend/web/`)

| # | File | Current | New |
|---|------|---------|-----|
| 8 | `web/index.html` | `<title>ClaimsIQ</title>`, meta description, apple-mobile-web-app-title | All → `FieldIQ` |
| 9 | `web/manifest.json` | `"name": "ClaimsIQ"`, `"short_name"`, `"description"` | All → `FieldIQ` |

## Flutter Integration Tests

| # | File | Current | New |
|---|------|---------|-----|
| 10 | `integration_test/create_request_test.dart` (line 47) | `'ClaimsIQ - Integration Test'` | `'FieldIQ - Integration Test'` |

## ~~PWA Frontend (`frontend/claimsiq-pwa/`)~~ — REMOVED (not in use)

## Backend User-Facing Strings (emails, bot messages, API responses)

| # | File | Current | New |
|---|------|---------|-----|
| 16 | `Infrastructure/Services/EmailAgent.cs` (line 27) | `Brand = "ClaimsIQ"` | `Brand = "FieldIQ"` |
| 17 | `Infrastructure/Services/EmailAgent.cs` (line 577, 582) | `"ClaimsIQ System"` fallback name | `"FieldIQ System"` |
| 18 | `Infrastructure/Services/EmailAgent.cs` (line 311) | `"Log in to ClaimsIQ..."` | `"Log in to FieldIQ..."` |
| 19 | `Infrastructure/Services/EmailAgent.cs` (line 363) | `"Thank you for using ClaimsIQ"` | `"Thank you for using FieldIQ"` |

> **Note**: `claimsiq.bajaj.com` URLs in EmailAgent.cs are left unchanged — update when domain is ready.
| 20 | `Infrastructure/Services/NotificationDispatcher.cs` (line 303) | `"ClaimsIQ: New claim..."` subject | `"FieldIQ: New claim..."` |
| 21 | `Infrastructure/Services/Teams/TeamsBotService.cs` (line 71) | `"ClaimsIQ Review Bot"` | `"FieldIQ Review Bot"` |
| 22 | `Infrastructure/Services/Teams/TeamsBotService.cs` (line 1311) | `"Sign in to ClaimsIQ"` | `"Sign in to FieldIQ"` |
| 23 | `Infrastructure/Services/Teams/TeamsBotService.cs` (line 1318) | `"...your ClaimsIQ credentials..."` | `"...your FieldIQ credentials..."` |
| 24 | `Infrastructure/Services/Teams/TeamsBotOptions.cs` (line 31) | Comment: `ClaimsIQ portal` | `FieldIQ portal` |
| 25 | `API/Controllers/AssistantController.cs` (line 131) | `"ClaimsIQ assistant"` | `"FieldIQ assistant"` |
| 26 | `API/Controllers/AssistantController.cs` (line 2245) | `"ClaimsIQ Enquiry Dump..."` | `"FieldIQ Enquiry Dump..."` |
| 27 | `Domain/Enums/NotificationChannel.cs` (lines 11, 16) | `ClaimsIQ` in XML comments | `FieldIQ` |
| 28 | `Infrastructure/Templates/Email/new-submission.html` | All `ClaimsIQ` references | All → `FieldIQ` |
| 29 | `API/templates/email/new-submission.html` | All `ClaimsIQ` references | All → `FieldIQ` |

## Backend Tests

| # | File | Current | New |
|---|------|---------|-----|
| 30 | `Tests/Infrastructure/Teams/TeamsBotServiceTests.cs` (line 91) | `"ClaimsIQ Review Bot"` | `"FieldIQ Review Bot"` |

---

## Out of Scope
- Backend namespace/project names (`BajajDocumentProcessing.*`) — no change
- Database names, connection strings — no change
- `ClaimsIQRequirements.md`, `PENDING_FEATURES.md` — documentation, not runtime
- `appsettings.json` JWT Issuer/Audience — no change

## Total Changes: ~23 locations across ~15 files

---

## ✅ Plan Executed

**Timestamp**: March 23, 2026, Monday

### Files Changed (15 files)

**Flutter App (7 files)**
1. `frontend/lib/main.dart` — app title → `FieldIQ`
2. `frontend/lib/features/auth/presentation/pages/new_login_page.dart` — login header → `FieldIQ`
3. `frontend/lib/features/assistant/presentation/widgets/assistant_header.dart` — `FieldIQ Assistant`
4. `frontend/lib/features/assistant/presentation/widgets/assistant_chat_panel.dart` — `FieldIQ Assistant`
5. `frontend/lib/features/admin/presentation/pages/admin_dashboard_page.dart` — `FieldIQ — Admin Panel`
6. `frontend/lib/features/conversational_submission/presentation/widgets/step_progress_bar.dart` — dartdoc comment
7. `frontend/lib/features/conversational_submission/presentation/widgets/user_message_bubble.dart` — dartdoc comment

**Flutter Web (2 files)**
8. `frontend/web/index.html` — title, meta description, apple-mobile-web-app-title → `FieldIQ`
9. `frontend/web/manifest.json` — name, short_name, description → `FieldIQ`

**Integration Test (1 file)**
10. `frontend/integration_test/create_request_test.dart` — app title → `FieldIQ`

**Backend Services (5 files)**
11. `backend/.../Services/EmailAgent.cs` — Brand constant, fallback name, footer text, HTML comment
12. `backend/.../Services/NotificationDispatcher.cs` — email subject line
13. `backend/.../Services/Teams/TeamsBotService.cs` — bot welcome, login card text, comments
14. `backend/.../Services/Teams/TeamsBotOptions.cs` — XML doc comment
15. `backend/.../Controllers/AssistantController.cs` — greeting message, enquiry dump message

**Backend Domain (1 file)**
16. `backend/.../Domain/Enums/NotificationChannel.cs` — XML doc comments

**Email Templates (2 files)**
17. `backend/.../Infrastructure/Templates/Email/new-submission.html` — all 5 ClaimsIQ references
18. `backend/.../API/templates/email/new-submission.html` — all 5 ClaimsIQ references

**Backend Tests (1 file)**
19. `backend/.../Tests/Infrastructure/Teams/TeamsBotServiceTests.cs` — assertion string

### Not Changed (per plan)
- `claimsiq.bajaj.com` URLs in EmailAgent.cs — deferred until domain is ready
- `frontend/claimsiq-pwa/` — not in use
- Backend namespaces, database names, documentation `.md` files
