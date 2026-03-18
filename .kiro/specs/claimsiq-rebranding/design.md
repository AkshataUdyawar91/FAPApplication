# ClaimsIQ Rebranding Bugfix Design

## Overview

The application currently displays incorrect product branding across multiple user-facing surfaces. The product name "Bajaj Document Processing" appears in browser titles, PWA manifests, email signatures, and UI text, when the correct brand name is "ClaimsIQ". Additionally, the login page subtitle displays the legacy descriptor "Marketing Operations Portal" instead of "Claims Intelligence Platform".

This bugfix systematically replaces all user-facing product name strings with the correct ClaimsIQ branding while preserving:
- "Bajaj" as the company name/logo label (intentionally kept)
- "FAP-{id}" submission reference numbers (business identifiers)
- C# namespace identifiers (code-level names, not user-facing)

The fix is a targeted string replacement operation across frontend and backend files, with no architectural changes, no API contract modifications, and no database schema updates.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug - when user-facing text displays "Bajaj Document Processing", "FAP Portal", "Field Activation Portal", or "Marketing Operations Portal" as product names
- **Property (P)**: The desired behavior - all product name references display "ClaimsIQ" and the login subtitle displays "Claims Intelligence Platform"
- **Preservation**: Existing behavior that must remain unchanged - "Bajaj" company branding, "FAP-{id}" submission numbers, C# namespaces, and all functional behavior
- **Product Name**: User-facing application branding (ClaimsIQ) - distinct from company name (Bajaj) and code identifiers (BajajDocumentProcessing namespace)
- **Business Identifier**: Reference numbers like "FAP-{id}" that identify submission documents - these are data values, not branding

## Bug Details

### Bug Condition

The bug manifests when user-facing text displays legacy product name strings instead of the correct "ClaimsIQ" brand. The affected surfaces include browser titles, PWA manifests, Flutter app initialization, email signatures, AI prompts, login page subtitle, and fallback route text. The root cause is hardcoded string literals in configuration files and source code that were never updated after the product rebranding decision.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type UserFacingTextContext
  OUTPUT: boolean
  
  RETURN (input.text CONTAINS "Bajaj Document Processing" 
          OR input.text CONTAINS "FAP Portal"
          OR input.text CONTAINS "Field Activation Portal"
          OR input.text CONTAINS "Marketing Operations Portal")
         AND input.context IN [
           'browser_title', 
           'pwa_manifest', 
           'app_title', 
           'email_signature', 
           'ai_prompt', 
           'login_subtitle', 
           'fallback_route_text',
           'ui_text'
         ]
         AND NOT isBusinessIdentifier(input.text)
         AND NOT isCompanyName(input.text)
         AND NOT isCodeIdentifier(input.text)
END FUNCTION

FUNCTION isBusinessIdentifier(text)
  RETURN text MATCHES "FAP-[A-Z0-9]+"
END FUNCTION

FUNCTION isCompanyName(text)
  RETURN text == "Bajaj" AND context IN ['appbar_title', 'logo_label', 'company_branding']
END FUNCTION

FUNCTION isCodeIdentifier(text)
  RETURN text IN ['BajajDocumentProcessing', 'Bajaj.DocumentProcessing'] 
         AND context == 'namespace_or_assembly'
