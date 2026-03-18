# Requirements Document

## Introduction

This feature restructures the role model and approval workflow for the Bajaj Document Processing System. The current system uses `ASM` and `HQ` role names that no longer reflect the business hierarchy. The new model introduces `CircleHead (CH)` and `Regional Approver (RA)` roles with explicit state-based routing, ensures AgencyId is always derived from the authenticated user's identity, replaces PO file upload on the agency form with a PO dropdown sourced from the PO master table, adds an Admin role for master data management, and enforces role-scoped visibility of FAP submissions throughout the system.

The approval workflow becomes: Agency submits → routed to the CircleHead for that state → CH approves → routed to the RA for that state → RA gives final approval.

## Glossary

- **FAP**: Field Activation Package — a `DocumentPackage` submission created by an Agency user.
- **Agency**: An external supplier/agency user who submits FAPs. Identified by `UserRole.Agency`.
- **CircleHead (CH)**: First-level approver, previously called ASM. Identified by `UserRole.CircleHead`. One CH is assigned to one state.
- **RA (Regional Approver)**: Second-level approver, previously called HQ. Identified by `UserRole.RA`. One RA may be assigned to many states.
- **Admin**: A new role that can create, update, and delete master data (states, PO masters, role-state mappings, user accounts). Identified by `UserRole.Admin`.
- **State_CH_RA_Mapping**: A mapping table that links a `StateGstMaster` state to exactly one `CircleHead` user and exactly one `RA` user.
- **PO_Master**: The existing `PO` table used as a master list of Purchase Orders, filtered by the agency derived from the logged-in user.
- **AgencyId**: The `Guid` foreign key on `User.AgencyId` that links an Agency user to their `Agency` record.
- **JWT_Claims**: The set of claims embedded in the JWT token issued at login, including `UserId` and `Role`.
- **Submission_Form**: The Flutter `AgencyUploadPage` used by Agency users to create or edit a FAP.
- **Approval_Router**: The backend service responsible for determining which CH or RA should receive a FAP based on the FAP's `ActivationState`.
- **PackageState**: The enum tracking a FAP's lifecycle state (`Uploaded`, `Extracting`, `Validating`, `PendingCH`, `CHRejected`, `PendingRA`, `RARejected`, `Approved`).

---

## Requirements

### Requirement 1: AgencyId Derived from Authenticated User

**User Story:** As a system, I want the AgencyId on every FAP to be derived from the logged-in user's identity, so that an agency user cannot submit on behalf of another agency.

#### Acceptance Criteria

1. WHEN an Agency user submits a FAP, THE Submission_Form SHALL NOT include an AgencyId field; the backend SHALL resolve AgencyId from `JWT_Claims.UserId → User.AgencyId`.
2. WHEN the backend receives a FAP creation request, THE System SHALL look up the submitting user's `AgencyId` from the `Users` table using the authenticated `UserId` claim.
3. IF the authenticated user has a null `AgencyId`, THEN THE System SHALL return HTTP 403 with the message "User is not linked to an agency".
4. THE System SHALL reject any FAP creation request that includes a client-supplied `AgencyId` that differs from the server-resolved `AgencyId`.

---

### Requirement 2: PO Dropdown Replaces PO File Upload on Submission Form

**User Story:** As an agency user, I want to select a PO from a dropdown list of pre-loaded POs for my agency, so that I do not need to upload a PO file manually during submission.

#### Acceptance Criteria

1. THE Submission_Form SHALL replace the PO file upload card with a PO dropdown selector.
2. WHEN the Submission_Form loads, THE System SHALL call `GET /api/pos` filtered by the agency derived from the authenticated user and populate the dropdown with results.
3. WHEN the user selects a PO from the dropdown, THE Submission_Form SHALL display the selected PO's number, vendor name, and total amount as read-only fields.
4. WHEN the user taps "Next Step" on the Invoice Details step, THE Submission_Form SHALL validate that a PO has been selected; if not, THE Submission_Form SHALL display "Please select a Purchase Order".
5. THE `GET /api/pos` endpoint SHALL return only POs belonging to the agency of the authenticated user, regardless of the user's role claim.
6. IF no POs exist for the agency, THEN THE Submission_Form SHALL display "No Purchase Orders available for your agency" and disable the Next Step button on Step 1.

