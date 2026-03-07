---
inclusion: manual
---

# Prompt Library — Enterprise-Grade Development

Copy, fill in the [brackets], and use. Every prompt enforces the Guidelines.md steering rules and the Definition of Done checklist.

**Golden rule embedded in every prompt**: Do NOT change intended behavior unless you flag it as **[BUG FLAG]** with evidence and proposed safest fix.

**Steering file references used in prompts below**:
- `Guidelines.md` — Cross-cutting rules, Definition of Done, spec-first mandate.
- `dotnet-best-practices.md` — .NET/C# specific rules (backend prompts).
- `flutter-best-practices.md` — Flutter/Dart specific rules (frontend prompts).
- `sql-best-practices.md` — SQL scripts, stored procedures, seed data, query performance.
- `product.md`, `tech.md`, `structure.md` — Non-negotiable project constraints.

---

## 0. Full Codebase Quality Sweep (Principal Engineer Review)

Use this when you need to bring a module or the entire codebase up to bar.

```
You are a Principal Engineer responsible for production-grade quality.

Context:
- Steering docs (product.md, tech.md, structure.md, Guidelines.md) are non-negotiable constraints.
- Backend rules: dotnet-best-practices.md. Frontend rules: flutter-best-practices.md.
- SQL/Database rules: sql-best-practices.md.
- The code compiles and runs but quality is below bar.

Goal: Bring [file/folder/entire codebase] to enterprise-ready quality WITHOUT changing intended behavior unless you explicitly flag a bug.

Process (do not skip steps):

STEP 1 — Quality Gap Report (max 2 pages):
For each finding include: file path, severity (P0 critical / P1 high / P2 medium), recommended fix.
Categories to check:
- Architecture/pattern violations vs steering docs (layer violations, wrong dependency direction, business logic in controllers, domain entities in API responses, missing DI registration).
- Code smells and complexity (methods >40 lines, files >500 lines, duplication, deep nesting, anonymous response objects, missing guard clauses).
- Error handling & edge cases (swallowed exceptions, missing null checks, generic catch blocks, missing CancellationToken, fire-and-forget patterns).
- Security (secrets in code, missing [Authorize], missing ownership checks, open CORS, missing input validation, user enumeration, unsafe deserialization).
- Performance (N+1 queries, missing pagination, synchronous I/O, missing AsNoTracking, missing indexes, unbounded result sets).
- Test gaps (missing unit tests, missing edge case tests, missing property-based tests, missing integration tests).
- Naming/convention inconsistencies vs structure.md naming conventions.
- Missing docs/comments on public APIs.

STEP 2 — Remediation Plan:
- Order findings by: P0 first, then by dependency (foundational changes before dependent ones).
- Each step must be a small, independently mergeable diff.
- Each step includes: what changes, why, files affected, acceptance check (how to verify), rollback note (how to undo if it breaks something).

STEP 3 — Implement step by step:
For EACH step output:
a) What you will change and why (1-2 sentences).
b) Exact files to edit.
c) The code changes.
d) Tests added/updated with rationale.
e) Any doc/comment updates.
f) Verification command (e.g., `dotnet test`, `flutter analyze`).
g) Definition of Done checklist (architecture ✓, readability ✓, error handling ✓, tests ✓, security ✓, maintainability ✓).
```

---

## 1. New Backend Feature (End-to-End)

**Prerequisite**: A spec must exist for this feature (requirements.md → design.md → tasks.md). If no spec exists, run "Create a spec for [feature]" first.

**Rules**: Follow `dotnet-best-practices.md` for all .NET conventions.

