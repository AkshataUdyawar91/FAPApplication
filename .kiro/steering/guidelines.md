---
inclusion: always
---

# Development Guidelines

## Prime Directive

NEVER change existing behavior unless you explicitly flag it as a bug with evidence (failing test, spec violation, or runtime error). When flagging a bug, state:

1. What the current behavior is.
2. What the correct behavior should be (cite spec or steering doc).
3. The safest minimal fix.
4. Impact radius: list all callers/consumers affected.

Label it **[BUG FLAG]** and wait for confirmation before applying.

## Spec-First Development (Mandatory)

Every feature, enhancement, or non-trivial bugfix MUST go through the spec workflow before any code is written. No exceptions.

**Required sequence**:

1. `requirements.md` — User stories and acceptance criteria, reviewed and approved.
2. `design.md` — Technical design with architecture decisions, data models, and correctness properties, reviewed and approved.
3. `tasks.md` — Implementation plan broken into small, reviewable tasks.
4. Code — Execute tasks in order. Each task is a small, independently verifiable change.

**How to start**: Say "Create a spec for [feature/bugfix description]".

**Rule**: If you are about to write code and no spec exists, stop. Create the spec first.

**Exceptions**: trivial one-line fixes, lint/format fixes, and steering doc updates.

## Definition of Done (every change must pass all gates)

- [ ] **Architecture**: conforms to steering docs; no layer violations.
- [ ] **Readability**: clear names, small functions (≤40 lines), single responsibility, minimal duplication.
- [ ] **Error handling**: consistent strategy; no silent failures; structured logging at boundaries.
- [ ] **Tests**: unit tests for new/changed code + edge cases; not happy-path only.
- [ ] **Security**: no secrets in code; inputs validated; auth enforced; least privilege.
- [ ] **Maintainability**: no cleverness; explicit over implicit; non-obvious decisions documented in code comments.
- [ ] **Existing tests pass**: `dotnet test` and `flutter test` green.

## Code Quality Standards

### General Principles

