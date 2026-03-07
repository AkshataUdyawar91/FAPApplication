---
inclusion: always
---

# .NET API Best Practices

This file supplements Guidelines.md with .NET-specific rules. Where both files cover the same topic, this file provides the deeper detail. Guidelines.md remains the primary authority for cross-cutting concerns.

## Architecture & Design Patterns

### Clean Architecture (reinforces Guidelines.md)

- Dependency flow: Domain → Application → Infrastructure → API (inward dependency only).
- Domain layer: zero external dependencies.
- Use dependency injection for all services — no service locator pattern.
- Keep controllers thin — delegate all business logic to services.
- Keep constructors clean — no work in constructors (no I/O, no computation, no conditional logic). Constructors assign fields only.

### Naming Conventions
- **PascalCase**: Classes, methods, properties, public fields
- **camelCase**: Private fields (with `_` prefix), local variables, parameters
- **Interfaces**: Prefix with `I` (e.g., `IDocumentAgent`)
- **Async methods**: Suffix with `Async` (e.g., `ProcessDocumentAsync`)
- **DTOs**: Suffix with `Request`, `Response`, or `Data`

### RESTful API Conventions

- Use proper HTTP verbs: GET (read), POST (create), PUT (full update), PATCH (partial update), DELETE (remove).
- Use plural nouns for resource names: `/api/documents`, `/api/submissions`.
- Use explicit parameter binding: `[FromBody]`, `[FromQuery]`, `[FromRoute]` on all action parameters.

HTTP status codes (complete reference):
- **200 OK** — Successful GET, PUT, PATCH.
- **201 Created** — Successful POST (include Location header).
- **204 No Content** — Successful DELETE or update with no response body.
- **400 Bad Request** — Validation errors (return structured error list).
- **401 Unauthorized** — Authentication required or token invalid.
- **403 Forbidden** — Authenticated but insufficient permissions.
- **404 Not Found** — Resource doesn't exist.
- **409 Conflict** — State conflict (e.g., duplicate submission).
- **422 Unprocessable Entity** — Semantically invalid request.
- **429 Too Many Requests** — Rate limit exceeded.
- **500 Internal Server Error** — Unexpected server failure (include correlation ID, hide details).

### Request/Response Models

- Use DTOs for all API inputs and outputs — never expose domain entities directly.
- Validate all inputs using DataAnnotations or FluentValidation.
- Return consistent response structures across all endpoints.
- Use `[FromBody]`, `[FromQuery]`, `[FromRoute]` attributes explicitly on all parameters.

## Error Handling (extends Guidelines.md)

### Exception Strategy

- Do NOT use exceptions for normal control flow — exceptions are expensive.
- Use return types (Result pattern or `Either<Error, T>`) for expected error cases (validation failures, not-found, business rule violations).
- Reserve exceptions for truly exceptional situations (infrastructure failures, unrecoverable states).
- Define custom exception types for domain errors: `NotFoundException`, `ValidationException`, `ConflictException`, `ForbiddenException`, `DomainException`.
- Global exception middleware maps exceptions to HTTP status codes — controllers should not have try/catch.

### Monitoring Exceptions

- Monitor exception rates using APM tools (Application Insights or equivalent).
- Set up alerts for critical/error-level exceptions.
- Track exception types and frequencies to identify systemic issues.

## Async/Await (extends Guidelines.md)

- Always use async/await for I/O operations (database, HTTP, file, Azure services).
- Pass `CancellationToken` to ALL async methods — no exceptions.
- Use `HttpContext.RequestAborted` as the cancellation token source in controllers.
- Avoid `async void` — only permitted for event handlers. Everything else returns `Task` or `Task<T>`.
- Never block on async code with `.Wait()`, `.Result`, or `.GetAwaiter().GetResult()`.
- Use `ConfigureAwait(false)` in library/infrastructure code (not needed in ASP.NET Core controllers/middleware).
- Use `ValueTask<T>` for hot paths where the result is often available synchronously (e.g., cache lookups).
- Use `IAsyncEnumerable<T>` for streaming large result sets to avoid loading everything into memory.

## Dependency Injection (extends Guidelines.md)