```
Implement [feature name]: [one-sentence description].
Spec: .kiro/specs/[feature-name]/ (reference design.md for architecture decisions).

Deliverables (in this order):
1. Interface in Application/Common/Interfaces/ with XML doc comments on every method.
2. Request/Response DTOs in Application/DTOs/ as C# records with DataAnnotations
   ([Required], [MaxLength], [EmailAddress], [Range] as appropriate).
3. Custom domain exceptions if needed (NotFoundException, etc.) in Application/Common/Exceptions/.
4. Implementation in Infrastructure/Services/ with:
   - Constructor injection only. All fields readonly.
   - Structured logging at entry, exit, and error points with CorrelationId.
   - CancellationToken propagated through all async calls.
   - Resilience policies if calling any external service (configure in DependencyInjection.cs).
   - State transition guards if modifying PackageState.
5. Registration in Infrastructure/DependencyInjection.cs with correct lifetime.
6. Controller endpoint in API/Controllers/ that:
   - Uses [Authorize(Roles = "...")] with appropriate role policy.
   - Returns typed DTOs, not anonymous objects.
   - Returns proper HTTP status codes (201 create, 200 success, 400/404/409 as needed).
   - Has zero business logic — delegates entirely to the service.
   - Includes [ProducesResponseType] attributes for Swagger documentation.
   - Validates resource ownership (userId matches resource owner).
7. Unit tests in Tests/ covering: happy path, validation failure, not found,
   forbidden (wrong user), service exception, boundary values.
8. FsCheck property tests if the feature involves numeric calculations or invariants.

Acceptance checks:
- `dotnet build` succeeds with zero warnings.
- `dotnet test` passes all tests including new ones.
- Swagger UI shows the endpoint with correct request/response schemas.

Rollback: Revert the commit. No database migration involved.

Do NOT change any existing behavior. If you find a bug, flag it as [BUG FLAG].
```

---

## 2. New API Endpoint

**Prerequisite**: This endpoint should be defined in a spec's design.md. If it's not part of an existing spec, create one first.

**Rules**: Follow `dotnet-best-practices.md` for all .NET conventions.

```
Add endpoint: [HTTP METHOD] /api/[route]
Purpose: [what it does and who calls it]
Auth: [Authorize(Roles = "[role]")] or [AllowAnonymous]
Request body: [describe fields or "none"]
Response: [describe shape — must be a typed DTO, not anonymous object]

Requirements:
- Request DTO as a C# record with DataAnnotations validation.
- Response DTO as a C# record in Application/DTOs/.
- Validate resource ownership: authenticated user must own or have access to the resource.
- Return 400 for validation errors, 401 for unauthenticated, 403 for unauthorized,
  404 if resource not found, 409 for conflicts.
- Structured logging with correlation ID at entry and exit.
- Unit tests covering: success, not found, forbidden, validation failure, edge cases.
- Controller delegates to a service — zero business logic in the controller.
- [ProducesResponseType] attributes for all possible status codes.

Acceptance: `dotnet build` clean, `dotnet test` green, endpoint visible in Swagger.
Rollback: Revert commit.

Do NOT change existing endpoints or behavior.
```

---

## 3. Bug Fix (Safe, Regression-Tested)

**Prerequisite**: For non-trivial bugs, create a bugfix spec first (Create a spec for [bug description]). The spec will guide root cause analysis and ensure a regression test is written. For trivial one-line fixes, this prompt can be used directly.

**Rules**: For backend bugs, follow `dotnet-best-practices.md`. For frontend bugs, follow `flutter-best-practices.md`.

```
Bug: [describe the incorrect behavior with steps to reproduce]
Expected: [what should happen, cite spec/steering doc if applicable]
Actual: [what happens instead]

Process (do not skip steps):
1. Root cause analysis: Show the problematic code, explain WHY it fails.
2. Impact analysis: List all callers/consumers of the affected code.
3. Write a failing regression test FIRST that reproduces the bug.
4. Apply the MINIMAL fix that corrects the behavior without side effects.
5. Verify the regression test now passes.
6. Verify ALL existing tests still pass (`dotnet test` / `flutter test`).
7. If the fix touches shared code, confirm each caller still behaves correctly.

Acceptance: Regression test fails before fix, passes after. All other tests green.
Rollback: Revert the commit. The regression test documents the bug for future reference.

Do NOT refactor surrounding code. Fix only the bug.
```

---

## 4. Code Review & Hardening (Per-File)

**Rules**: For backend files, follow `dotnet-best-practices.md`. For frontend files, follow `flutter-best-practices.md`.

