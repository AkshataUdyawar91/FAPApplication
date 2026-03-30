# Requirements Document

## Introduction

The Flutter frontend currently handles errors by displaying basic red SnackBars with raw error message strings. The presentation layer discards the `Failure` type information (ServerFailure, NetworkFailure, AuthFailure, etc.) and stores only a plain `String` in state. There is no global error handler for unhandled exceptions, no reusable error widgets, no retry mechanisms, and no visual differentiation between failure types. This feature introduces a comprehensive, user-friendly error handling system with type-aware non-blocking toast notifications, reusable error components, retry logic, and global exception catching — all styled consistently with the Bajaj brand palette. Errors never block the screen or hide previously loaded data; instead, a pretty toast overlays the content so the user stays in context.

## Glossary

- **Error_Handler**: The centralized service responsible for mapping `Failure` objects to user-facing error presentations (messages, icons, colors, actions).
- **Failure**: The abstract base class (`Failure`) and its subtypes (`ServerFailure`, `NetworkFailure`, `AuthFailure`, `ValidationFailure`, `NotFoundFailure`, `CacheFailure`) defined in `core/error/failures.dart`.
- **Error_Toast**: A styled, non-blocking overlay toast notification displayed at the top or bottom of the screen for all error types, replacing the current red SnackBar pattern. The toast overlays the existing content without hiding or replacing it.
- **Error_Dialog**: A modal dialog widget used only for critical errors that require user acknowledgment (e.g., authentication expiry).
- **Retry_Handler**: A utility that executes a failed async operation again, with optional exponential backoff for network and server failures.
- **Global_Error_Handler**: The configuration of `FlutterError.onError` and `PlatformDispatcher.instance.onError` in `main.dart` to catch unhandled framework and platform exceptions.
- **Error_State**: The portion of a notifier/page state that holds error information to preserve failure type context for the presentation layer.

## Requirements

### Requirement 1: Failure-Aware Error Handling with Data Preservation

**User Story:** As a developer, I want error handling in pages and notifiers to preserve the full `Failure` context and retain previously loaded data when an error occurs, so that the UI remains usable and the presentation layer can render type-specific error toasts.

#### Acceptance Criteria

1. WHEN an error occurs, THE page/notifier SHALL map the exception to an appropriate `Failure` subtype for type-aware error presentation.
2. WHEN a repository call or API call fails, THE page/notifier SHALL retain any previously loaded data from the prior successful state — the user must continue to see the last successfully loaded content.
3. WHEN the error is cleared or dismissed, THE page SHALL keep the existing data intact.
4. THE page/notifier SHALL NOT clear or replace previously loaded data when an error occurs.

### Requirement 2: Centralized Failure-to-UI Mapping

**User Story:** As a developer, I want a single service that maps each `Failure` subtype to a user-friendly message, icon, and color scheme, so that error presentation is consistent across the entire app.

#### Acceptance Criteria

1. THE Error_Handler SHALL map `NetworkFailure` to a Wi-Fi-off icon, the message "No internet connection. Check your network and try again.", and a warning color scheme using `AppColors.pendingText` as the accent.
2. THE Error_Handler SHALL map `ServerFailure` to a cloud-off icon, the message "Something went wrong on our end. Please try again later.", and an error color scheme using `AppColors.rejectedText` as the accent.
3. THE Error_Handler SHALL map `AuthFailure` to a lock icon, the message "Your session has expired. Please sign in again.", and an info color scheme using `AppColors.reviewText` as the accent.
4. THE Error_Handler SHALL map `ValidationFailure` to a warning icon, the message "Please check your input and try again.", and a warning color scheme using `AppColors.pendingText` as the accent.
5. THE Error_Handler SHALL map `NotFoundFailure` to a search-off icon, the message "The requested resource could not be found.", and a neutral color scheme using `AppColors.textSecondary` as the accent.
6. THE Error_Handler SHALL map `CacheFailure` to a storage icon, the message "Local data could not be loaded. Please try again.", and a warning color scheme using `AppColors.pendingText` as the accent.
7. WHEN a `Failure` subtype has a non-empty custom message, THE Error_Handler SHALL use the custom message instead of the default message.

### Requirement 3: Non-Blocking Error Toast Widget

**User Story:** As a user, I want to see a pretty, non-blocking toast notification when an error occurs, so that I understand what went wrong without losing the content I was viewing.

#### Acceptance Criteria

