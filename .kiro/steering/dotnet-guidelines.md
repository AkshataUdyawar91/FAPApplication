# .NET API Guidelines & Best Practices

## Architecture & Design Patterns

### Clean Architecture
- Follow the established layer structure: Domain → Application → Infrastructure → API
- Domain layer should have no dependencies on other layers
- Use dependency injection for all services
- Keep controllers thin - delegate business logic to services

### Naming Conventions
- **PascalCase**: Classes, methods, properties, public fields
- **camelCase**: Private fields (with `_` prefix), local variables, parameters
- **Interfaces**: Prefix with `I` (e.g., `IDocumentAgent`)
- **Async methods**: Suffix with `Async` (e.g., `ProcessDocumentAsync`)
- **DTOs**: Suffix with `Request`, `Response`, or `Data`

## Code Quality

### Error Handling
- Always use try-catch blocks in controllers and service methods
- Log errors with appropriate log levels (Error, Warning, Information)
- Return meaningful error messages to clients
- Use custom exception types for domain-specific errors
- Never expose stack traces or sensitive information to clients
- **Do not use exceptions for normal control flow** - exceptions are expensive
- Use return types (Result pattern, Either) for expected error cases
- Reserve exceptions for truly exceptional situations
- Monitor exceptions using observability tools (Application Insights, Sentry)
- Set up alerts for critical exceptions

### Async/Await
- Always use `async`/`await` for I/O operations (database, HTTP calls, file operations)
- Pass `CancellationToken` to all async methods
- Avoid `async void` except for event handlers
- Use `ConfigureAwait(false)` in library code (not needed in ASP.NET Core)

### Dependency Injection
- Register services with appropriate lifetimes:
  - **Transient**: Lightweight, stateless services
  - **Scoped**: Per-request services (DbContext, HTTP context-dependent services)
  - **Singleton**: Stateless, thread-safe services (configuration, caching)
- Avoid service locator pattern - use constructor injection
- Keep constructors clean - don't perform work in constructors

## API Design

### RESTful Conventions
- Use proper HTTP verbs: GET (read), POST (create), PUT (update), PATCH (partial update), DELETE (delete)
- Use plural nouns for resource names: `/api/documents`, `/api/submissions`
- Use HTTP status codes correctly:
  - 200 OK - Successful GET, PUT, PATCH
  - 201 Created - Successful POST
  - 204 No Content - Successful DELETE
  - 400 Bad Request - Validation errors
  - 401 Unauthorized - Authentication required
  - 403 Forbidden - Insufficient permissions
  - 404 Not Found - Resource doesn't exist
  - 500 Internal Server Error - Unexpected errors

### Request/Response Models
- Use DTOs for all API inputs and outputs - never expose domain entities directly
- Validate all inputs using Data Annotations or FluentValidation
- Return consistent response structures
- Use `[FromBody]`, `[FromQuery]`, `[FromRoute]` attributes explicitly

### Security
- Always validate and sanitize user inputs
- Use parameterized queries to prevent SQL injection
- Implement proper authentication and authorization
- Use HTTPS in production
- Store secrets in Azure Key Vault or environment variables, never in code
- Implement rate limiting for public endpoints
- Use CORS policies appropriately
- **Handle null ContentLength explicitly** to avoid security risks
- Validate file uploads (size, type, content)
- Implement CSRF protection for state-changing operations
- Use secure headers (HSTS, X-Frame-Options, CSP)
- Sanitize error messages to prevent information disclosure

## Database & Entity Framework

### DbContext Best Practices
- Register DbContext as Scoped
- Use async methods: `ToListAsync()`, `FirstOrDefaultAsync()`, `SaveChangesAsync()`
- Dispose DbContext properly (handled automatically with DI)
- Use `AsNoTracking()` for read-only queries
- Avoid N+1 queries - use `Include()` and `ThenInclude()` for eager loading
- Use `AsSplitQuery()` for complex includes to avoid cartesian explosion
- Don't track entities unnecessarily

### Query Optimization
- Use LINQ for queries - avoid raw SQL unless necessary
- Project to DTOs in queries to reduce data transfer
- Retrieve only required fields using `Select()`
- Use pagination for large result sets
- Add appropriate indexes for frequently queried columns
- Avoid N+1 query patterns - always use eager loading or explicit loading
- Use compiled queries for frequently executed queries
- Profile queries with SQL Server Profiler or EF Core logging