```
Review [file path] as a principal engineer. Check against Guidelines.md and the relevant language-specific steering file.

Checklist:
- [ ] No dead code, commented-out code, TODO/HACK/FIXME stubs.
- [ ] All public methods have XML doc comments.
- [ ] No methods >40 lines, no files >500 lines.
- [ ] Guard clauses first, happy path last.
- [ ] No anonymous objects in API responses — typed DTOs only.
- [ ] No business logic in controllers.
- [ ] No direct DbContext access in controllers.
- [ ] Domain entities not exposed in API responses.
- [ ] All request DTOs have DataAnnotations validation.
- [ ] CancellationToken propagated through all async calls.
- [ ] Structured logging at service boundaries (entry/exit/error).
- [ ] No swallowed exceptions (empty catch or catch-log-continue without rethrow).
- [ ] No fire-and-forget (Task.Run without await).
- [ ] Security: [Authorize] present, ownership checks, no secrets in code.
- [ ] Performance: AsNoTracking for reads, pagination on lists, no N+1.
- [ ] State transitions validated via guard method.
- [ ] Named constants for magic numbers/strings.

For each issue:
- State: file:line, what's wrong, severity (P0/P1/P2), risk.
- Apply the fix.
- If it's a behavior change, flag as [BUG FLAG] and propose fix separately.

Acceptance: `dotnet build` clean, `dotnet test` green.
```

---

## 5. Refactor (Behavior-Preserving)

**Rules**: For backend, follow `dotnet-best-practices.md`. For frontend, follow `flutter-best-practices.md`.

```
Refactor [class/method] for readability and maintainability.

Rules:
- Do NOT change any observable behavior. Input/output must remain identical.
- Extract methods with descriptive names for complex logic blocks.
- Replace magic numbers/strings with named constants.
- Convert nested if/else to guard clauses (early returns).
- Split files >500 lines. Split methods >40 lines.
- Replace anonymous response objects with typed DTOs.
- Add missing XML doc comments on public methods.
- Add missing structured logging at entry/exit/error points.
- Run existing tests after refactoring to confirm nothing broke.

Output:
- Before/after summary: what changed and why (table format).
- Verification: `dotnet test` / `flutter test` green.
- Rollback: Revert commit. Refactoring is isolated from behavior changes.

If you discover a bug during refactoring, flag it as [BUG FLAG] — do not fix it in the same change. Separate concerns.
```

---

## 6. Add Unit Tests

**Rules**: Follow `dotnet-best-practices.md` for backend tests, `flutter-best-practices.md` for frontend tests.

```
Add unit tests for [class/service] in Tests/[layer]/.

Coverage requirements:
- Happy path: normal inputs produce expected outputs.
- Validation: invalid inputs rejected with correct exception/error types.
- Edge cases: null inputs, empty collections, boundary values (0, max, negative).
- Error paths: external dependency throws — verify logging and error propagation.
- State: if service modifies state, verify before/after state is correct.
- Concurrency: if applicable, verify idempotency (calling twice produces same result).

Standards:
- xUnit + Moq. Mock all external dependencies.
- Test names: `MethodName_Scenario_ExpectedResult`.
- Each test: Arrange / Act / Assert with section comments.
- No test should depend on another test's state (isolated).

If the class has numeric invariants (scores, percentages, amounts), add FsCheck property-based tests in Tests/[layer]/Properties/ that verify the invariant holds for ALL valid inputs (min 200 test cases).

Acceptance: `dotnet test` green, new tests appear in test explorer.
```

---

## 7. Property-Based Tests

**Rules**: Follow `dotnet-best-practices.md` for FsCheck conventions.

```
Add FsCheck property-based tests for [class/method] in Tests/[layer]/Properties/.

Properties to test:
- [invariant: e.g., "confidence score is always between 0 and 100 for any valid input"]
- [invariant: e.g., "weighted sum of component scores equals overall score"]
- [roundtrip: e.g., "serialize then deserialize produces identical DTO"]
- [idempotency: e.g., "calculating score twice produces same result"]

Standards:
- Custom Arb generators for domain types. Constrain inputs to valid ranges.
- Minimum 200 test cases per property.
- Name: `PropertyName_Invariant`.
- Comment linking to the requirement/spec that defines the invariant.

Acceptance: `dotnet test` green, properties pass with 200+ cases.
```

