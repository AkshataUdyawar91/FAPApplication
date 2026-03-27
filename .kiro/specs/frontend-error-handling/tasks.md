# Implementation Plan: Frontend Error Handling

## Overview

Implement a comprehensive, non-blocking error handling system for the Flutter frontend using existing Riverpod/setState state management. The system replaces raw red SnackBars with type-aware branded toasts, preserves data on error, provides retry for transient failures, shows auth dialogs for session expiry, and catches unhandled exceptions globally. Existing state management patterns are kept as-is.

## Tasks

- [x] 1. Create core error handling infrastructure
  - [x] 1.1 ~~Add `flutter_bloc` and `bloc` packages to `pubspec.yaml`, run `flutter pub get`~~ (Skipped — using existing state management)
    - _Requirements: 1.1_

  - [x] 1.2 Create `ErrorPresentation` value object in `frontend/lib/core/error/error_presentation.dart`
    - Define `ErrorPresentation` class with fields: `icon`, `message`, `accentColor`, `backgroundColor`, `isRetryable`
    - Use `const` constructor
    - _Requirements: 2.1–2.7, 3.2_

  - [x] 1.3 Create `ErrorHandler` static mapper in `frontend/lib/core/error/error_handler.dart`
    - Implement `mapFailure(Failure)` returning `ErrorPresentation` per the mapping table in design
    - Implement `show(BuildContext, {Failure, VoidCallback? onRetry})` dispatching toast vs dialog
    - Handle custom message override: if `failure.message` differs from subtype default, use custom message
    - _Requirements: 2.1–2.7_

  - [ ]* 1.4 Write property test: Custom message override (Property 3)
    - **Property 3: Custom message override**
    - **Validates: Requirements 2.7**

  - [ ]* 1.5 Write property test: Retryable failures mapping (Property 5)
    - **Property 5: Retryable failures show retry button**
    - **Validates: Requirements 3.5**

  - [ ]* 1.6 Write property test: WCAG AA contrast ratio (Property 6)
    - **Property 6: WCAG AA contrast ratio**
    - **Validates: Requirements 3.9**

- [x] 2. Create ErrorToast widget and ErrorToastManager
  - [x] 2.1 Create `ErrorToast` widget in `frontend/lib/core/widgets/error_toast.dart`
    - Non-blocking overlay with rounded corners (12dp), left accent border (4dp), shadow
    - Display icon, message, dismiss button (close icon)
    - Conditionally show "Retry" button when `presentation.isRetryable` is true
    - Slide-in animation and fade-out on dismiss
    - _Requirements: 3.1–3.3, 3.5–3.9_

  - [x] 2.2 Create `ErrorToastManager` singleton in `frontend/lib/core/error/error_toast_manager.dart`
    - Queue-based: shows one toast at a time, auto-dismisses after 5 seconds
    - FIFO ordering for rapid consecutive errors
    - `show(BuildContext, ErrorPresentation, {VoidCallback? onRetry})` and `dismiss()` methods
    - _Requirements: 3.4, 3.10_

  - [ ]* 2.3 Write property test: Toast renders ErrorPresentation fields (Property 4)
    - **Property 4: Toast renders ErrorPresentation fields**
    - **Validates: Requirements 3.2**

  - [ ]* 2.4 Write property test: Toast queue processes sequentially (Property 7)
    - **Property 7: Toast queue processes sequentially**
    - **Validates: Requirements 3.10**

- [x] 3. Create ErrorDialog and RetryHandler
  - [x] 3.1 Create `ErrorDialog` in `frontend/lib/core/widgets/error_dialog.dart`
    - Modal dialog for `AuthFailure` with "Sign In" button
    - `barrierDismissible: false`
    - "Sign In" navigates to `/login` and clears auth state
    - Styled with `AppColors.primary` for action button
    - Deduplicate: don't show second dialog if one is already visible
    - _Requirements: 4.1–4.4_

  - [x] 3.2 Create `RetryHandler` utility in `frontend/lib/core/error/retry_handler.dart`
    - `static Future<Either<Failure, T>> execute<T>(Future<Either<Failure, T>> Function() operation)`
    - Executes callback exactly once per call
    - _Requirements: 5.1, 5.2_

  - [ ]* 3.3 Write property test: Retry executes callback exactly once (Property 8)
    - **Property 8: Retry executes callback exactly once**
    - **Validates: Requirements 5.1**

- [x] 4. Checkpoint - Ensure all core widgets and utilities compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Create EmptyStateWidget
  - [x] 5.1 Create `EmptyStateWidget` in `frontend/lib/core/widgets/empty_state_widget.dart`
    - Centered layout with icon, title, message
    - Optional action button (shown only when both `actionLabel` and `onAction` provided)
    - Use `AppColors.textSecondary` for message, `AppColors.primary` for action button
    - _Requirements: 7.1–7.3_

  - [ ]* 5.2 Write property test: Empty state renders all provided fields (Property 11)
    - **Property 11: Empty state renders all provided fields**
    - **Validates: Requirements 7.1**

  - [ ]* 5.3 Write property test: Empty state conditionally shows action button (Property 12)
    - **Property 12: Empty state conditionally shows action button**
    - **Validates: Requirements 7.2**