### Async Data Access
- Always use async data access APIs (`ToListAsync`, `FirstOrDefaultAsync`, etc.)
- Never block on async database calls with `.Wait()` or `.Result`
- Use `IAsyncEnumerable<T>` for streaming large result sets
- Cancel long-running queries with `CancellationToken`

### Migrations
- Create migrations with descriptive names
- Review generated migration code before applying
- Never modify database schema directly - always use migrations
- Test migrations on development environment first
- Keep migrations small and focused
- Document breaking changes in migration comments

## Performance & Scalability

### Caching Strategy
- Cache frequently accessed, rarely changing data strategically
- Use distributed caching (Redis) for multi-instance deployments
- Set appropriate cache expiration times
- Invalidate cache when data changes
- Cache at appropriate layers (in-memory, distributed, CDN)
- Monitor cache hit rates and adjust strategy

### Asynchronous Programming
- Use asynchronous programming throughout the entire call stack
- Always use `async`/`await` - never block with `.Wait()` or `.Result`
- Avoid synchronous I/O operations in async methods
- Use `ConfigureAwait(false)` in library code (not needed in ASP.NET Core)
- Pass `CancellationToken` to all async methods
- Use `ValueTask<T>` for hot paths when appropriate

### Hot Path Optimization
- Identify and optimize frequently executed code paths
- Profile application to find bottlenecks
- Minimize allocations in hot paths
- Use struct types for small, frequently allocated objects
- Consider using `Span<T>` and `Memory<T>` for performance-critical code
- Avoid LINQ in performance-critical sections (use for loops instead)

### Background Processing
- Use `IHostedService` or `BackgroundService` for long-running tasks
- Offload long-running processes to background services
- Use message brokers (Azure Service Bus, RabbitMQ) for reliable background processing
- Don't block HTTP requests with long-running operations
- Avoid capturing scoped services in singleton background services
- Use `IServiceScopeFactory` to create scopes in background services
- Use SignalR for real-time client updates when needed

## Data & Memory Optimization

### Large Dataset Handling
- Implement pagination for large datasets (use Skip/Take or cursor-based pagination)
- Use `IAsyncEnumerable<T>` for streaming large result sets
- Retrieve only required fields (use projections in queries)
- Use `AsNoTracking()` for read-only queries
- Avoid loading entire collections into memory

### Memory Management
- Minimize Large Object Heap (LOH) allocations (objects >85KB)
- Use `ArrayPool<T>` for large temporary buffers
- Dispose IDisposable resources properly (use `using` statements)
- Avoid memory leaks - unsubscribe from events
- Use object pooling for expensive objects (HttpClient, database connections)
- Profile GC performance regularly with tools like dotMemory or PerfView
- Monitor Gen 2 collections and LOH fragmentation
- Use weak references when appropriate

### String and Collection Optimization
- Use `StringBuilder` for string concatenation in loops
- Use `Span<T>` and `ReadOnlySpan<T>` to avoid allocations
- Prefer `List<T>` over `IEnumerable<T>` when count is known
- Use `Dictionary<TKey, TValue>` with appropriate initial capacity
- Avoid unnecessary string allocations (use string interpolation wisely)

## Testing

### Unit Tests
- Write tests for business logic and service methods
- Use mocking frameworks (Moq) for dependencies
- Follow AAA pattern: Arrange, Act, Assert
- Test edge cases and error conditions
- Aim for high code coverage (>80%)

### Integration Tests
- Test API endpoints end-to-end
- Use in-memory database or test database
- Clean up test data after each test
- Test authentication and authorization

### Property-Based Tests
- Use FsCheck for property-based testing
- Test invariants and business rules
- Generate random test data to find edge cases

## Logging & Monitoring

### Logging
- Use structured logging with `ILogger<T>`
- Log at appropriate levels:
  - **Trace**: Very detailed debugging information
  - **Debug**: Debugging information
  - **Information**: General informational messages
  - **Warning**: Potentially harmful situations
  - **Error**: Error events that might still allow the application to continue
  - **Critical**: Critical failures requiring immediate attention
- Include correlation IDs for request tracing
- Don't log sensitive information (passwords, tokens, PII)

### Monitoring
- Use Application Insights or similar APM tools
- Monitor API response times and error rates
- Set up alerts for critical errors
- Track custom metrics for business KPIs

## Azure Services Integration

### Azure OpenAI
- Implement retry logic with exponential backoff
- Handle rate limiting (429 errors)
- Cache responses when appropriate
- Monitor token usage and costs