---

## 8. Security Audit

**Rules**: For backend, follow `dotnet-best-practices.md` security section. For frontend, follow `flutter-best-practices.md` security section. For SQL injection and database permissions, follow `sql-best-practices.md`.

```
Security audit [file/folder/endpoint]. Check every item:

[ ] Auth: [Authorize] present with correct roles? [AllowAnonymous] only where intended?
[ ] Ownership: Modifying endpoints verify userId matches resource owner (not just role)?
[ ] Input validation: All DTO properties have DataAnnotations? [ApiController] auto-validates?
[ ] File uploads: Magic byte validation? Size limits at middleware AND controller?
[ ] Secrets: Any hardcoded keys, connection strings, passwords in code or config?
[ ] Injection: All queries parameterized? No string concatenation in queries?
[ ] Error responses: Leak internal details (stack traces, file paths, SQL)?
[ ] Logging: Sensitive data excluded (passwords, tokens, PII)?
[ ] CORS: Restricted to known origins? AllowAnyOrigin only in Development?
[ ] Rate limiting: Applied to auth endpoints (login, refresh)?
[ ] Enumeration: Login returns identical message for "not found" and "wrong password"?
[ ] Deserialization: Untrusted JSON deserialized safely (no type-name handling)?

For each finding:
- Severity: CRITICAL / HIGH / MEDIUM / LOW.
- Attack vector: How could this be exploited?
- Fix: Apply it.
- Rollback: How to undo if the fix breaks something.

Do NOT change business logic. Security fixes only.
Acceptance: `dotnet build` clean, `dotnet test` green, security checklist all ✓.
```

---

## 9. Performance Optimization

**Rules**: Follow `dotnet-best-practices.md` for backend performance (EF Core, caching, async). Follow `sql-best-practices.md` for query optimization, indexing, and pagination.

```
Optimize [endpoint/service/query] for production load.

Investigate and fix:
- N+1 queries → Use Include/ThenInclude or projection.
- Missing pagination → Add page/pageSize (default 20, max 100).
- Synchronous I/O → Replace with async equivalents.
- Missing AsNoTracking → Add for read-only queries.
- Missing indexes → Add in EF Core configuration files.
- Over-fetching → Use Select() projection for list endpoints.
- Missing caching → Add IMemoryCache with TTL for expensive computations.
- Unbounded result sets → Enforce max page size.

For each change: show before/after (query plan or code diff).
Acceptance: Existing tests pass. Response shape unchanged. `dotnet test` green.
Rollback: Revert commit. Performance changes are isolated.

Do NOT change response shapes or behavior.
```

---

## 10. Frontend Feature (Flutter)

**Prerequisite**: A spec must exist for this feature. The design.md should define the UI states, data flow, and API contracts. If no spec exists, create one first.

**Rules**: Follow `flutter-best-practices.md` for all Flutter/Dart conventions.

```
Build [page/widget]: [description of what it shows and does].
Spec: .kiro/specs/[feature-name]/ (reference design.md for UI requirements).

Requirements:
- AppColors and AppTheme exclusively — no inline colors or text styles.
- State management: Riverpod AsyncNotifier for async operations.
- Navigation: go_router — no Navigator.push.
- Data flow: widget → provider → use case → repository → data source. No direct Dio calls.
- Models: use freezed + json_serializable for data classes.
- Handle ALL states:
  - Loading: skeleton loader for content, spinner for actions.
  - Error: user-friendly message + retry button. Log correlation ID.
  - Empty: helpful message with suggested action.
  - Success: render data.
- Interactive elements: minimum 48×48 touch target.
- Disable buttons during API calls (prevent double-tap).
- Confirmation dialog for destructive actions.
- Responsive: mobile (360px), tablet (768px), web (1200px+).
- Widget test covering: renders correctly, loading state, error state, empty state.

Acceptance: `flutter analyze` clean, `flutter test` green, renders on Chrome and mobile.
Rollback: Revert commit. Frontend changes are isolated from backend.
```

