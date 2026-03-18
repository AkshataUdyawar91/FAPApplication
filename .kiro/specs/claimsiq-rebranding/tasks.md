# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Legacy Product Name Strings Present
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate legacy product name strings exist in user-facing surfaces
  - **Scoped PBT Approach**: Verify concrete legacy strings in specific files (deterministic bug - scope to exact file locations)
  - Test that legacy strings "Bajaj Document Processing", "FAP Portal", "Field Activation Portal", and "Marketing Operations Portal" exist in the 7 identified files
  - Verify browser title contains "Bajaj Document Processing" in `frontend/web/index.html`
  - Verify PWA manifest contains "Bajaj Document Processing" and "Bajaj" in `frontend/web/manifest.json`
  - Verify Flutter app title contains "Bajaj Document Processing" in `frontend/lib/main.dart`
  - Verify login subtitle contains "Marketing Operations Portal" in `frontend/lib/features/auth/presentation/pages/new_login_page.dart`
  - Verify fallback route text contains "Bajaj Document Processing" in `frontend/lib/core/router/app_router.dart`
  - Verify email signature contains "Bajaj Document Processing System" in `backend/src/BajajDocumentProcessing.Infrastructure/Services/EmailAgent.cs`
  - Verify AI prompt contains "Bajaj Document Processing System" in `backend/src/BajajDocumentProcessing.Infrastructure/Services/AnalyticsAgent.cs`
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
  - Document counterexamples found (exact file locations and legacy strings)
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.6, 1.7, 1.8, 1.9_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Product-Name Text Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-product-name text
  - Verify "Bajaj" company name preserved in AppBar titles (mobile pages)
  - Verify "Bajaj" company logo label preserved in desktop top bar
  - Verify "FAP-{id}" submission reference numbers preserved (e.g., "FAP-A2B2C3D4")
  - Verify "Approve FAP" and "Reject FAP" button labels preserved
  - Verify "FAP NUMBER" column header preserved
  - Verify C# namespace "BajajDocumentProcessing" preserved in code
  - Verify API authentication flow unchanged
  - Verify email delivery configuration unchanged
  - Write property-based tests capturing observed behavior patterns from Preservation Requirements
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [ ] 3. Fix for ClaimsIQ rebranding

  - [x] 3.1 Update frontend browser title
    - Open `frontend/web/index.html`
    - Replace `<title>Bajaj Document Processing</title>` with `<title>ClaimsIQ</title>`
    - _Bug_Condition: isBugCondition(input) where input.text = "Bajaj Document Processing" AND input.context = "browser_title"_
    - _Expected_Behavior: Browser title displays "ClaimsIQ"_
    - _Preservation: Company names, business identifiers, code namespaces unchanged_
    - _Requirements: 1.1, 2.1_

  - [x] 3.2 Update PWA manifest
    - Open `frontend/web/manifest.json`
    - Replace `"name": "Bajaj Document Processing"` with `"name": "ClaimsIQ"`
    - Replace `"short_name": "Bajaj"` with `"short_name": "ClaimsIQ"`
    - _Bug_Condition: isBugCondition(input) where input.text = "Bajaj Document Processing" AND input.context = "pwa_manifest"_
    - _Expected_Behavior: PWA manifest displays "ClaimsIQ" for both name and short_name_
    - _Preservation: Company names, business identifiers, code namespaces unchanged_
    - _Requirements: 1.2, 2.2_

  - [x] 3.3 Update Flutter app title
    - Open `frontend/lib/main.dart`
    - Replace `title: 'Bajaj Document Processing'` with `title: 'ClaimsIQ'`
    - _Bug_Condition: isBugCondition(input) where input.text = "Bajaj Document Processing" AND input.context = "app_title"_
    - _Expected_Behavior: Flutter app title displays "ClaimsIQ"_
    - _Preservation: Company names, business identifiers, code namespaces unchanged_
    - _Requirements: 1.3, 2.3_

  - [x] 3.4 Update login page subtitle
    - Open `frontend/lib/features/auth/presentation/pages/new_login_page.dart`
    - Replace `'Marketing Operations Portal'` with `'Claims Intelligence Platform'`
    - _Bug_Condition: isBugCondition(input) where input.text = "Marketing Operations Portal" AND input.context = "login_subtitle"_
    - _Expected_Behavior: Login subtitle displays "Claims Intelligence Platform"_
    - _Preservation: Company names, business identifiers, code namespaces unchanged_
    - _Requirements: 1.9, 2.9_

  - [x] 3.5 Update fallback route text
    - Open `frontend/lib/core/router/app_router.dart`
    - Replace `'Welcome to Bajaj Document Processing'` with `'Welcome to ClaimsIQ'`
    - _Bug_Condition: isBugCondition(input) where input.text = "Bajaj Document Processing" AND input.context = "fallback_route_text"_
    - _Expected_Behavior: Fallback route displays "Welcome to ClaimsIQ"_
    - _Preservation: Company names, business identifiers, code namespaces unchanged_
    - _Requirements: 1.6, 2.6_

  - [x] 3.6 Update email notification signatures
    - Open `backend/src/BajajDocumentProcessing.Infrastructure/Services/EmailAgent.cs`
    - Replace all instances of `"Bajaj Document Processing System"` with `"ClaimsIQ"` in email body templates
    - Check `SendSubmissionReceivedEmailAsync` method
    - Check `SendReuploadRequestedEmailAsync` method
    - Check any other email template methods
    - _Bug_Condition: isBugCondition(input) where input.text = "Bajaj Document Processing System" AND input.context = "email_signature"_
    - _Expected_Behavior: Email signatures display "ClaimsIQ"_
    - _Preservation: Email delivery configuration, sender addresses, authentication unchanged_
    - _Requirements: 1.7, 2.7, 3.6_

  - [x] 3.7 Update AI analytics prompt
    - Open `backend/src/BajajDocumentProcessing.Infrastructure/Services/AnalyticsAgent.cs`
    - Replace `"Bajaj Document Processing System"` with `"ClaimsIQ"` in the system prompt or context provided to Azure OpenAI
    - Check `GenerateNarrativeAsync` method or similar
    - _Bug_Condition: isBugCondition(input) where input.text = "Bajaj Document Processing System" AND input.context = "ai_prompt"_
    - _Expected_Behavior: AI prompt references "ClaimsIQ"_
    - _Preservation: AI service configuration, API contracts unchanged_
    - _Requirements: 1.8, 2.8_

  - [x] 3.8 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - ClaimsIQ Branding Displayed
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - Verify all 7 files now contain correct "ClaimsIQ" branding
    - _Requirements: 2.1, 2.2, 2.3, 2.6, 2.7, 2.8, 2.9, 2.10_

  - [x] 3.9 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Product-Name Text Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm "Bajaj" company name still appears in AppBar and desktop top bar
    - Confirm "FAP-{id}" submission reference numbers unchanged
    - Confirm "Approve FAP", "Reject FAP", "FAP NUMBER" labels unchanged
    - Confirm C# namespace "BajajDocumentProcessing" unchanged
    - Confirm all functional behavior unchanged (authentication, email delivery, API contracts)

- [x] 4. Checkpoint - Ensure all tests pass
  - Run bug condition exploration test - should PASS (confirms fix works)
  - Run preservation tests - should PASS (confirms no regressions)
  - Manually verify browser title shows "ClaimsIQ"
  - Manually verify PWA installation shows "ClaimsIQ"
  - Manually verify login page subtitle shows "Claims Intelligence Platform"
  - Manually verify fallback route shows "Welcome to ClaimsIQ"
  - Trigger email notification and verify signature shows "ClaimsIQ"
  - Generate analytics narrative and verify prompt references "ClaimsIQ"
  - Verify "Bajaj" company branding preserved in AppBar and desktop top bar
  - Verify "FAP-{id}" submission numbers still display correctly
  - Verify button labels and column headers unchanged
  - Ask the user if questions arise
