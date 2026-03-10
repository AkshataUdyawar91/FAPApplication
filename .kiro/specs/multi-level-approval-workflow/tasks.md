# Implementation Plan: Multi-Level Approval Workflow

## Overview

Implement the three-tier approval workflow (Agency → ASM → RA) with a centralized `ApprovalWorkflowService`, append-only audit trail via `ApprovalAction` entity, refactored API endpoints, and a vertically bifurcated frontend review detail page. Tasks are ordered: domain entities → infrastructure services → API endpoints → frontend components.

## Tasks

- [x] 1. Add domain entities and enums for approval workflow
  - [x] 1.1 Create `ApprovalActionType` enum in `backend/src/BajajDocumentProcessing.Domain/Enums/ApprovalActionType.cs`
    - Define values: ASMApproved = 1, ASMRejected = 2, RAApproved = 3, RARejected = 4, Resubmitted = 5
    - _Requirements: 1.5, 6.1_

  - [x] 1.2 Create `ApprovalAction` entity in `backend/src/BajajDocumentProcessing.Domain/Entities/ApprovalAction.cs`
    - Properties: PackageId, ActorUserId, ActionType, PreviousState, NewState, Comment, ActionTimestamp
    - Navigation properties: Package (DocumentPackage), ActorUser (User)
    - Inherit from BaseEntity
    - _Requirements: 6.1, 6.4_

  - [x] 1.3 Add `ApprovalActions` navigation property to `DocumentPackage` entity
    - Add `ICollection<ApprovalAction> ApprovalActions` to `backend/src/BajajDocumentProcessing.Domain/Entities/DocumentPackage.cs`
    - _Requirements: 6.1_

  - [x] 1.4 Add new values to `NotificationType` enum in `backend/src/BajajDocumentProcessing.Domain/Enums/NotificationType.cs`
    - Add: RejectedByASM = 6, RejectedByRA = 7, PendingRAReview = 8, Resubmitted = 9
    - _Requirements: 9.1, 9.2, 9.3, 9.5_

- [x] 2. Add EF Core configuration and database migration
  - [x] 2.1 Create EF Core configuration for `ApprovalAction` in `backend/src/BajajDocumentProcessing.Infrastructure/Persistence/Configurations/ApprovalActionConfiguration.cs`
    - Configure FK to DocumentPackages with Restrict delete, FK to Users with Restrict delete
    - Add index on PackageId and composite index on (PackageId, ActionTimestamp)
    - Configure Comment as nvarchar(500) NOT NULL
    - _Requirements: 6.1, 6.2_

  - [x] 2.2 Add `DbSet<ApprovalAction>` to `IApplicationDbContext` and `ApplicationDbContext`
    - Update `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/IApplicationDbContext.cs`
    - Update `backend/src/BajajDocumentProcessing.Infrastructure/Persistence/ApplicationDbContext.cs`
    - _Requirements: 6.1_

  - [x] 2.3 Create EF Core migration for ApprovalAction table
    - Run `dotnet ef migrations add AddApprovalActionTable` from the API project directory
    - Review generated migration for correctness
    - _Requirements: 6.1_

- [x] 3. Checkpoint - Ensure domain and database layer compiles
  - Ensure `dotnet build` succeeds, ask the user if questions arise.

