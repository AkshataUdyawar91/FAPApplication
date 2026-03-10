# Requirements Document

## Introduction

This feature formalizes the multi-level approval workflow for document submission packages in the Bajaj Document Processing System. Packages follow a three-tier approval chain: Agency → ASM → RA. Rejections at any approval level return the package to the Agency for corrections, and resubmission always restarts from the ASM level. Every approval or rejection action requires a comment and is timestamped, producing a complete audit trail of the approval history.

## Glossary

- **Approval_Workflow_Engine**: The backend service responsible for managing state transitions, enforcing transition rules, and recording approval history for document packages.
- **DocumentPackage**: A submission containing one or more business documents (PO, Invoice, Cost Summary, Activity, Photos) that moves through the approval workflow.
- **Agency_User**: A user with the Agency role who submits document packages and makes corrections after rejections.
- **ASM_Reviewer**: A user with the ASM (Area Sales Manager) role who performs the first level of approval review.
- **RA_Reviewer**: A user with the HQ/RA role who performs the second and final level of approval review.
- **Approval_Action**: A recorded event representing an approval or rejection decision, including the reviewer identity, comment, timestamp, and resulting state transition.
- **Approval_History**: An ordered collection of all Approval_Action records for a given DocumentPackage, forming the complete audit trail.
- **Resubmission**: The act of an Agency_User sending a previously rejected DocumentPackage back into the approval chain after making corrections.

## Requirements

### Requirement 1: Three-Tier Approval State Machine

**User Story:** As a system administrator, I want the approval workflow to enforce a strict three-tier approval chain (Agency → ASM → RA), so that every document package is reviewed at two independent levels before final approval.

#### Acceptance Criteria

1. WHEN a DocumentPackage completes AI processing (recommendation generated), THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to PendingASMApproval.
2. WHEN an ASM_Reviewer approves a DocumentPackage in PendingASMApproval state, THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to PendingRAApproval.
3. WHEN an RA_Reviewer approves a DocumentPackage in PendingRAApproval state, THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to Approved.
4. THE Approval_Workflow_Engine SHALL reject any state transition that does not follow the defined transition rules.
5. THE Approval_Workflow_Engine SHALL permit only the following state transitions for the approval phase:
   - PendingASMApproval → ASMApproved (PendingRAApproval)
   - PendingASMApproval → RejectedByASM
   - PendingRAApproval → Approved
   - PendingRAApproval → RejectedByRA
   - RejectedByASM → PendingASMApproval (via Agency resubmission)
   - RejectedByRA → PendingASMApproval (via Agency resubmission)

### Requirement 2: ASM Approval and Rejection

**User Story:** As an ASM, I want to approve or reject document packages assigned to me with mandatory comments, so that the Agency has clear feedback and the package progresses through the workflow.

#### Acceptance Criteria

1. WHEN an ASM_Reviewer approves a DocumentPackage, THE Approval_Workflow_Engine SHALL require a non-empty comment from the ASM_Reviewer.
2. WHEN an ASM_Reviewer approves a DocumentPackage, THE Approval_Workflow_Engine SHALL record the ASM_Reviewer identity, the comment, and the current UTC timestamp.
3. WHEN an ASM_Reviewer rejects a DocumentPackage, THE Approval_Workflow_Engine SHALL require a non-empty comment from the ASM_Reviewer explaining the rejection reason.
4. WHEN an ASM_Reviewer rejects a DocumentPackage, THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to RejectedByASM.
5. WHEN an ASM_Reviewer rejects a DocumentPackage, THE Approval_Workflow_Engine SHALL record the ASM_Reviewer identity, the rejection comment, and the current UTC timestamp.
6. WHILE a DocumentPackage is in PendingASMApproval state, THE Approval_Workflow_Engine SHALL allow only users with the ASM role to perform approval or rejection actions on the DocumentPackage.

### Requirement 3: RA Approval and Rejection

**User Story:** As an RA reviewer, I want to approve or reject document packages that have passed ASM review with mandatory comments, so that final approval decisions are documented and traceable.

#### Acceptance Criteria

