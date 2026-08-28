---
name: performance
description: Universal performance engineering guidelines for software projects. Use when building, modifying, reviewing, debugging, profiling, or optimizing frontend, backend, APIs, databases, networking, builds, dependencies, assets, or runtime behavior. Prioritize measurable improvements, efficient resource usage, and maintainable solutions without premature optimization.
---

# Performance Engineering Skill

## Purpose

Build software that is fast, responsive, efficient, scalable, and maintainable.

Optimize real bottlenecks rather than guessing.

Performance improvements must not unnecessarily reduce:

- Correctness
- Security
- Reliability
- Accessibility
- Maintainability
- Developer experience

Prefer simple, measurable optimizations over complicated performance systems.

---

# 1. Core Principles

## Measure Before Optimizing

Do not make major performance changes based only on assumptions.

When practical:

1. Identify the suspected bottleneck.
2. Measure current behavior.
3. Make the smallest reasonable improvement.
4. Measure again.
5. Keep the change only if it provides a meaningful benefit.

Use profiling, benchmarks, browser performance tools, database query analysis, logs, or other appropriate measurements.

## Optimize Bottlenecks, Not Everything

Prioritize:

1. User-visible latency
2. Slow critical paths
3. Excessive network requests
4. Expensive database queries
5. Excessive memory usage
6. Large bundles/assets
7. CPU-intensive operations
8. Repeated or unnecessary work

Do not optimize trivial code merely because it looks inefficient.

## Prefer Simplicity

Do not introduce complex infrastructure for minor gains.

Avoid adding:

- Caching layers
- Redis
- Message queues
- Workers
- Microservices
- Custom optimization frameworks
- Complex state-management systems
- Premature abstractions

unless the project's measured requirements justify them.

---

# 2. Application Architecture

Prefer architecture that minimizes unnecessary work and communication.

Before changing architecture:

- Understand the existing system.
- Identify the actual bottleneck.
- Consider the simplest solution.
- Avoid rewriting working systems without measurable justification.

Prefer:

```text
Simple architecture
      ↓
Measure
      ↓
Identify bottleneck
      ↓
Targeted optimization
```

Avoid:

```text
Complex architecture
      ↓
Assumed performance problem
      ↓
Unnecessary infrastructure
```

Keep expensive operations away from latency-sensitive paths when practical.

---

# 3. Frontend Performance

## Rendering

Render only what is necessary.

Avoid:

- Unnecessary re-renders
- Unnecessary client-side state
- Duplicate components performing the same work
- Large component trees without reason
- Expensive calculations during rendering

For frameworks supporting server-side rendering or server components, prefer server-side execution when client-side interactivity is not required.

Use client-side code only when needed for:

- User interaction
- Browser APIs
- Local UI state
- Real-time behavior
- Client-only libraries

Do not mark entire sections of an application as client-side unnecessarily.

## JavaScript

Minimize JavaScript sent to users.

Avoid:

- Large unnecessary libraries
- Duplicate dependencies
- Client-side implementations of server-side work
- Shipping data that the page does not need
- Running expensive calculations repeatedly

Prefer native platform capabilities when they are sufficient.

## Lists

For large datasets:

- Paginate where appropriate.
- Virtualize very large lists when necessary.
- Avoid rendering thousands of unnecessary DOM nodes.
- Fetch only the required records.

---

# 4. Network Performance

Reduce unnecessary network work.

Prefer:

- Fewer requests
- Smaller payloads
- Appropriate caching
- Compression
- Request deduplication
- Parallel independent requests
- Efficient API responses

Avoid:

- Duplicate requests
- Sequential requests when operations can safely run in parallel
- Sending unused fields
- Large responses for small UI requirements
- Polling when a more efficient mechanism is appropriate

Do not optimize network requests by sacrificing correctness or data consistency.

---

# 5. API Performance

API endpoints should:

- Validate input efficiently.
- Return only necessary data.
- Avoid unnecessary database calls.
- Avoid duplicate work.
- Handle pagination for large datasets.
- Use appropriate caching when justified.
- Avoid blocking operations when asynchronous processing is appropriate.