END FUNCTION
```

### Examples

- **Browser Title**: User opens app → sees "Bajaj Document Processing" in tab → EXPECTED: "ClaimsIQ"
- **PWA Manifest**: User installs PWA → sees "Bajaj Document Processing" as app name → EXPECTED: "ClaimsIQ"
- **Email Signature**: User receives notification → sees "Bajaj Document Processing System" → EXPECTED: "ClaimsIQ"
- **Login Subtitle**: User views login page → sees "Marketing Operations Portal" → EXPECTED: "Claims Intelligence Platform"
- **Fallback Route**: User navigates to invalid URL → sees "Welcome to Bajaj Document Processing" → EXPECTED: "Welcome to ClaimsIQ"
- **Submission ID (Preserved)**: User views submission → sees "FAP-A2B2C3D4" → EXPECTED: "FAP-A2B2C3D4" (unchanged)
- **AppBar Company Name (Preserved)**: User views mobile AppBar → sees "Bajaj" → EXPECTED: "Bajaj" (unchanged)
- **C# Namespace (Preserved)**: Code references `BajajDocumentProcessing.Application` → EXPECTED: unchanged (code identifier)

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- "Bajaj" as standalone company name/logo label in AppBar and desktop top bar must remain unchanged
- "FAP-{id}" submission reference numbers must continue to display with FAP prefix
- "Approve FAP" and "Reject FAP" button labels must remain unchanged (these reference document type)
- "FAP NUMBER" column header must remain unchanged (document type column)
- C# namespace identifiers (`BajajDocumentProcessing.*`) must remain unchanged
- All authentication flows, API contracts, and database schemas must remain unchanged
- Email delivery configuration and sender addresses must remain unchanged
- All functional behavior (submission processing, validation, approval workflows) must remain unchanged

**Scope:**
All inputs that do NOT involve user-facing product name strings should be completely unaffected by this fix. This includes:
- API request/response payloads (no contract changes)
- Database queries and data structures (no schema changes)
- Authentication and authorization logic (no security changes)
- Business logic and workflow orchestration (no functional changes)
- File upload and document processing (no processing changes)

## Hypothesized Root Cause

Based on the bug description, the root cause is straightforward:

1. **Hardcoded String Literals**: The original product name "Bajaj Document Processing" was hardcoded in multiple configuration files and source code files during initial development. When the product was rebranded to "ClaimsIQ", these strings were not systematically updated.

2. **Legacy Descriptor Not Updated**: The login page subtitle "Marketing Operations Portal" is a legacy descriptor from the original "FAP Portal" (Field Activation Portal) branding that predates the ClaimsIQ rebrand.

3. **No Centralized Branding Configuration**: Product name strings are scattered across frontend HTML, manifest files, Flutter code, backend email templates, and AI prompts rather than being defined in a single configuration constant.

4. **Inconsistent Naming Convention**: The codebase uses "Bajaj" in multiple contexts (company name, product name, namespace) without clear distinction, making it difficult to identify which instances should be updated.

## Correctness Properties

Property 1: Bug Condition - Product Name Displays ClaimsIQ

_For any_ user-facing text context where the bug condition holds (displays "Bajaj Document Processing", "FAP Portal", "Field Activation Portal", or "Marketing Operations Portal" as a product name), the fixed application SHALL display "ClaimsIQ" as the product name (or "Claims Intelligence Platform" for the login subtitle).

**Validates: Requirements 2.1, 2.2, 2.3, 2.6, 2.7, 2.8, 2.9, 2.10**

Property 2: Preservation - Non-Product-Name Text Unchanged

_For any_ text that is NOT a user-facing product name (company names, business identifiers, code namespaces, button labels referencing document types), the fixed application SHALL display exactly the same text as the original application, preserving all existing branding distinctions and functional labels.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

## Fix Implementation

### Changes Required

The fix requires string replacements in 7 files across frontend and backend:

**Frontend Files:**

**File**: `frontend/web/index.html`

**Function**: Browser page title

**Specific Changes**:
1. **Browser Title Tag**: Replace `<title>Bajaj Document Processing</title>` with `<title>ClaimsIQ</title>`

---

**File**: `frontend/web/manifest.json`

**Function**: PWA manifest configuration

**Specific Changes**:
1. **PWA App Name**: Replace `"name": "Bajaj Document Processing"` with `"name": "ClaimsIQ"`
2. **PWA Short Name**: Replace `"short_name": "Bajaj"` with `"short_name": "ClaimsIQ"`

---

**File**: `frontend/lib/main.dart`

**Function**: Flutter app initialization

**Specific Changes**:
1. **MaterialApp Title**: Replace `title: 'Bajaj Document Processing'` with `title: 'ClaimsIQ'`

---

**File**: `frontend/lib/core/router/app_router.dart`

**Function**: Fallback route for unmatched URLs

**Specific Changes**:
1. **Fallback Route Text**: Replace `'Welcome to Bajaj Document Processing'` with `'Welcome to ClaimsIQ'`

---

**File**: `frontend/lib/features/auth/presentation/pages/new_login_page.dart`

**Function**: Login page subtitle display

**Specific Changes**:
1. **Login Subtitle**: Replace `'Marketing Operations Portal'` with `'Claims Intelligence Platform'`

---

**Backend Files:**

**File**: `backend/src/BajajDocumentProcessing.Infrastructure/Services/EmailAgent.cs`

**Function**: Email notification signature

**Specific Changes**:
1. **Email Signature**: Replace all instances of `"Bajaj Document Processing System"` in email body templates with `"ClaimsIQ"`
   - Likely in the `SendSubmissionReceivedEmailAsync` method
   - Likely in the `SendReuploadRequestedEmailAsync` method
   - Likely in any other email template methods

---

**File**: `backend/src/BajajDocumentProcessing.Infrastructure/Services/AnalyticsAgent.cs`

**Function**: AI analytics narrative generation

**Specific Changes**:
1. **AI Prompt Product Reference**: Replace `"Bajaj Document Processing System"` with `"ClaimsIQ"` in the system prompt or context provided to Azure OpenAI
   - Likely in the `GenerateNarrativeAsync` method or similar

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code (verify incorrect strings are present), then verify the fix works correctly (correct strings displayed) and preserves existing behavior (non-product-name strings unchanged).

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm that the legacy product name strings are present in the specified files.

**Test Plan**: Manually inspect each file listed in the Fix Implementation section to verify the presence of legacy strings. Run the application and observe the browser title, PWA manifest, login page, and trigger email notifications to confirm the bug manifests in the UI.

**Test Cases**:
1. **Browser Title Test**: Open `frontend/web/index.html` and verify `<title>` contains "Bajaj Document Processing" (will fail on unfixed code)
2. **PWA Manifest Test**: Open `frontend/web/manifest.json` and verify `name` and `short_name` contain "Bajaj Document Processing" and "Bajaj" (will fail on unfixed code)
3. **Flutter App Title Test**: Open `frontend/lib/main.dart` and verify `MaterialApp.title` contains "Bajaj Document Processing" (will fail on unfixed code)
4. **Login Subtitle Test**: Open `frontend/lib/features/auth/presentation/pages/new_login_page.dart` and verify subtitle contains "Marketing Operations Portal" (will fail on unfixed code)
5. **Fallback Route Test**: Open `frontend/lib/core/router/app_router.dart` and verify fallback text contains "Bajaj Document Processing" (will fail on unfixed code)
6. **Email Signature Test**: Open `backend/src/BajajDocumentProcessing.Infrastructure/Services/EmailAgent.cs` and verify email templates contain "Bajaj Document Processing System" (will fail on unfixed code)
7. **AI Prompt Test**: Open `backend/src/BajajDocumentProcessing.Infrastructure/Services/AnalyticsAgent.cs` and verify AI prompt contains "Bajaj Document Processing System" (will fail on unfixed code)

**Expected Counterexamples**:
- All 7 files contain legacy product name strings
- Browser tab displays "Bajaj Document Processing"
- PWA installation shows "Bajaj Document Processing"
- Login page shows "Marketing Operations Portal"
- Email notifications show "Bajaj Document Processing System"

### Fix Checking

**Goal**: Verify that for all user-facing contexts where the bug condition holds, the fixed application displays the correct product name.

**Pseudocode:**
```
FOR ALL context WHERE isBugCondition(context) DO
  text := getDisplayedText_fixed(context)
  ASSERT text == "ClaimsIQ" OR text == "Claims Intelligence Platform"