Register services with correct lifetimes:
- **Transient**: Lightweight, stateless services (validators, mappers).
- **Scoped**: Per-request services (DbContext, services that depend on DbContext, HTTP context-dependent services).
- **Singleton**: Stateless, thread-safe services (configuration wrappers, caching, resilience policies).

Rules:
- Never use service locator pattern — always constructor injection.
- Keep constructors clean — assign fields only, no logic.
- In `BackgroundService` / `IHostedService`: use `IServiceScopeFactory` to create scopes for scoped services. Never capture scoped services directly in a singleton.

## Database & Entity Framework

### DbContext Best Practices

- Register DbContext as Scoped (default and correct).
- Use async methods everywhere: `ToListAsync()`, `FirstOrDefaultAsync()`, `SaveChangesAsync()`.
- Never block on async DB calls with `.Wait()` or `.Result`.
- DbContext is disposed automatically by DI — don't manually dispose.
- Use `AsNoTracking()` for all read-only queries (list endpoints, detail views, reports).
- Don't track entities unnecessarily — detach after read if you won't save changes.

### Query Optimization

- Use LINQ for queries — avoid raw SQL unless there's a measurable performance reason.
- Project to DTOs in queries using `Select()` to reduce data transfer.
- Retrieve only required fields — never SELECT * equivalent.
- Use pagination for all list endpoints: `Skip()`/`Take()` with default page size 20, max 100.
- Add indexes for frequently queried columns in EF Core configuration files.
- Avoid N+1 query patterns — always use `Include()`/`ThenInclude()` for eager loading.
- Use `AsSplitQuery()` for complex includes with multiple collection navigations to avoid cartesian explosion.
- Use compiled queries (`EF.CompileAsyncQuery`) for frequently executed, performance-critical queries.
- Profile queries using EF Core logging (`EnableSensitiveDataLogging` in Development only) or SQL Server Profiler.
- Cancel long-running queries with `CancellationToken`.

### Async Data Access

- Always use async data access APIs (`ToListAsync`, `FirstOrDefaultAsync`, `CountAsync`, etc.).
- Use `IAsyncEnumerable<T>` for streaming large result sets without loading all into memory.
- Never block on async database calls.

### Migrations

- Create migrations with descriptive names: `AddStateLocationToDocumentPackage`, not `Migration1`.
- Review generated migration code before applying — verify no data loss.
- Never modify database schema directly — always use migrations.
- Test migrations on development environment first.
- Keep migrations small and focused — one logical change per migration.
- If adding a required column to an existing table, always provide a default value.
- Document breaking changes in migration commit messages.

## Performance & Scalability

### Caching Strategy

- Cache frequently accessed, rarely changing data (analytics, configuration, lookup tables).
- Use `IMemoryCache` for single-instance deployments.
- Use distributed caching (Redis) for multi-instance deployments.
- Set appropriate cache expiration (TTL) — don't cache indefinitely.
- Invalidate cache when underlying data changes.
- Monitor cache hit rates and adjust strategy.
- Cache at the appropriate layer: service layer for business data, middleware for response caching.

### Hot Path Optimization

- Identify and optimize frequently executed code paths.
- Profile application to find bottlenecks (use BenchmarkDotNet, dotTrace, or PerfView).
- Minimize allocations in hot paths:
  - Use struct types for small, frequently allocated value objects.
  - Use `Span<T>` and `Memory<T>` for performance-critical buffer operations.
  - Use `ArrayPool<T>` for large temporary buffers (avoids Large Object Heap pressure).
  - Use `StringBuilder` for string concatenation in loops.
  - Use `Dictionary<TKey, TValue>` with initial capacity when size is known.
- Avoid LINQ in performance-critical sections — use for loops instead.
- Use `ValueTask<T>` for hot paths where the result is often synchronously available.

### Background Processing

- Use `IHostedService` or `BackgroundService` for long-running tasks.
- Use `Channel<T>` for producer-consumer patterns within the process.
- Use message brokers (Azure Service Bus) for reliable cross-service background processing.
- Never block HTTP requests with long-running operations — return 202 Accepted and process asynchronously.
- In background services, use `IServiceScopeFactory` to create scopes — never capture scoped services directly.