- [x] 6. Configure GlobalErrorHandler in main.dart
  - [x] 6.1 Create `GlobalErrorHandler` in `frontend/lib/core/error/global_error_handler.dart`
    - `static void init()` configures `FlutterError.onError` and `PlatformDispatcher.instance.onError`
    - Log error details (type, message, stack trace) using `logger` package
    - Debug mode: print full error and stack trace to console
    - Release mode: suppress red error screen, show fallback error widget
    - _Requirements: 6.1–6.5_

  - [x] 6.2 Wire `GlobalErrorHandler.init()` into `frontend/lib/main.dart`
    - Call `GlobalErrorHandler.init()` before `runApp()`
    - Add `WidgetsFlutterBinding.ensureInitialized()` before init
    - _Requirements: 6.1, 6.2_

  - [ ]* 6.3 Write property test: Global handler logs all caught errors (Property 10)
    - **Property 10: Global handler logs all caught errors**
    - **Validates: Requirements 6.3**

- [x] 7. Checkpoint - Ensure global error handler and empty state widget work correctly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Migrate Submission feature to ErrorToast (keep existing state management)
  - [x] 8.1 Migrate `agency_dashboard_page.dart` to use `ErrorToast`
    - Replace red SnackBar error displays with `ErrorHandler.show()` calls
    - Add `_mapExceptionToFailure()` helper for Dio exceptions
    - Show `EmptyStateWidget` when submissions list is empty and no error
    - Keep existing Riverpod/setState state management unchanged
    - _Requirements: 1.1–1.4, 8.2, 5.3_

  - [ ]* 8.3 Write property test: Data preservation on error (Property 1)
    - **Property 1: Data preservation on error**
    - **Validates: Requirements 1.2, 1.4**

  - [ ]* 8.4 Write property test: Error clearing preserves data (Property 2)
    - **Property 2: Error clearing preserves data**
    - **Validates: Requirements 1.3**

  - [ ]* 8.5 Write property test: Retry failure produces new error state (Property 9)
    - **Property 9: Retry failure produces new error state**
    - **Validates: Requirements 5.4**

- [x] 9. Migrate Auth feature to ErrorToast (keep existing state management)
  - [x] 9.1 Migrate `login_page.dart` to use `ErrorToast`
    - Replace red SnackBar error displays with `ErrorHandler.show()` calls
    - Add `_mapExceptionToFailure()` helper for Dio exceptions
    - AuthFailure triggers `ErrorDialog` with "Sign In" flow
    - Keep existing Riverpod/setState state management unchanged
    - _Requirements: 8.1, 4.1–4.3_

- [x] 10. Migrate remaining features to ErrorToast (keep existing state management)
  - [x] 10.1 Migrate Approval pages to use `ErrorToast`
    - Replace red/error SnackBar displays with `ErrorHandler.show()` in ASM review, HQ review, and detail pages
    - Add `_mapExceptionToFailure()` helper (same pattern as agency_dashboard_page)
    - Keep existing Riverpod/setState state management unchanged
    - _Requirements: 8.3_

  - [x] 10.2 Migrate Analytics page to use `ErrorToast`
    - Replace red/error SnackBar displays with `ErrorHandler.show()`
    - Keep existing state management unchanged
    - _Requirements: 8.4_

  - [x] 10.3 Migrate Chat/Assistant pages to use `ErrorToast`
    - Replace red/error SnackBar displays with `ErrorHandler.show()`
    - Keep existing state management unchanged
    - _Requirements: 8.5_

  - [x] 10.4 Migrate Admin pages to use `ErrorToast`
    - Replace red/error SnackBar displays with `ErrorHandler.show()` in SAP logs, supplier PO, dealer master, email logs, enquiry dump, RA/CH mapping pages
    - Keep existing state management unchanged
    - _Requirements: 8.6_

- [x] 11. Checkpoint - Ensure all page migrations compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 12. Final wiring and integration verification
  - [x] 12.1 Verify `ErrorHandler.show()` dispatches `ErrorDialog` for `AuthFailure` and `ErrorToast` for all other failure types across all migrated pages
    - Confirm retry callbacks are wired where applicable
    - Confirm auth dialog "Sign In" navigates to `/login`
    - _Requirements: 2.1–2.6, 3.5, 3.6, 4.1, 4.2_

  - [ ]* 12.2 Write integration tests verifying each migrated page uses `ErrorToast` instead of `SnackBar`
    - Test Login, Submission, Approval, Analytics, Chat, and Admin pages
    - _Requirements: 8.1–8.6_

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document (Properties 1–12)
- The codebase uses Riverpod and direct Dio/setState patterns — all existing state management is kept as-is (no BLoC migration)
- Error handling migration focuses on replacing SnackBar error displays with ErrorHandler.show() (ErrorToast/ErrorDialog)