1. WHEN an RA_Reviewer approves a DocumentPackage, THE Approval_Workflow_Engine SHALL require a non-empty comment from the RA_Reviewer.
2. WHEN an RA_Reviewer approves a DocumentPackage, THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to Approved and record the RA_Reviewer identity, the comment, and the current UTC timestamp.
3. WHEN an RA_Reviewer rejects a DocumentPackage, THE Approval_Workflow_Engine SHALL require a non-empty comment from the RA_Reviewer explaining the rejection reason.
4. WHEN an RA_Reviewer rejects a DocumentPackage, THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to RejectedByRA.
5. WHEN an RA_Reviewer rejects a DocumentPackage, THE Approval_Workflow_Engine SHALL record the RA_Reviewer identity, the rejection comment, and the current UTC timestamp.
6. WHILE a DocumentPackage is in PendingRAApproval state, THE Approval_Workflow_Engine SHALL allow only users with the RA role to perform approval or rejection actions on the DocumentPackage.

### Requirement 4: Rejection-Resubmission Loop

**User Story:** As an Agency user, I want to correct and resubmit rejected packages so that they can be re-evaluated through the approval chain starting from ASM.

#### Acceptance Criteria

1. WHEN an Agency_User resubmits a DocumentPackage in RejectedByASM state, THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to PendingASMApproval.
2. WHEN an Agency_User resubmits a DocumentPackage in RejectedByRA state, THE Approval_Workflow_Engine SHALL transition the DocumentPackage state to PendingASMApproval (not directly to PendingRAApproval).
3. WHEN an Agency_User resubmits a DocumentPackage, THE Approval_Workflow_Engine SHALL increment the resubmission count for the DocumentPackage.
4. WHEN an Agency_User resubmits a DocumentPackage, THE Approval_Workflow_Engine SHALL require a non-empty comment describing the changes made.
5. WHILE a DocumentPackage is in RejectedByASM or RejectedByRA state, THE Approval_Workflow_Engine SHALL allow only the Agency_User who originally submitted the DocumentPackage to perform the resubmission action.
6. THE Approval_Workflow_Engine SHALL preserve all previous approval history when a DocumentPackage is resubmitted.

### Requirement 5: Mandatory Comments on All Actions

**User Story:** As a compliance officer, I want every approval, rejection, and resubmission action to include a mandatory comment, so that there is a clear rationale for every decision in the audit trail.

#### Acceptance Criteria

1. THE Approval_Workflow_Engine SHALL reject any approval action that does not include a non-empty comment with a minimum length of 3 characters.
2. THE Approval_Workflow_Engine SHALL reject any rejection action that does not include a non-empty comment with a minimum length of 3 characters.
3. THE Approval_Workflow_Engine SHALL reject any resubmission action that does not include a non-empty comment with a minimum length of 3 characters.
4. IF a comment consists only of whitespace characters, THEN THE Approval_Workflow_Engine SHALL treat the comment as empty and reject the action.

### Requirement 6: Approval History Audit Trail

**User Story:** As an auditor, I want a complete, immutable history of all approval actions for each document package, so that I can trace every decision, who made it, and when.

#### Acceptance Criteria

1. WHEN any approval, rejection, or resubmission action is performed, THE Approval_Workflow_Engine SHALL create an Approval_Action record containing: the DocumentPackage identifier, the acting user identifier, the action type (Approved, Rejected, Resubmitted), the previous state, the new state, the comment, and the UTC timestamp.
2. THE Approval_Workflow_Engine SHALL store Approval_Action records in an append-only manner; existing records SHALL NOT be modified or deleted.
3. WHEN a user requests the approval history for a DocumentPackage, THE Approval_Workflow_Engine SHALL return all Approval_Action records ordered by timestamp ascending.
4. THE Approval_Workflow_Engine SHALL include the reviewer display name and role in each Approval_Action record for readability.
5. FOR ALL DocumentPackages, the sequence of Approval_Action records SHALL be consistent with the defined state transition rules (round-trip property: replaying actions from initial state produces the current state).

### Requirement 7: Resubmission Tracking

**User Story:** As an ASM, I want to see how many times a package has been resubmitted and the history of changes, so that I can assess whether the Agency is addressing feedback adequately.

#### Acceptance Criteria

1. THE Approval_Workflow_Engine SHALL maintain a resubmission count on each DocumentPackage that reflects the total number of times the package has been resubmitted.
2. WHEN an ASM_Reviewer or RA_Reviewer views a DocumentPackage, THE Approval_Workflow_Engine SHALL display the current resubmission count.
3. WHEN an ASM_Reviewer or RA_Reviewer views a DocumentPackage, THE Approval_Workflow_Engine SHALL provide access to the full approval history including all previous rejection reasons and resubmission comments.