---

### Requirement 3: State–CircleHead–RA Mapping Table

**User Story:** As an Admin, I want a mapping table that links each state to exactly one CircleHead and one RA, so that the system can automatically route FAPs to the correct approvers.

#### Acceptance Criteria

1. THE System SHALL maintain a `State_CH_RA_Mapping` table with columns: `Id`, `StateGstMasterId` (FK), `CircleHeadUserId` (FK → Users), `RAUserId` (FK → Users), `CreatedAt`, `UpdatedAt`, `IsDeleted`.
2. THE `State_CH_RA_Mapping` table SHALL enforce a unique constraint on `StateGstMasterId` so that one state maps to exactly one CircleHead.
3. WHEN a mapping is created, THE System SHALL validate that `CircleHeadUserId` references a user with `UserRole.CircleHead` and `RAUserId` references a user with `UserRole.RA`; if either validation fails, THE System SHALL return HTTP 400 with a descriptive error.
4. THE System SHALL allow multiple `State_CH_RA_Mapping` rows to share the same `RAUserId`, enabling one RA to cover many states.
5. WHERE the Admin role is active, THE System SHALL expose `GET /api/mappings`, `POST /api/mappings`, `PUT /api/mappings/{id}`, and `DELETE /api/mappings/{id}` endpoints restricted to `UserRole.Admin`.

---

### Requirement 4: Role Renaming — ASM → CircleHead, HQ → RA

**User Story:** As a developer, I want the role names in the codebase to match the business terminology, so that code, API responses, and UI labels are consistent with the new hierarchy.

#### Acceptance Criteria

1. THE `UserRole` enum SHALL rename `ASM = 2` to `CircleHead = 2`, preserving the integer value for backward compatibility with existing database rows.
2. THE `UserRole` enum SHALL rename `HQ` (if present) to `RA`, preserving its integer value; the existing `RA = 3` value SHALL remain unchanged.
3. THE JWT token `role` claim SHALL emit `"CircleHead"` for users previously identified as ASM and `"RA"` for users previously identified as HQ.
4. THE `PackageState` enum SHALL rename `PendingASM` to `PendingCH` and `ASMRejected` to `CHRejected`, preserving integer values.
5. THE System SHALL update all `[Authorize(Roles = "ASM")]` policy attributes to `[Authorize(Roles = "CircleHead")]` across all controllers.
6. THE Flutter frontend SHALL update all role string comparisons from `"ASM"` to `"CircleHead"` and from `"HQ"` to `"RA"`.

---

### Requirement 5: Admin Role for Master Data Management

**User Story:** As an Admin, I want to create and modify master data (states, PO masters, role-state mappings, user accounts), so that I can maintain the reference data the system depends on.

#### Acceptance Criteria

1. THE `UserRole` enum SHALL include `Admin = 4` (already present; this requirement confirms its use).
2. WHEN a request is made to any master-data endpoint, THE System SHALL verify the authenticated user has `UserRole.Admin`; if not, THE System SHALL return HTTP 403.
3. THE System SHALL expose CRUD endpoints for `StateGstMaster` restricted to `UserRole.Admin`: `GET /api/admin/states`, `POST /api/admin/states`, `PUT /api/admin/states/{id}`, `DELETE /api/admin/states/{id}`.
4. THE System SHALL expose CRUD endpoints for PO master records restricted to `UserRole.Admin`: `GET /api/admin/pos`, `POST /api/admin/pos`, `PUT /api/admin/pos/{id}`, `DELETE /api/admin/pos/{id}`.
5. THE System SHALL expose CRUD endpoints for user accounts restricted to `UserRole.Admin`: `GET /api/admin/users`, `POST /api/admin/users`, `PUT /api/admin/users/{id}`, `DELETE /api/admin/users/{id}`.
6. WHEN an Admin creates a user, THE System SHALL accept a `role` field and set `User.Role` accordingly; THE System SHALL hash the provided password using BCrypt before persisting.

---

### Requirement 6: Seed Data for New Roles and Mappings

**User Story:** As a developer, I want sample seed data for CircleHead, RA, and Admin users and their state mappings, so that the system is immediately usable in a development environment.