### Memory Management

- Minimize Large Object Heap (LOH) allocations (objects >85KB).
- Use `ArrayPool<T>` for large temporary buffers.
- Dispose `IDisposable` resources properly — use `using` statements or `await using` for async disposables.
- Avoid memory leaks: unsubscribe from events, dispose timers, cancel background tasks on shutdown.
- Use object pooling (`ObjectPool<T>`) for expensive-to-create objects.
- Profile GC performance in production (monitor Gen 2 collections and LOH fragmentation).

### String & Collection Optimization

- Use `StringBuilder` for string concatenation in loops (not `+=`).
- Use `Span<T>` and `ReadOnlySpan<T>` to avoid string allocations in parsing.
- Prefer `List<T>` over `IEnumerable<T>` when count is known (avoids multiple enumeration).
- Initialize `Dictionary<TKey, TValue>` and `List<T>` with expected capacity.
- Use `string.Create()` or interpolated string handlers for complex string building.

## HTTP & Middleware

### HTTP Client Best Practices

- Use `IHttpClientFactory` for ALL HTTP calls — never `new HttpClient()`.
- Configure HttpClient with appropriate timeouts and resilience policies (Polly).
- Reuse HttpClient instances through the factory — it manages connection pooling.
- Use typed clients or named clients registered in `DependencyInjection.cs`.

### HttpContext Rules

- Never store HttpContext in fields — it's not thread-safe and is request-scoped.
- Never access HttpContext across threads — it's scoped to the request.
- Never modify response headers after the response has started writing — it will throw.
- Use `HttpContext.RequestAborted` as the `CancellationToken` in controllers.
- Access HttpContext in services through `IHttpContextAccessor` (registered as Singleton).

### Middleware Development

- Keep middleware lightweight and focused — one concern per middleware.
- Use async methods in middleware (`InvokeAsync`).
- Always call `next(context)` to continue the pipeline (unless intentionally short-circuiting).
- Handle exceptions appropriately — don't let them propagate unhandled.
- Order middleware correctly in the pipeline (auth before authorization, CORS before routing, etc.).
- No blocking operations in middleware.

### JSON Serialization

- Use `System.Text.Json` — not Newtonsoft.Json (better performance, built-in).
- Configure JSON options globally in Program.cs:
  - `PropertyNamingPolicy = JsonNamingPolicy.CamelCase`
  - `DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull`
- Use source generators (`[JsonSerializable]`) for AOT compilation and startup performance.
- Handle null values consistently.
- Use custom `JsonConverter<T>` for complex types (e.g., polymorphic serialization).

## Security (extends Guidelines.md)

### Input & Output Safety

- Always validate and sanitize user inputs at the API boundary.
- Use parameterized queries — never concatenate user input into SQL.
- Handle null ContentLength explicitly on file uploads to avoid security risks.
- Validate file uploads: size limits, allowed types (by magic bytes), content scanning.
- Sanitize error messages — never expose internal paths, SQL, or stack traces.

### HTTP Security Headers

- Enable HSTS (`UseHsts()`) in production.
- Set `X-Frame-Options: DENY` to prevent clickjacking.
- Set `X-Content-Type-Options: nosniff` to prevent MIME sniffing.
- Set `Content-Security-Policy` appropriate to the application.
- Set `Referrer-Policy: strict-origin-when-cross-origin`.
- Remove `Server` header to avoid version disclosure.

### CSRF & CORS

- Implement anti-forgery tokens for state-changing operations from browser forms.
- CORS: restrict to known origins. `AllowAnyOrigin` only in Development (gated by `IsDevelopment()`).

### Rate Limiting

- Apply rate limiting to authentication endpoints (login, refresh, password reset).
- Use ASP.NET Core rate limiting middleware (`AddRateLimiter`).
- Return 429 Too Many Requests with `Retry-After` header.

## Logging & Monitoring (extends Guidelines.md)

### Structured Logging

- Use `ILogger<T>` with message templates — never string interpolation.
- Log levels:
  - **Trace**: Very detailed debugging (disabled in production).
  - **Debug**: Debugging information, cache hits/misses.
  - **Information**: Operation start/complete, state transitions, business events.
  - **Warning**: Retries, circuit breaker changes, degraded operations.
  - **Error**: Failures that affect functionality.
  - **Critical**: System-level failures requiring immediate attention.