Avoid N+1 request patterns.

Prefer:

```text
One efficient request
      ↓
Required data
```

over:

```text
Request
 ↓
Request
 ↓
Request
 ↓
Request
 ↓
Request
```

when the operations can reasonably be combined.

Do not expose unnecessary internal data merely to simplify frontend development.

---

# 6. Database Performance

## Queries

Write queries that retrieve only the data required.

Avoid:

- Selecting unnecessary columns
- Loading entire tables
- Repeated identical queries
- N+1 queries
- Unbounded queries
- Inefficient joins
- Filtering large datasets entirely in application memory

Prefer database-side filtering, sorting, aggregation, and pagination when appropriate.

## Indexes

Use indexes for frequently queried fields when justified.

Consider indexes for:

- Frequently filtered columns
- Frequently sorted columns
- Foreign keys
- Frequently searched identifiers
- Common query combinations

Do not create indexes for every column.

Indexes have costs:

- Storage
- Write overhead
- Maintenance
- Additional complexity

## Pagination

Large datasets should not normally be returned in one request.

Use appropriate pagination.

For very large or frequently changing datasets, consider cursor/keyset pagination when offset pagination becomes inefficient.

## Transactions

Use transactions when multiple related database operations must succeed or fail together.

Do not use transactions unnecessarily for independent operations.

---

# 7. Caching

Caching can improve performance but introduces complexity and stale-data problems.

Before adding caching, determine:

- What is expensive?
- How frequently does it change?
- How frequently is it requested?
- How stale can the data safely become?
- What invalidates the cache?

Prefer simple caching mechanisms first.

Do not add distributed caching infrastructure unless the application requires it.

Always consider cache invalidation and correctness.

---

# 8. Images and Assets

Optimize large assets.

Prefer:

- Modern image formats where supported
- Responsive image sizes
- Appropriate compression
- Lazy loading for non-critical images
- Correct dimensions
- Optimized thumbnails

Avoid:

- Uploading massive images for small display areas
- Loading every image immediately
- Duplicate assets
- Unused fonts
- Excessive icon libraries

Do not sacrifice meaningful visual quality unnecessarily.

---

# 9. CSS and UI Performance

Avoid excessive:

- DOM nesting
- Expensive animations
- Large blur effects
- Heavy shadows
- Continuous layout calculations
- JavaScript-driven animations when CSS can handle them

Prefer performant CSS transitions and transforms where appropriate.

Respect reduced-motion preferences.

Avoid animations that interfere with usability or accessibility.

---

# 10. Memory Usage

Avoid unnecessary memory retention.

Watch for:

- Unbounded arrays
- Large objects kept in memory
- Event listeners that are never removed
- Timers that are never cleared
- Unreleased resources
- Large cached datasets
- Memory-heavy processing on request paths

For long-running processes, consider memory growth over time.

---

# 11. CPU Usage

Avoid repeatedly performing expensive calculations.

Prefer:

- Precomputation when justified
- Memoization when measurement shows repeated expensive work
- Efficient algorithms
- Batch processing
- Incremental processing

Do not memoize every function or component automatically.

Memoization itself has memory and complexity costs.

---

# 12. Algorithms and Data Structures

Choose appropriate algorithms and data structures.

Consider time and space complexity.

Prefer:

- Hash maps/sets for efficient lookups when appropriate
- Efficient sorting/filtering strategies
- Appropriate indexing
- Avoiding repeated linear searches in large datasets

Do not replace simple readable code with complicated algorithms unless the scale justifies it.

---

# 13. Concurrency and Asynchronous Work

Independent operations should run concurrently when safe.

For example:

```text
Task A ────────┐
Task B ────────┼──→ Continue
Task C ────────┘
```

rather than unnecessarily:

```text
Task A → Task B → Task C
```

However, respect:

- Dependencies
- Rate limits
- Database constraints
- Resource limits
- Ordering requirements
- Race conditions

Do not parallelize operations that must remain sequential.