- [x] 4. Create application layer DTOs and interface
  - [x] 4.1 Create `ApprovalWorkflowRequest` DTO in `backend/src/BajajDocumentProcessing.Application/DTOs/Approval/ApprovalWorkflowRequest.cs`
    - Add [Required], [MinLength(3)], [MaxLength(500)] validation on Comment property
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

  - [x] 4.2 Create `ApprovalResultDto` in `backend/src/BajajDocumentProcessing.Application/DTOs/Approval/ApprovalResultDto.cs`
    - Properties: PackageId, NewState, Message
    - _Requirements: 1.2, 1.3_

  - [x] 4.3 Create `ApprovalActionDto` in `backend/src/BajajDocumentProcessing.Application/DTOs/Approval/ApprovalActionDto.cs`
    - Properties: Id, PackageId, ActorName, ActorRole, ActionType, PreviousState, NewState, Comment, ActionTimestamp
    - _Requirements: 6.1, 6.3, 6.4_

  - [x] 4.4 Create `IApprovalWorkflowService` interface in `backend/src/BajajDocumentProcessing.Application/Common/Interfaces/IApprovalWorkflowService.cs`
    - Methods: ASMApproveAsync, ASMRejectAsync, RAApproveAsync, RARejectAsync, ResubmitAsync, GetApprovalHistoryAsync
    - All methods accept CancellationToken
    - _Requirements: 1.5, 2.1–2.6, 3.1–3.6, 4.1–4.6_

- [x] 5. Implement ApprovalWorkflowService
  - [x] 5.1 Create `ApprovalWorkflowService` in `backend/src/BajajDocumentProcessing.Infrastructure/Services/ApprovalWorkflowService.cs`
    - Implement state transition guard method using a dictionary of valid (currentState, actionType) → newState mappings
    - Implement comment validation: trim whitespace, reject if trimmed length < 3
    - Implement role validation: ASM for PendingASMApproval, HQ for PendingHQApproval, original Agency submitter for rejected states
    - Implement ASMApproveAsync: validate role → validate comment → guard transition → update state → record ApprovalAction → notify RA users → SaveChangesAsync
    - Implement ASMRejectAsync: validate role → validate comment → guard transition → update state → record ApprovalAction → notify Agency user → SaveChangesAsync
    - Implement RAApproveAsync: validate role → validate comment → guard transition → update state → record ApprovalAction → notify Agency user → SaveChangesAsync
    - Implement RARejectAsync: validate role → validate comment → guard transition → update state → record ApprovalAction → notify Agency user → SaveChangesAsync
    - Implement ResubmitAsync: validate ownership → validate comment → guard transition → update state → increment ResubmissionCount → record ApprovalAction → notify ASM users → SaveChangesAsync
    - Implement GetApprovalHistoryAsync: query ApprovalActions by PackageId, include ActorUser, order by ActionTimestamp ascending, map to ApprovalActionDto
    - Throw NotFoundException for missing packages, ValidationException for bad comments, ForbiddenException for unauthorized users, ConflictException for invalid state transitions
    - _Requirements: 1.1–1.5, 2.1–2.6, 3.1–3.6, 4.1–4.6, 5.1–5.4, 6.1–6.5, 7.1, 8.1–8.5, 9.1–9.5_

  - [ ]* 5.2 Write property test: Valid state transitions produce correct new state (Property 1)
    - **Property 1: Valid state transitions produce correct new state**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalStateMachineProperties.cs`
    - Use FsCheck to generate all valid (state, action) pairs and verify resulting state matches transition table
    - **Validates: Requirements 1.2, 1.3, 1.5, 2.4, 3.2, 3.4, 4.1, 4.2**

  - [ ]* 5.3 Write property test: Invalid state transitions are rejected (Property 2)
    - **Property 2: Invalid state transitions are rejected with no side effects**
    - Add to `ApprovalStateMachineProperties.cs`
    - Use FsCheck to generate invalid (state, action) pairs and verify ConflictException is thrown, state unchanged
    - **Validates: Requirements 1.4, 1.5**

  - [ ]* 5.4 Write property test: Comment validation (Property 3)
    - **Property 3: Comments shorter than 3 trimmed characters are rejected**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalCommentValidationProperties.cs`
    - Use FsCheck InvalidCommentGenerator for empty, whitespace-only, and < 3 trimmed char strings
    - **Validates: Requirements 2.1, 2.3, 3.1, 3.3, 4.4, 5.1, 5.2, 5.3, 5.4**

  - [ ]* 5.5 Write property test: Successful actions produce correct ApprovalAction records (Property 4)
    - **Property 4: Successful actions produce correct ApprovalAction records**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalActionRecordingProperties.cs`
    - Verify PackageId, ActorUserId, ActionType, PreviousState, NewState, Comment, ActionTimestamp are all correct
    - **Validates: Requirements 2.2, 2.5, 3.2, 3.5, 6.1, 6.4**

  - [ ]* 5.6 Write property test: Unauthorized users cannot perform actions (Property 5)
    - **Property 5: Unauthorized users cannot perform actions and state is unchanged**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalRoleAccessProperties.cs`
    - Use FsCheck to generate users with wrong roles for each state and verify ForbiddenException, no state change
    - **Validates: Requirements 2.6, 3.6, 4.5, 8.1, 8.2, 8.3, 8.4, 8.5**