- Include correlation IDs in every log entry for request tracing.
- Never log sensitive information: passwords, tokens, API keys, PII.

### Application Monitoring

- Use Application Insights or equivalent APM tool.
- Monitor: API response times, error rates, dependency call durations.
- Set up alerts for: error rate spikes, response time degradation, dependency failures.
- Track custom metrics for business KPIs (submission volume, approval rates, processing times).

## Azure Services Integration

### Azure OpenAI

- Implement retry logic with exponential backoff for all calls.
- Handle rate limiting (HTTP 429) with backoff and retry.
- Cache responses when appropriate (identical prompts with same inputs).
- Monitor token usage and costs.
- Use Semantic Kernel plugin patterns for agent orchestration.

### Azure Blob Storage

- Use SAS tokens for temporary client-side access (not connection strings).
- Use async methods for all storage operations.
- Set appropriate blob access levels (private by default).
- Implement retry policies for transient storage failures.

### Azure Communication Services

- Handle long-running email send operations properly (poll for completion).
- Validate email addresses before sending.
- Implement retry for transient failures.
- Monitor delivery rates and bounce rates.

## Response Optimization

### Compression

- Enable response compression in Program.cs (`AddResponseCompression`).
- Configure Gzip and Brotli compression for appropriate content types (JSON, HTML, CSS, JS).
- Don't compress already-compressed content (images, videos, zip files).

### Caching Headers

- Set `Cache-Control` headers for static and semi-static responses.
- Use `ETag` for conditional requests on detail endpoints.
- Use 304 Not Modified to avoid re-sending unchanged data.

## Hosting & Deployment

### Version Management

- Stay on supported LTS versions of .NET.
- Review breaking changes before upgrading.
- Test thoroughly after framework upgrades.
- Keep NuGet dependencies up to date — monitor security advisories.

### Deployment

- Use CI/CD pipelines for automated builds, tests, and deployments.
- Implement health checks (`/health`, `/health/ready`) for load balancer integration.
- Configure graceful shutdown (`IHostApplicationLifetime`) to complete in-flight requests.
- Use environment-specific configuration (`appsettings.Development.json`, `appsettings.Production.json`).

## Code Review Checklist

Before committing .NET code, verify:

- [ ] Code follows naming conventions (PascalCase classes/methods, _camelCase fields, IPrefix interfaces, Async suffix).
- [ ] All async methods use async/await properly — no `.Wait()` or `.Result`.
- [ ] No synchronous I/O in async code paths.
- [ ] `CancellationToken` propagated through all async calls.
- [ ] Error handling: global middleware handles exceptions, no try/catch in controllers.
- [ ] Exceptions not used for normal control flow.
- [ ] Structured logging with `ILogger<T>` at service boundaries.
- [ ] No sensitive data in logs (passwords, tokens, PII).
- [ ] Input validation via DataAnnotations on all request DTOs.
- [ ] `[Authorize]` with correct roles on all non-public endpoints.
- [ ] Resource ownership verified (not just role check).
- [ ] No hardcoded secrets or configuration values.
- [ ] XML doc comments on all public methods.
- [ ] No compiler warnings.
- [ ] Unit tests written and passing (happy path + edge cases + error paths).
- [ ] Pagination on list endpoints (default 20, max 100).
- [ ] `AsNoTracking()` on read-only queries.
- [ ] N+1 queries avoided (use Include/ThenInclude).
- [ ] `IHttpClientFactory` used for HTTP calls — no `new HttpClient()`.
- [ ] HttpContext not stored in fields or accessed across threads.
- [ ] Response headers not modified after response starts.
- [ ] Background services use `IServiceScopeFactory` for scoped dependencies.
- [ ] `System.Text.Json` used (not Newtonsoft.Json).
- [ ] Typed DTOs returned from controllers (no anonymous objects).
- [ ] State transitions validated via guard method.
- [ ] Files ≤500 lines, methods ≤40 lines, parameters ≤5.