### Azure Blob Storage
- Use SAS tokens for temporary access
- Implement proper error handling for storage operations
- Use async methods for all storage operations
- Set appropriate blob access levels

### Azure Document Intelligence
- Handle long-running operations properly
- Validate document formats before processing
- Implement timeout handling
- Cache extraction results

## HTTP & Middleware Best Practices

### HTTP Request Handling
- **Avoid synchronous I/O operations** in middleware and controllers
- Use `IHttpClientFactory` for all HTTP calls - never create HttpClient directly
- Configure HttpClient with appropriate timeouts and retry policies
- Reuse HttpClient instances through IHttpClientFactory
- Use Polly for resilience (retry, circuit breaker, timeout policies)

### HttpContext Best Practices
- **Avoid storing HttpContext in fields** - it's not thread-safe
- **Do not access HttpContext across threads** - it's scoped to the request
- **Do not modify response headers after response starts** - will throw exception
- Use `HttpContext.RequestAborted` for cancellation token
- Access HttpContext through `IHttpContextAccessor` when needed in services

### Middleware Development
- Keep middleware lightweight and focused
- Use async methods in middleware
- Call `next()` to continue the pipeline
- Handle exceptions appropriately
- Order middleware correctly in pipeline
- Avoid blocking operations in middleware

### JSON Serialization
- **Use System.Text.Json** for better performance (not Newtonsoft.Json)
- Configure JSON options globally in Program.cs
- Use source generators for AOT compilation
- Handle null values and naming policies consistently
- Use custom converters for complex types

## Client Optimization

### Asset Optimization
- **Bundle and minify JS/CSS assets** in production
- Use webpack, Vite, or built-in bundling tools
- Enable tree shaking to remove unused code
- Compress images and optimize formats (WebP, AVIF)
- Use lazy loading for images and components
- Implement code splitting for large applications

### Response Optimization
- **Enable response compression** (Gzip, Brotli)
- Configure compression for appropriate content types
- Set appropriate cache headers (Cache-Control, ETag)
- Use CDN for static assets
- Implement HTTP/2 or HTTP/3 for multiplexing
- Minimize response payload size

### Frontend Asset Loading
- **Optimize frontend asset loading strategy**:
  - Use `<link rel="preload">` for critical resources
  - Use `<link rel="prefetch">` for future navigation
  - Defer non-critical JavaScript
  - Inline critical CSS
  - Use async/defer for script tags
  - Implement resource hints (dns-prefetch, preconnect)

## Hosting & Deployment

### IIS Hosting
- **Use in-process hosting with IIS** for better performance
- Configure application pool settings appropriately
- Set appropriate request limits and timeouts
- Enable HTTP/2 in IIS
- Configure logging and monitoring
- Use Windows Authentication when appropriate

### Version Management
- **Upgrade regularly to the latest ASP.NET Core version**
- Stay on supported LTS (Long Term Support) versions
- Review breaking changes before upgrading
- Test thoroughly after upgrades
- Keep dependencies up to date
- Monitor security advisories

### Deployment Best Practices
- Use CI/CD pipelines for automated deployments
- Implement blue-green or canary deployments
- Use health checks for load balancer integration
- Configure graceful shutdown
- Implement rolling updates for zero downtime
- Monitor deployment metrics

## Code Review Checklist

Before committing code, ensure:
- [ ] Code follows naming conventions
- [ ] All async methods use `async`/`await` properly - no `.Wait()` or `.Result`
- [ ] No synchronous I/O operations in async code paths
- [ ] Error handling is implemented (try-catch with logging)
- [ ] Exceptions are not used for normal control flow
- [ ] Logging is added for important operations
- [ ] Input validation is performed
- [ ] Security best practices are followed (null ContentLength handled, etc.)
- [ ] Unit tests are written and passing
- [ ] No hardcoded secrets or configuration
- [ ] Code is properly documented with XML comments
- [ ] No compiler warnings
- [ ] Performance considerations addressed:
  - [ ] Pagination implemented for large datasets
  - [ ] AsNoTracking() used for read-only queries
  - [ ] N+1 queries avoided
  - [ ] IHttpClientFactory used for HTTP calls
  - [ ] Large allocations minimized (use ArrayPool if needed)
- [ ] HttpContext not stored in fields or accessed across threads
- [ ] Response headers not modified after response starts
- [ ] Background services don't capture scoped services incorrectly
- [ ] System.Text.Json used instead of Newtonsoft.Json
- [ ] Response compression enabled for appropriate content
- [ ] Assets bundled and minified for production