- Write minimal, clean code. Every line must justify its existence.
- No dead code, commented-out code, or TODO/HACK/FIXME stubs in production paths. If you find one, fix it or remove it.
- No copy-paste duplication — extract shared logic into reusable methods/classes/widgets.
- Follow Single Responsibility Principle: one class/method = one job.
- Prefer composition over inheritance.
- All public methods must have XML doc comments (C#) or dartdoc comments (Dart).
- Name things for what they DO, not what they ARE. Method names = verbs, class names = nouns.
- Every conditional branch must be understandable without reading surrounding code. Extract complex conditions into named booleans or methods.
- Guard clauses first, happy path last. Return early on invalid states instead of nesting.
- No anonymous objects in API responses. Always return typed DTOs defined in `Application/DTOs/`.

### Readability & Debuggability

- Code is read 10x more than written. Optimize for the reader.
- One logical operation per line. No chained ternaries or multi-statement lambdas.
- Group related code with blank lines. Separate: setup → execution → result handling.
- Log at method entry and exit for any operation that crosses a service boundary. Include operation name and key identifiers.
- Every catch block must log the exception with context (what was attempted, with what inputs). Never catch and ignore.
- Use named constants for magic numbers and strings. No literal values in business logic.
- When a method does multiple steps (e.g., workflow orchestration), add a brief inline comment before each step explaining WHAT it does, not HOW.

### Language-Specific Rules

- C# / .NET rules are in `dotnet-best-practices.md`.
- Dart / Flutter rules are in `flutter-best-practices.md`.
- SQL / Database script rules are in `sql-best-practices.md`.

All three files are `inclusion: always` and supplement these guidelines.

## Architecture Rules

Architecture details are in the language-specific steering files:
- Backend (Clean Architecture): see `dotnet-best-practices.md`
- Frontend (Clean Architecture): see `flutter-best-practices.md`

**Cross-cutting architecture rules**:
- One class per file. File name matches class name exactly.
- Use dependency injection for everything — no `new` for services.
- Domain entities never appear in API responses — always map to DTOs.
- No direct API calls from presentation layer — always go through use cases or services.

## State Machine & Workflow Rules

`PackageState` transitions must be validated. The allowed transitions are:

```
Uploaded → Extracting → Validating → Validated → Scoring → Recommending → PendingApproval
Validating → ValidationFailed
PendingApproval → Approved | Rejected | ReuploadRequested
```

- Every state change must go through a guard method that validates the transition is legal.
- Every state change must be audit-logged: who, when, from-state, to-state.
- No direct assignment to `package.State = ...` outside the guard method.

## Security Rules

- Authentication and authorization middleware MUST be enabled in `Program.cs`. Never comment them out.
- No real secrets in source code or `appsettings.json` committed to version control. `appsettings.json` may contain placeholder keys (e.g., `"YOUR_KEY_HERE"`) for development. For production, use environment variables or a secrets manager. (Azure Key Vault integration is deferred — not required at this stage.)
- CORS must restrict origins to known frontend URLs. `AllowAnyOrigin` is permitted ONLY in Development environment, gated by `builder.Environment.IsDevelopment()`.
- Validate file uploads by magic bytes, not just file extension. Enforce size limits at middleware and controller level.
- All user input must be validated at the API boundary (DataAnnotations on DTOs) before reaching business logic.
- Use parameterized queries only — never concatenate user input into SQL or any query language.
- JWT tokens must be validated for issuer, audience, lifetime, and signing key.
- Implement token blacklisting for logout using Redis or distributed cache.
- Never log sensitive data: passwords, tokens, API keys, PII. Mask or omit.
- All endpoints that modify data must verify the authenticated user owns or has permission for that specific resource. Role check alone is insufficient — also check `userId` matches resource owner.
- Rate limit authentication endpoints (login, refresh, password reset). Assumption: use ASP.NET Core rate limiting middleware.
- Return identical error messages for "user not found" and "wrong password" to prevent user enumeration.

## Error Handling

- Use global exception handling middleware — don't scatter try/catch in every controller action.
- Every error response must include a correlation ID for tracing.
- Never expose stack traces, internal paths, or exception details in API responses.
- Define custom exception types in Application layer: `NotFoundException`, `ValidationException`, `ConflictException`, `ForbiddenException`, `DomainException`. Map each to an HTTP status code in the global handler.
- Log errors with structured data: `CorrelationId`, `UserId`, `OperationName`, `ExceptionType`, `Message`.
- Frontend error handling rules are in `flutter-best-practices.md`.

## Resilience

All external service calls (Azure OpenAI, Blob Storage, SAP, ACS, Redis) must have:

- Retry policy with exponential backoff (3 attempts) and jitter.
- Circuit breaker (open after 5 consecutive failures, 60s break duration).
- Timeout policy (configurable per service, default 30s).

- Use Polly or `Microsoft.Extensions.Http.Resilience` for resilience policies.
- Configure policies in `DependencyInjection.cs` via `IHttpClientBuilder.AddPolicyHandler()`, not inline in service constructors.
- Log circuit breaker state changes at WARNING level.
- When a circuit breaker is open, return a graceful degraded response (cached data or descriptive error), not a raw 500.

## Observability

- Every API request must have a correlation ID generated in middleware, propagated through all layers via `IHttpContextAccessor` or a scoped `CorrelationIdService`.

**Log levels** (use consistently):
- **DEBUG**: Cache hits/misses, detailed flow tracing (off in production).
- **INFORMATION**: Operation start/complete, state transitions, business events.
- **WARNING**: Retries, circuit breaker changes, degraded operations, unexpected but handled conditions.
- **ERROR**: Unhandled exceptions, external service failures, data integrity issues.

- Include in every log entry: `CorrelationId`, `UserId` (if authenticated), `OperationName`.
- Health check endpoints: `/health` (liveness), `/health/ready` (dependency checks: DB, Redis, Azure services).

## Data Integrity

- All database writes spanning multiple entities must use explicit transactions (`IDbContextTransaction`).
- **Idempotency**: operations that can be retried (submission processing, email sending) must check for existing results before creating duplicates.
- **Soft delete only**: never hard-delete records. Use `IsDeleted` flag with global query filters.
- **Audit trail**: all state changes on `DocumentPackage` must be logged with who, when, from-state, to-state.
- **Optimistic concurrency**: use `[ConcurrencyCheck]` or `RowVersion` on entities that can be modified concurrently (`DocumentPackage`, `Recommendation`).
- For transaction isolation levels, deadlock handling, and raw SQL transaction patterns, see `sql-best-practices.md`.

## Performance

- Use eager loading (`Include`/`ThenInclude`) to avoid N+1 queries.
- Always paginate list endpoints — never return unbounded result sets. Default page size: 20, max: 100.
- Use async file I/O — never block threads with synchronous reads.
- Cache analytics/dashboard data with TTL and invalidation on data changes.
- Use projection (`Select`) when you don't need full entities — especially on list endpoints.
- Use `AsNoTracking()` for read-only queries.
- Index foreign keys and frequently filtered columns in EF Core configurations.
- For detailed query optimization, indexing strategy, and stored procedure patterns, see `sql-best-practices.md`.

## Testing — per tech.md

- Every new service/feature must include unit tests.
- Use xUnit + Moq for unit tests, FsCheck for property-based tests (backend).
- Property-based tests must validate invariants (e.g., confidence scores in [0, 100], weighted sum equals overall).
- Test names follow: `MethodName_Scenario_ExpectedResult`.
- Mock external dependencies — never call real Azure services in unit tests.
- Every bug fix must include a regression test that reproduces the bug before the fix.
- Test the sad paths: null inputs, empty collections, boundary values (0, max, negative), invalid state transitions.
- Integration tests use in-memory database or test containers — never the real database.
- Frontend testing rules are in `flutter-best-practices.md`.

## UI Quality

Detailed frontend/UI rules are in `flutter-best-practices.md`.

**Cross-cutting UI principles** that apply to any frontend:

- **Loading states**: skeleton loaders for content areas, spinners for actions. Never blank screens.
- **Error states**: user-friendly messages with retry buttons. Never raw error codes.
- **Empty states**: helpful messages with suggested actions. Never blank lists.
- All interactive elements: minimum 48×48 touch targets.
- Text must meet WCAG AA contrast ratios against backgrounds.
- **Forms**: inline validation errors, not just toasts. Disable submit buttons during API calls.
- **Destructive actions** (reject, delete): require confirmation dialog.

## File & Code Organization

- No files over 500 lines — split into smaller, focused files. (Flutter: 300 lines per `flutter-best-practices.md`.)
- No methods over 40 lines — extract helper methods.
- No more than 5 parameters per method — use parameter objects or records.
- Remove all unused imports and dependencies.
- Group file contents: fields → constructor → public methods → private methods.
- Keep related files close: service + its validator + its tests in adjacent directories.
- Inline record types (e.g., `public record RejectSubmissionRequest(string Reason)`) are acceptable for simple request DTOs with ≤3 properties. For anything larger, create a dedicated file in `Application/DTOs/`.