### Requirement 8: Role-Based Access Control for Approval Actions

**User Story:** As a security administrator, I want approval actions to be restricted to authorized roles, so that only the correct reviewer can act at each stage of the workflow.

#### Acceptance Criteria

1. THE Approval_Workflow_Engine SHALL allow only ASM_Reviewer users to approve or reject DocumentPackages in PendingASMApproval state.
2. THE Approval_Workflow_Engine SHALL allow only RA_Reviewer users to approve or reject DocumentPackages in PendingRAApproval state.
3. THE Approval_Workflow_Engine SHALL allow only the original Agency_User (the user whose identifier matches the SubmittedByUserId on the DocumentPackage) to resubmit a rejected DocumentPackage.
4. IF a user without the required role attempts an approval action, THEN THE Approval_Workflow_Engine SHALL return an authorization error and SHALL NOT modify the DocumentPackage state.
5. IF an Agency_User who is not the original submitter attempts to resubmit a DocumentPackage, THEN THE Approval_Workflow_Engine SHALL return an authorization error and SHALL NOT modify the DocumentPackage state.

### Requirement 9: Notification on State Transitions

**User Story:** As an Agency user, I want to be notified when my package is approved or rejected at any level, so that I can take timely action on rejections or know when my package is fully approved.

#### Acceptance Criteria

1. WHEN a DocumentPackage transitions to RejectedByASM, THE Approval_Workflow_Engine SHALL send a notification to the Agency_User who submitted the package, including the rejection reason.
2. WHEN a DocumentPackage transitions to RejectedByRA, THE Approval_Workflow_Engine SHALL send a notification to the Agency_User who submitted the package, including the rejection reason.
3. WHEN a DocumentPackage transitions to PendingRAApproval, THE Approval_Workflow_Engine SHALL send a notification to RA_Reviewer users indicating a new package is awaiting their review.
4. WHEN a DocumentPackage transitions to Approved (final), THE Approval_Workflow_Engine SHALL send a notification to the Agency_User who submitted the package confirming final approval.
5. WHEN a DocumentPackage transitions to PendingASMApproval via resubmission, THE Approval_Workflow_Engine SHALL send a notification to ASM_Reviewer users indicating a resubmitted package is awaiting review.

### Requirement 10: Frontend Approval Workflow UI

**User Story:** As a user (Agency, ASM, or RA), I want a clear review detail page with current data on one side and the approval flow on the other, so that I can see all relevant information and the complete approval history at a glance.

#### Acceptance Criteria

1. WHILE an ASM_Reviewer is viewing the review queue, THE Frontend SHALL display only DocumentPackages in PendingASMApproval state.
2. WHILE an RA_Reviewer is viewing the review queue, THE Frontend SHALL display only DocumentPackages in PendingRAApproval state.
3. WHEN an Agency_User, ASM_Reviewer, or RA_Reviewer opens a DocumentPackage review detail page, THE Frontend SHALL display the page vertically bifurcated into two side-by-side sections: Section 1 (left) for current data and Section 2 (right) for the approval flow.
4. THE Frontend SHALL display in Section 1 (left) the following current data: package details, documents list, AI recommendation, confidence scores, validation results, and resubmission count.
5. THE Frontend SHALL display in Section 2 (right) the complete approval history as a timeline showing each action with the actor name, role, action type, comment, and timestamp.
6. WHILE an ASM_Reviewer or RA_Reviewer is viewing the review detail page, THE Frontend SHALL display approve and reject action buttons with a mandatory comment field in Section 2 (right) below the approval history timeline.
7. WHILE an Agency_User is viewing a rejected DocumentPackage review detail page, THE Frontend SHALL display the rejection reason, the rejecting reviewer name, and a resubmit action button with a mandatory comment field in Section 2 (right) below the approval history timeline.
8. WHEN a reviewer or Agency_User initiates an approval, rejection, or resubmission action, THE Frontend SHALL validate that the comment field contains a non-empty value before submitting the action.
9. THE Frontend SHALL display the current workflow stage (PendingASMApproval, PendingRAApproval, Approved, RejectedByASM, RejectedByRA) with distinct visual indicators for each state on the review detail page.
10. THE Frontend SHALL apply the vertically bifurcated layout consistently across the Agency_User, ASM_Reviewer, and RA_Reviewer review detail pages.
