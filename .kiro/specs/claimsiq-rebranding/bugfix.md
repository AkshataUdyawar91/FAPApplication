# Bugfix Requirements Document

## Introduction

The application currently displays "Bajaj Document Processing" as the product/app name across various user-facing surfaces — the browser tab title, the PWA manifest, the Flutter app title, email notification signatures, the Teams bot display name, and the fallback route text. The correct product brand name is **ClaimsIQ**. No instance of "Bajaj Document Processing", "FAP Portal", "Field Activation Portal", or any expanded form of "FAP" as a product name should remain visible to end users after this fix.

Note: "Bajaj" as the **company name / logo label** is intentionally preserved wherever it appears (AppBar, desktop top bar branding, etc.) — it identifies the client company, not the product. "FAP-{id}" submission reference numbers (e.g., "FAP-A2B2C3D4") are also preserved as business identifiers. Only the product/application name strings are in scope for rebranding.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN a user opens the app in a browser THEN the system displays "Bajaj Document Processing" in the browser tab title (`<title>` in `frontend/web/index.html`)

1.2 WHEN a user installs the app as a PWA THEN the system shows "Bajaj Document Processing" as the app name and "Bajaj" as the short name (in `frontend/web/manifest.json`)

1.3 WHEN the Flutter app initialises THEN the system sets the OS-level app title to "Bajaj Document Processing" (in `frontend/lib/main.dart` `MaterialApp.title`)

~~1.4 WHEN a user views the mobile AppBar on any page (Agency Dashboard, Agency Submission Detail, ASM Review Detail, HQ Review Detail) THEN the system displays "Bajaj" as the AppBar title~~ *(out of scope — AppBar label "Bajaj" is intentionally preserved)*

1.5 WHEN a user views the desktop top bar on Agency Dashboard or Agency Upload pages THEN the system displays "Bajaj" as the branding label *(this is the company logo label — intentionally preserved)*

1.6 WHEN a user navigates to an unmatched route THEN the system displays "Welcome to Bajaj Document Processing" as the fallback page text

1.7 WHEN the system sends an email notification (submission received, reupload requested, ASM review ready, or any other notification) THEN the email signature reads "Bajaj Document Processing System"

1.8 WHEN the system generates an AI analytics narrative THEN the prompt references "Bajaj Document Processing System" as the product name

1.9 WHEN a user opens the login page THEN the system displays "Marketing Operations Portal" as the subtitle (this is the legacy FAP Portal descriptor that should be updated to reflect ClaimsIQ)

1.10 WHEN any UI text, tooltip, or help text references "FAP Portal", "Field Activation Portal", or similar expanded forms THEN the system displays these legacy product name strings instead of "ClaimsIQ"

1.11 WHEN the API sends HTTP responses THEN the system does NOT include any custom application-name headers (e.g., "X-Application-Name") — this is current behavior and remains unchanged

### Expected Behavior (Correct)

2.1 WHEN a user opens the app in a browser THEN the system SHALL display "ClaimsIQ" in the browser tab title

2.2 WHEN a user installs the app as a PWA THEN the system SHALL show "ClaimsIQ" as both the app name and short name in the manifest

2.3 WHEN the Flutter app initialises THEN the system SHALL set the OS-level app title to "ClaimsIQ"

2.4 WHEN a user views the mobile AppBar on any page THEN the system SHALL CONTINUE TO display "Bajaj" as the AppBar title (intentionally unchanged)

2.5 WHEN a user views the desktop top bar on Agency Dashboard or Agency Upload pages THEN the system SHALL CONTINUE TO display "Bajaj" as the branding/logo label (company name — intentionally unchanged)

2.6 WHEN a user navigates to an unmatched route THEN the system SHALL display "Welcome to ClaimsIQ" as the fallback page text

2.7 WHEN the system sends any email notification THEN the email signature SHALL read "ClaimsIQ"

2.8 WHEN the system generates an AI analytics narrative THEN the prompt SHALL reference "ClaimsIQ" as the product name

2.9 WHEN a user opens the login page THEN the system SHALL display "Claims Intelligence Platform" as the subtitle

2.10 WHEN any UI text, tooltip, or help text would reference "FAP Portal", "Field Activation Portal", or similar expanded forms THEN the system SHALL display "ClaimsIQ" instead

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a submission ID is displayed as a reference number THEN the system SHALL CONTINUE TO format it as "FAP-{id}" (this is a business identifier, not a product brand string)

3.2 WHEN the ASM review page shows action buttons THEN the system SHALL CONTINUE TO display "Approve FAP" and "Reject FAP" labels (these reference the FAP submission document type, not the product name)

3.3 WHEN the agency dashboard table renders THEN the system SHALL CONTINUE TO show the "FAP NUMBER" column header (this is a document type column label, not a product name)

3.4 WHEN any authenticated API call is made THEN the system SHALL CONTINUE TO use the same JWT authentication flow and headers without change

3.5 WHEN the backend namespace or assembly names are referenced in code THEN the system SHALL CONTINUE TO use "BajajDocumentProcessing" as the C# namespace (code identifiers are out of scope — only user-facing strings are being rebranded)

3.6 WHEN email delivery is triggered THEN the system SHALL CONTINUE TO send via the same Azure Communication Services sender address and configuration

3.7 WHEN the Teams bot sends a notification THEN the system SHALL CONTINUE TO deliver the notification payload unchanged — only the display name shown to recipients SHALL change to "ClaimsIQ"

3.8 WHEN any UI surface displays "Bajaj" as a standalone company name or logo label THEN the system SHALL CONTINUE TO display "Bajaj" unchanged (this is the client company name, not the product name)