#### Acceptance Criteria

1. THE `ApplicationDbContextSeed` SHALL include at least one `UserRole.Admin` user with a known hashed password.
2. THE `ApplicationDbContextSeed` SHALL include at least two `UserRole.CircleHead` users, each assigned to at least one distinct Indian state via `State_CH_RA_Mapping`.
3. THE `ApplicationDbContextSeed` SHALL include at least one `UserRole.RA` user assigned to cover the same states as the seeded CircleHeads.
4. THE seed script SHALL be idempotent — re-running it SHALL NOT create duplicate records; it SHALL use `IF NOT EXISTS` or `MERGE` patterns.
5. THE seed data SHALL NOT contain plaintext passwords; all passwords SHALL be BCrypt-hashed strings.

---

### Requirement 7: Role-Based FAP Scoping

**User Story:** As a user, I want to see only the FAPs relevant to my role, so that I am not overwhelmed by submissions outside my responsibility.

#### Acceptance Criteria

1. WHEN an Agency user requests the FAP list, THE System SHALL return only `DocumentPackage` records where `AgencyId` matches the user's resolved `AgencyId`.
2. WHEN a CircleHead user requests the FAP list, THE System SHALL return only `DocumentPackage` records where `ActivationState` matches a state assigned to that CircleHead in `State_CH_RA_Mapping`.
3. WHEN an RA user requests the FAP list, THE System SHALL return only `DocumentPackage` records where `ActivationState` matches any state assigned to that RA in `State_CH_RA_Mapping`.
4. WHEN an Admin user requests the FAP list, THE System SHALL return all `DocumentPackage` records without state or agency filtering.
5. IF a CircleHead or RA user has no entries in `State_CH_RA_Mapping`, THEN THE System SHALL return an empty list and HTTP 200.
6. THE Flutter dashboard pages for CircleHead and RA SHALL call the scoped FAP list endpoint and display only the records returned, without client-side filtering.

---

### Requirement 8: Two-Stage Approval Routing

**User Story:** As an Agency user, I want my submitted FAP to automatically route to the correct CircleHead and then to the correct RA, so that I do not need to manually select approvers.

#### Acceptance Criteria

1. WHEN an Agency user submits a FAP, THE Approval_Router SHALL look up the `State_CH_RA_Mapping` row where `StateGstMasterId` matches the FAP's `ActivationState`.
2. IF no mapping exists for the FAP's `ActivationState`, THEN THE System SHALL return HTTP 422 with the message "No approver mapping found for state: {stateName}".
3. WHEN a mapping is found, THE System SHALL set `DocumentPackage.State` to `PendingCH` and create a `RequestApprovalHistory` record with `Action = Submitted` and `ApproverId = submittingUserId`.
4. WHEN a CircleHead approves a FAP in `PendingCH` state, THE System SHALL set `DocumentPackage.State` to `PendingRA` and create a `RequestApprovalHistory` record with `Action = Approved` and `ApproverId = circleHeadUserId`.
5. WHEN a CircleHead rejects a FAP in `PendingCH` state, THE System SHALL set `DocumentPackage.State` to `CHRejected` and create a `RequestApprovalHistory` record with `Action = Rejected`.
6. WHEN an RA approves a FAP in `PendingRA` state, THE System SHALL set `DocumentPackage.State` to `Approved` and create a `RequestApprovalHistory` record with `Action = Approved` and `ApproverId = raUserId`.
7. WHEN an RA rejects a FAP in `PendingRA` state, THE System SHALL set `DocumentPackage.State` to `RARejected` and create a `RequestApprovalHistory` record with `Action = Rejected`.
8. THE System SHALL validate every `PackageState` transition through a guard method; any invalid transition SHALL return HTTP 409 with the message "Invalid state transition from {currentState} to {targetState}".
9. WHILE a FAP is in `PendingCH` state, THE System SHALL permit only the mapped CircleHead for that FAP's state to approve or reject it; any other user SHALL receive HTTP 403.
10. WHILE a FAP is in `PendingRA` state, THE System SHALL permit only the mapped RA for that FAP's state to approve or reject it; any other user SHALL receive HTTP 403.