---

# 14. Background Processing

Move expensive non-user-critical work out of request/response paths when appropriate.

Potential candidates:

- Large file processing
- Report generation
- Email sending
- Data imports
- Image processing
- Batch operations

Use background jobs only when justified by actual requirements.

Do not introduce queues or workers merely because they are considered "scalable."

---

# 15. Build and Dependency Performance

Keep projects lightweight.

Before adding a dependency:

1. Check whether the project already has a solution.
2. Check whether the platform provides the capability.
3. Consider dependency size.
4. Consider runtime impact.
5. Consider maintenance cost.
6. Consider security implications.

Remove unused dependencies when safe.

Avoid duplicate libraries that solve the same problem.

Keep development tooling separate from production runtime dependencies when appropriate.

---

# 16. Loading Strategy

Prioritize critical content.

Load:

- Critical UI first
- Critical CSS first
- Critical data first

Defer:

- Non-critical components
- Heavy libraries
- Below-the-fold content
- Optional analytics
- Secondary functionality

Use lazy loading when it provides a meaningful benefit.

Do not lazy-load everything.

---

# 17. Error Handling and Performance

Performance optimizations must not hide failures.

Do not:

- Silently ignore errors
- Return incomplete data without indication
- Skip validation for speed
- Remove important logging blindly
- Disable safety checks without evidence

A fast incorrect application is not a performant application.

---

# 18. Security vs Performance

Never weaken security simply for performance.

Do not:

- Disable authentication
- Remove authorization checks
- Store secrets insecurely
- Skip input validation
- Expose sensitive data
- Disable encryption
- Trust client-side validation

If security checks are expensive, optimize their implementation rather than removing them.

---

# 19. Accessibility vs Performance

Do not remove accessibility features solely for small performance gains.

Maintain:

- Keyboard accessibility
- Semantic HTML
- Screen-reader support
- Focus management
- Reduced-motion support
- Sufficient visual clarity

Performance and accessibility should work together.

---

# 20. Monitoring

For production applications, monitor meaningful performance indicators such as:

- Response time
- Error rate
- Database latency
- Resource usage
- Page load performance
- API latency
- Memory usage
- CPU usage

Use real measurements when available.

Do not optimize against imaginary metrics.

---

# 21. Performance Review Checklist

Before considering a performance-sensitive feature complete, check:

### Frontend

- [ ] Unnecessary client-side code avoided
- [ ] Unnecessary re-renders avoided
- [ ] Large lists handled appropriately
- [ ] Images optimized
- [ ] Heavy components loaded appropriately
- [ ] Unnecessary dependencies avoided

### Network

- [ ] Duplicate requests avoided
- [ ] Payloads contain only necessary data
- [ ] Independent requests are parallelized when appropriate
- [ ] Large responses are paginated

### Backend

- [ ] Expensive work identified
- [ ] Unnecessary processing removed
- [ ] Appropriate asynchronous behavior used
- [ ] N+1 patterns avoided

### Database

- [ ] Queries request only necessary data
- [ ] Large datasets are paginated
- [ ] N+1 queries avoided
- [ ] Appropriate indexes considered
- [ ] Unnecessary queries removed

### Assets

- [ ] Images optimized
- [ ] Unused assets removed
- [ ] Large files handled appropriately

### Architecture

- [ ] No unnecessary infrastructure added
- [ ] No premature optimization
- [ ] Complexity is justified
- [ ] Existing architecture was considered before changing it

---

# 22. Optimization Decision Rule

Before implementing an optimization, ask:

1. **What is slow?**
2. **How do we know it is slow?**
3. **What is causing the problem?**
4. **What is the simplest solution?**
5. **What are the trade-offs?**
6. **How will we verify the improvement?**

If there is no measurable or clearly user-visible problem, prefer the simpler implementation.

---

# Final Rule

**Make it correct first.  
Make it simple.  
Measure it.  
Find the bottleneck.  
Optimize the bottleneck.  
Measure again.  
Keep complexity proportional to the actual problem.**