---

## 11. Frontend Error Handling & Auth Interceptor

**Rules**: Follow `flutter-best-practices.md` for error handling, Dio interceptors, and secure storage.

```
Add/update error handling for [feature/page].

Dio interceptor requirements:
- 401: Attempt token refresh via AuthService. On success, retry original request.
  On failure, clear stored tokens (flutter_secure_storage), redirect to login.
- 403: Show "Access denied" with back navigation.
- 404: Show "Not found" with back navigation.
- 422: Parse validation errors, show inline on form fields.
- 500: Show "Something went wrong" with retry button. Extract and log correlation ID from response headers.
- Network timeout / no connection: Show "Connection lost" with retry.
- All messages user-friendly. No raw HTTP codes or technical jargon.

Standards:
- Error interceptor registered in dio_client.dart.
- Token storage via flutter_secure_storage (not SharedPreferences).
- Global error boundary via FlutterError.onError + PlatformDispatcher.instance.onError.

Acceptance: `flutter analyze` clean, `flutter test` green.
Rollback: Revert commit.
```

---

## 12. Add Resilience to Service

**Rules**: Follow `dotnet-best-practices.md` for resilience policies and HTTP client configuration.

```
Add resilience policies to [service name] for calls to [external service].

Implementation:
- Retry: 3 attempts, exponential backoff (1s, 2s, 4s) with jitter. Log each retry at WARNING.
- Circuit breaker: Open after 5 consecutive failures, 60s break. Log state changes at WARNING.
- Timeout: [N] seconds per call. Log timeouts at WARNING.
- Configure in DependencyInjection.cs via IHttpClientBuilder.AddPolicyHandler(), NOT inline in service constructor.
- When circuit is open: return graceful degraded response (cached data or descriptive error), not raw 500.
- Unit tests: verify retry count, circuit breaker opens after threshold, timeout triggers.

Acceptance: `dotnet test` green. Service behavior unchanged when external service is healthy.
Rollback: Remove policy registration from DependencyInjection.cs. Service reverts to unprotected calls.

Do NOT change the service's business logic or response shape.
```

---

## 13. Database Migration (Safe)

**Prerequisite**: Schema changes should be defined in a spec's design.md (data model section). For new columns on existing tables, ensure the spec covers default values and migration safety.

**Rules**: Follow `dotnet-best-practices.md` for EF Core migrations and query optimization. Follow `sql-best-practices.md` for raw SQL migrations, seed data, and stored procedures.

```
Add migration for: [describe schema change].

Process:
1. Modify entity in Domain/Entities/ (add property with appropriate type and nullability).
2. Update EF Core configuration in Infrastructure/Persistence/Configurations/:
   - Column constraints (MaxLength, IsRequired, HasDefaultValue).
   - Indexes on foreign keys and frequently queried columns.
   - Relationship configuration (cascade/restrict delete).
3. Update IApplicationDbContext if adding a new DbSet.
4. Update Application/DTOs/ if the field needs to be exposed via API.
5. Update affected services to use the new field.
6. Generate migration: `dotnet ef migrations add [MigrationName] --project src/BajajDocumentProcessing.Infrastructure --startup-project src/BajajDocumentProcessing.API`.
7. Review generated migration SQL: no data loss, no breaking changes.
8. If adding a required column to existing table: provide a default value in migration.

Acceptance: `dotnet ef database update` succeeds. `dotnet test` green. Existing data preserved.
Rollback: `dotnet ef database update [PreviousMigrationName]` to revert.

Do NOT drop or rename existing columns without explicit confirmation.
```

---

## 14. Observability & Logging

**Rules**: Follow `dotnet-best-practices.md` for structured logging and monitoring conventions.