- [x] 6. Checkpoint - Ensure ApprovalWorkflowService compiles and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement approval history and resubmission properties
  - [ ]* 7.1 Write property test: Approval history is append-only (Property 6)
    - **Property 6: Approval history is append-only**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalHistoryProperties.cs`
    - Verify existing records unchanged after new actions
    - **Validates: Requirements 4.6, 6.2**

  - [ ]* 7.2 Write property test: Approval history ordered by timestamp (Property 7)
    - **Property 7: Approval history is ordered by timestamp ascending**
    - Add to `ApprovalHistoryProperties.cs`
    - Verify consecutive pairs have non-decreasing timestamps
    - **Validates: Requirements 6.3**

  - [ ]* 7.3 Write property test: Replay consistency (Property 8)
    - **Property 8: Replaying approval actions from initial state produces current state**
    - Add to `ApprovalHistoryProperties.cs`
    - Replay all actions from PendingASMApproval and verify final state matches package state
    - **Validates: Requirements 6.5**

  - [ ]* 7.4 Write property test: Resubmission count consistency (Property 9)
    - **Property 9: Resubmission count equals number of Resubmitted actions in history**
    - Create `backend/tests/BajajDocumentProcessing.Tests/Infrastructure/Properties/ApprovalResubmissionProperties.cs`
    - Verify ResubmissionCount == count of Resubmitted ApprovalAction records
    - **Validates: Requirements 4.3, 7.1**

- [x] 8. Register service and refactor API endpoints
  - [x] 8.1 Register `ApprovalWorkflowService` in DI container
    - Add scoped registration in `backend/src/BajajDocumentProcessing.Infrastructure/DependencyInjection.cs`
    - Register `IApprovalWorkflowService` → `ApprovalWorkflowService`
    - _Requirements: 1.1_

  - [x] 8.2 Refactor existing approval endpoints in `SubmissionsController` to delegate to `IApprovalWorkflowService`
    - Inject `IApprovalWorkflowService` into controller constructor
    - Refactor `asm-approve` endpoint: accept `ApprovalWorkflowRequest` body, call `ASMApproveAsync`, return `ApprovalResultDto`
    - Refactor `asm-reject` endpoint: accept `ApprovalWorkflowRequest` body, call `ASMRejectAsync`, return `ApprovalResultDto`
    - Refactor `hq-approve` endpoint (serves as ra-approve): accept `ApprovalWorkflowRequest` body, call `RAApproveAsync`, return `ApprovalResultDto`
    - Refactor `hq-reject` endpoint (serves as ra-reject): accept `ApprovalWorkflowRequest` body, call `RARejectAsync`, return `ApprovalResultDto`
    - _Requirements: 1.2, 1.3, 2.1–2.6, 3.1–3.6, 8.1, 8.2_

  - [x] 8.3 Add resubmit endpoint to `SubmissionsController`
    - Refactor existing `resubmit` endpoint to accept `ApprovalWorkflowRequest` body, call `ResubmitAsync`, return `ApprovalResultDto`
    - Ensure [Authorize(Roles = "Agency")] attribute
    - _Requirements: 4.1–4.5, 8.3, 8.5_

  - [x] 8.4 Add approval-history GET endpoint to `SubmissionsController`
    - Route: `GET /api/submissions/{id}/approval-history`
    - Call `GetApprovalHistoryAsync`, return `List<ApprovalActionDto>`
    - Authorize for all authenticated roles
    - _Requirements: 6.1, 6.3, 6.4, 7.2, 7.3_

  - [ ]* 8.5 Write unit tests for refactored controller endpoints
    - Test correct HTTP status codes (200, 400, 403, 404, 409)
    - Test authorization attributes are present
    - Test response shapes match DTOs
    - _Requirements: 8.1–8.5_

- [x] 9. Checkpoint - Ensure backend compiles and all tests pass
  - Ensure `dotnet build` and `dotnet test` succeed, ask the user if questions arise.

- [x] 10. Create frontend data layer for approval workflow
  - [x] 10.1 Create `ApprovalActionModel` in `frontend/lib/features/approval/data/models/approval_action_model.dart`
    - Properties: id, packageId, actorName, actorRole, actionType, previousState, newState, comment, actionTimestamp
    - Implement `fromJson` factory constructor
    - _Requirements: 6.1, 6.4_

  - [x] 10.2 Update `ApprovalRemoteDataSource` in `frontend/lib/features/approval/data/datasources/approval_remote_datasource.dart`
    - Add methods: `asmApprove(id, comment)`, `asmReject(id, comment)`, `raApprove(id, comment)`, `raReject(id, comment)`, `resubmit(id, comment)`, `getApprovalHistory(id)`
    - Use Dio PATCH for actions, GET for history
    - _Requirements: 2.1, 2.3, 3.1, 3.3, 4.4, 6.3_

  - [x] 10.3 Update `ApprovalRepository` interface and implementation
    - Add corresponding methods to `frontend/lib/features/approval/domain/repositories/approval_repository.dart`
    - Add implementations to `frontend/lib/features/approval/data/repositories/approval_repository_impl.dart`
    - Use Either<Failure, T> pattern for error handling
    - _Requirements: 2.1–2.6, 3.1–3.6, 4.1–4.5_

- [x] 11. Create frontend presentation layer - shared layout and widgets
  - [x] 11.1 Create `BifurcatedReviewLayout` widget in `frontend/lib/features/approval/presentation/widgets/bifurcated_review_layout.dart`
    - Split page into left (~60%) and right (~40%) sections using Row with Expanded
    - Accept leftChild and rightChild widget parameters
    - Responsive: stack vertically on mobile (< 600px)
    - _Requirements: 10.3, 10.10_

  - [x] 11.2 Create `WorkflowStageIndicator` widget in `frontend/lib/features/approval/presentation/widgets/workflow_stage_indicator.dart`
    - Horizontal stepper showing: PendingASMApproval → PendingRAApproval → Approved
    - Distinct colors per state (use AppColors), highlight current stage
    - Show rejected states with red indicator
    - _Requirements: 10.9_

  - [x] 11.3 Create `ApprovalHistoryTimeline` widget in `frontend/lib/features/approval/presentation/widgets/approval_history_timeline.dart`
    - Render ordered list of ApprovalActionModel as vertical timeline
    - Each entry shows: actor name, role badge, action type icon, comment text, formatted timestamp
    - Use distinct colors for approve (green), reject (red), resubmit (orange) actions
    - _Requirements: 10.5, 7.3_

  - [x] 11.4 Create `ApprovalActionPanel` widget in `frontend/lib/features/approval/presentation/widgets/approval_action_panel.dart`
    - Role-aware: show Approve/Reject buttons for ASM and RA, Resubmit button for Agency
    - Mandatory comment TextField with inline validation (min 3 chars after trim)
    - Disable buttons during API call (loading state)
    - Show rejection reason and rejecting reviewer name for Agency view
    - _Requirements: 10.6, 10.7, 10.8, 5.1–5.4_

- [x] 12. Update approval providers and notifier
  - [x] 12.1 Update `ApprovalNotifier` in `frontend/lib/features/approval/presentation/providers/approval_notifier.dart`
    - Add methods: asmApprove, asmReject, raApprove, raReject, resubmit, fetchApprovalHistory
    - Manage loading/error/success states for each action
    - Store approval history list in state
    - _Requirements: 2.1–2.6, 3.1–3.6, 4.1–4.5, 6.3_

  - [x] 12.2 Update `approval_providers.dart` to expose new providers
    - Add provider for approval history
    - _Requirements: 6.3, 7.2, 7.3_

- [x] 13. Refactor review detail pages to use bifurcated layout
  - [x] 13.1 Refactor `ASMReviewDetailPage` to use `BifurcatedReviewLayout`
    - Left section: existing package details, documents list, AI recommendation, confidence scores, validation results, resubmission count
    - Right section: WorkflowStageIndicator, ResubmissionCount badge, ApprovalHistoryTimeline, ApprovalActionPanel (approve/reject)
    - Fetch approval history on page load
    - _Requirements: 10.1, 10.3, 10.4, 10.5, 10.6, 10.9, 10.10_

  - [x] 13.2 Refactor `HQReviewDetailPage` to use `BifurcatedReviewLayout`
    - Left section: same current data as ASM view
    - Right section: WorkflowStageIndicator, ResubmissionCount badge, ApprovalHistoryTimeline, ApprovalActionPanel (approve/reject for RA)
    - Fetch approval history on page load
    - _Requirements: 10.2, 10.3, 10.4, 10.5, 10.6, 10.9, 10.10_

  - [x] 13.3 Create `AgencyReviewDetailPage` in `frontend/lib/features/approval/presentation/pages/agency_review_detail_page.dart`
    - Left section: package details, documents list, AI recommendation, confidence scores, validation results
    - Right section: WorkflowStageIndicator, ApprovalHistoryTimeline, ApprovalActionPanel (resubmit button with comment, shown only when state is RejectedByASM or RejectedByRA)
    - Display rejection reason and rejecting reviewer name prominently
    - _Requirements: 10.3, 10.4, 10.5, 10.7, 10.9, 10.10_

  - [x] 13.4 Update review queue pages to filter by correct states
    - `ASMReviewPage`: filter to PendingASMApproval state only
    - `HQReviewPage`: filter to PendingHQApproval state only
    - _Requirements: 10.1, 10.2_

  - [x] 13.5 Add route for `AgencyReviewDetailPage` in router configuration
    - Register route in `frontend/lib/core/router/` for agency review detail
    - _Requirements: 10.7_

- [x] 14. Checkpoint - Ensure frontend compiles and renders correctly
  - Ensure `flutter analyze` passes, ask the user if questions arise.

- [x] 15. Final integration and wiring
  - [x] 15.1 Wire notification dispatch in `ApprovalWorkflowService` for all state transitions
    - ASM approve → notify RA users (PendingRAReview)
    - ASM reject → notify Agency user (RejectedByASM)
    - RA approve → notify Agency user (Approved)
    - RA reject → notify Agency user (RejectedByRA)
    - Resubmit → notify ASM users (Resubmitted)
    - Notifications are best-effort: catch and log failures, don't roll back approval action
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ]* 15.2 Write unit tests for notification dispatch
    - Verify INotificationAgent called with correct parameters for each transition
    - Verify approval action succeeds even if notification fails
    - _Requirements: 9.1–9.5_

- [x] 16. Final checkpoint - Ensure all tests pass
  - Ensure `dotnet build`, `dotnet test`, and `flutter analyze` all pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- The existing `PendingHQApproval` state serves as `PendingRAApproval` (HQ is the legacy name for RA)
- Backend uses C# / .NET 8, frontend uses Dart / Flutter per tech.md