END FOR
```

**Test Plan**: After applying the fix, manually verify each affected surface displays the correct branding.

**Test Cases**:
1. **Browser Title Verification**: Open app in browser → verify tab title shows "ClaimsIQ"
2. **PWA Manifest Verification**: Install PWA → verify app name shows "ClaimsIQ"
3. **Flutter App Title Verification**: Launch Flutter app → verify OS-level title shows "ClaimsIQ"
4. **Login Subtitle Verification**: Open login page → verify subtitle shows "Claims Intelligence Platform"
5. **Fallback Route Verification**: Navigate to invalid URL → verify text shows "Welcome to ClaimsIQ"
6. **Email Signature Verification**: Trigger email notification → verify signature shows "ClaimsIQ"
7. **AI Prompt Verification**: Generate analytics narrative → verify prompt references "ClaimsIQ"

### Preservation Checking

**Goal**: Verify that for all text that is NOT a user-facing product name, the fixed application displays the same text as the original application.

**Pseudocode:**
```
FOR ALL context WHERE NOT isBugCondition(context) DO
  ASSERT getDisplayedText_original(context) = getDisplayedText_fixed(context)
END FOR
```

**Testing Approach**: Property-based testing is NOT recommended for this bugfix because the preservation scope is well-defined and finite. Manual verification of specific preservation cases is more appropriate.

**Test Plan**: After applying the fix, manually verify that preserved text remains unchanged.

**Test Cases**:
1. **Submission ID Preservation**: View submission detail page → verify submission ID displays as "FAP-{id}" format (e.g., "FAP-A2B2C3D4")
2. **AppBar Company Name Preservation**: View mobile AppBar → verify title displays "Bajaj" (company name)
3. **Desktop Top Bar Preservation**: View desktop dashboard → verify branding label displays "Bajaj" (company logo)
4. **Button Label Preservation**: View ASM review page → verify buttons display "Approve FAP" and "Reject FAP"
5. **Column Header Preservation**: View agency dashboard table → verify column header displays "FAP NUMBER"
6. **Namespace Preservation**: Search codebase for `BajajDocumentProcessing` namespace → verify all namespace declarations unchanged
7. **API Contract Preservation**: Make authenticated API call → verify JWT authentication flow unchanged
8. **Email Delivery Preservation**: Trigger email notification → verify email is delivered successfully via same sender address

### Unit Tests

- No new unit tests required — this is a string replacement bugfix with no logic changes
- Existing unit tests should continue to pass without modification
- If any existing tests assert on product name strings, update those assertions to expect "ClaimsIQ"

### Property-Based Tests

- Not applicable — this bugfix involves deterministic string replacements, not algorithmic logic
- No invariants to test beyond "product name strings display ClaimsIQ"

### Integration Tests

- **Full User Flow Test**: Complete a submission workflow (login → upload → submit → receive email) and verify all user-facing surfaces display correct branding
- **Cross-Surface Consistency Test**: Verify product name is consistent across browser title, PWA manifest, login page, and email notifications
- **Regression Test**: Verify all preserved text (company names, business identifiers, button labels) remains unchanged after fix