```
Add observability to [service/controller/workflow].

Requirements:
- Correlation ID: generated in middleware, available via scoped service, included in all logs.
- Log at method entry: operation name, key identifiers (packageId, userId, etc.).
- Log at method exit: operation name, result summary, elapsed time (use Stopwatch).
- Log at error: operation name, exception type, message, correlation ID.
- Log levels per Guidelines.md: DEBUG for cache, INFO for operations, WARNING for retries, ERROR for failures.
- Health check: add dependency check to /health/ready if this service depends on an external system.

Do NOT add verbose logging inside loops or for every line. Log at service boundaries and state transitions only.

Acceptance: `dotnet test` green. Logs visible in console with correlation IDs.
Rollback: Revert commit.
```

---

## 15. Workflow / State Machine Change

**Prerequisite**: State machine changes are high-risk. A spec is mandatory. The design.md must include the updated state diagram and transition rules before any code is modified.

**Rules**: Follow `dotnet-best-practices.md` for backend changes, `flutter-best-practices.md` for frontend state display updates.

```
Modify the [workflow/state machine] to: [describe the change].

Requirements:
- Update PackageState enum if adding new states.
- Update state transition guard to allow the new transition path.
- Audit log the new transition (who, when, from-state, to-state).
- Update WorkflowOrchestrator if the processing pipeline changes.
- Update any UI that displays state (frontend status badges, filters).
- Unit test: valid transition succeeds, invalid transition throws.
- Property test: no valid input sequence can reach an illegal state.

Acceptance: `dotnet test` green. State diagram in comments matches implementation.
Rollback: Revert commit. State enum change is backward-compatible (new values only, no renaming).
```

---

## 16. Verify Against Steering Docs

**Rules**: Check against ALL steering docs including `dotnet-best-practices.md` (backend), `flutter-best-practices.md` (frontend), and `sql-best-practices.md` (database/SQL).

```
Audit [file/folder] against ALL steering docs (product.md, tech.md, structure.md, Guidelines.md, dotnet-best-practices.md, flutter-best-practices.md, sql-best-practices.md).

For each violation:
- Cite the specific steering doc rule being violated.
- Show the violating code (file:line).
- Severity: P0 (blocks production) / P1 (should fix before release) / P2 (tech debt).
- Apply the fix if it doesn't change behavior.
- Flag as [BUG FLAG] if fixing requires a behavior change.

Output a compliance checklist:
- [ ] Architecture matches structure.md dependency flow.
- [ ] Tech stack matches tech.md (correct packages, versions, patterns).
- [ ] Naming matches structure.md conventions.
- [ ] Brand colors match tech.md branding constants.
- [ ] Security rules from Guidelines.md all satisfied.
- [ ] Testing standards from Guidelines.md met.
- [ ] Backend code follows dotnet-best-practices.md (if applicable).
- [ ] Frontend code follows flutter-best-practices.md (if applicable).
- [ ] SQL/database code follows sql-best-practices.md (if applicable).

Acceptance: All checklist items ✓. `dotnet test` / `flutter test` green.
```

---

## 17. Quick Operations

```
Run all backend tests and fix any failures without changing intended behavior. For each failure: show the test name, why it fails, and the minimal fix.

Run `flutter analyze` and fix all warnings and errors. Do not change behavior — only fix lint/analysis issues.

Check [file] for compile errors and type issues. Fix them.

Find all TODO, HACK, and FIXME comments in [scope]. For each: implement it properly OR remove it with a one-line justification. Do not leave any behind.

Find all swallowed exceptions (empty catch blocks, catch-log-continue without rethrow) in [scope]. For each: rethrow, return proper error, or add a comment explaining why swallowing is intentional and safe.

Find all fire-and-forget patterns (Task.Run without await, _ = SomeAsync()) in the backend. Replace each with BackgroundService or Channel<T>. Add unit test verifying the background processing is triggered.

Find all anonymous objects returned from controller actions (new { ... }). Replace each with a typed DTO in Application/DTOs/. Do not change the response shape — the DTO must have identical property names.

Find all controllers that access _context (DbContext) directly. Extract the data access into a service method in Infrastructure/Services/. Controller should call the service instead.
```