1. WHEN any error occurs, THE Error_Toast SHALL display as an overlay on top of the current screen content without hiding or replacing the underlying page data.
2. THE Error_Toast SHALL display the mapped icon, user-friendly message, and color scheme from the Error_Handler.
3. THE Error_Toast SHALL include a dismiss button (close icon) that removes the toast from view.
4. THE Error_Toast SHALL auto-dismiss after 5 seconds if the user does not interact with it.
5. WHERE the Failure is retryable (NetworkFailure, ServerFailure), THE Error_Toast SHALL display a "Retry" action button inline.
6. WHEN the user taps the "Retry" action button, THE Error_Toast SHALL invoke the provided retry callback.
7. THE Error_Toast SHALL use rounded corners (12dp radius), the mapped accent color as the left border indicator (4dp width), a subtle shadow for elevation, and the corresponding light background color.
8. THE Error_Toast SHALL animate in with a slide-down (from top) or slide-up (from bottom) animation and fade out on dismiss.
9. THE Error_Toast SHALL meet WCAG AA contrast requirements between text and background.
10. WHEN multiple errors occur in quick succession, THE Error_Toast SHALL queue toasts and display them one at a time, dismissing the previous before showing the next.

### Requirement 4: Error Dialog for Critical Errors

**User Story:** As a user, I want to be notified with a dialog when a critical error occurs that requires my attention, so that I can take the appropriate action immediately.

#### Acceptance Criteria

1. WHEN an AuthFailure occurs during an authenticated operation, THE Error_Dialog SHALL display a modal dialog with the auth error message and a "Sign In" action button.
2. WHEN the user taps the "Sign In" button in the Error_Dialog, THE Error_Dialog SHALL navigate the user to the login page and clear the authentication state.
3. THE Error_Dialog SHALL prevent dismissal by tapping outside the dialog (barrierDismissible = false) for AuthFailure errors.
4. THE Error_Dialog SHALL use the Bajaj brand styling with `AppColors.primary` for the action button.

### Requirement 5: Retry Mechanism

**User Story:** As a user, I want failed network and server operations to be retried on demand, so that transient failures do not block my workflow.

#### Acceptance Criteria

1. WHEN the user taps a retry button (on Error_Toast or Error_Dialog), THE Retry_Handler SHALL re-execute the original failed operation exactly once.
2. THE Retry_Handler SHALL accept a `Future Function()` callback representing the operation to retry.
3. WHILE a retry operation is in progress, THE presentation layer SHALL display a loading indicator on the retry button.
4. IF the retry operation fails again, THEN THE presentation layer SHALL display a new Error_Toast with the updated error.

### Requirement 6: Global Error Handler

**User Story:** As a developer, I want unhandled Flutter framework errors and platform exceptions to be caught globally, so that the app never shows a red error screen or crashes silently in production.

#### Acceptance Criteria

1. THE Global_Error_Handler SHALL configure `FlutterError.onError` in `main.dart` to catch unhandled framework errors.
2. THE Global_Error_Handler SHALL configure `PlatformDispatcher.instance.onError` in `main.dart` to catch unhandled platform exceptions.
3. WHEN an unhandled error is caught, THE Global_Error_Handler SHALL log the error details (exception type, message, stack trace) using the `logger` package.
4. WHEN an unhandled error is caught in debug mode, THE Global_Error_Handler SHALL print the full error and stack trace to the console.
5. WHEN an unhandled error is caught in release mode, THE Global_Error_Handler SHALL suppress the default red error screen and display a user-friendly fallback error widget.

### Requirement 7: Empty State Widget

**User Story:** As a user, I want to see a helpful message with a suggested action when a list or page has no data, so that I understand the page is not broken.

#### Acceptance Criteria

1. WHEN a data list is empty and no error has occurred, THE Empty_State widget SHALL display a centered layout with an illustrative icon, a title, and a descriptive message.
2. WHERE an action is applicable (e.g., "Create your first submission"), THE Empty_State widget SHALL display an action button.
3. THE Empty_State widget SHALL use `AppColors.textSecondary` for the message text and `AppColors.primary` for the action button.

### Requirement 8: Consistent Error Presentation Across Existing Pages

**User Story:** As a user, I want all pages in the app to use the same error presentation style, so that the experience feels polished and predictable.

#### Acceptance Criteria

1. THE Login_Page SHALL replace the current red `SnackBar` error display with the Error_Toast widget using the Failure object.
2. THE Submission_Pages (agency dashboard, submission detail) SHALL replace red `SnackBar` error displays with the Error_Toast widget, keeping previously loaded data visible underneath.
3. THE Approval_Pages (ASM review, HQ review) SHALL replace the current `SnackBar` error display with the Error_Toast widget.
4. THE Analytics_Page SHALL replace the current `SnackBar` error display with the Error_Toast widget, keeping previously loaded charts and data visible underneath.
5. THE Chat_Page SHALL replace the current `SnackBar` error display with the Error_Toast widget.
6. THE Admin_Pages (SAP logs, supplier PO, dealer master, email logs, enquiry dump, RA/CH mapping) SHALL replace red `SnackBar` error displays with the Error_Toast widget.
