# URL Shortener - QA Test Report

**Date**: 2026-04-02
**Tester**: Senior QA Engineer
**Application**: URL Shortener (Java Spring Boot + MySQL + React)
**Backend URL**: http://localhost:8080
**Status**: Backend NOT Running - Tests performed via static code analysis

---

## Executive Summary

| Category | Status |
|----------|--------|
| Backend Health | FAIL - Not running on port 8080 |
| MySQL Connection | PASS - Running on port 3306 |
| API Contract | PARTIAL - Issues found |
| Code Quality | ISSUES FOUND |
| Security | ISSUES FOUND |
| Performance | ISSUES FOUND |

---

## 1. API Testing Results

### 1.1 Health Check - CANNOT TEST

**Status**: FAIL - Backend not reachable

```
$ curl http://localhost:8080/api/health
Connection refused
```

**Action Required**: Start Spring Boot application

---

### 1.2 POST /shorten - Expected Behavior

| Test Case | Input | Expected | Notes |
|-----------|-------|----------|-------|
| Valid URL | `{"url": "https://google.com"}` | 200 + shortCode | Should work |
| Invalid URL (no protocol) | `{"url": "not-a-url"}` | 400 Bad Request | Need to verify |
| Empty URL | `{"url": ""}` | 400 Bad Request | @NotBlank should catch |
| Missing URL field | `{}` | 400 Bad Request | @NotBlank should catch |
| Very Long URL (>2048) | URL with 5000+ chars | 400 Bad Request | @Size(max=2048) should catch |
| Duplicate URL | Same URL twice | Both return shortCode | NO deduplication |
| Custom Alias valid | 3-20 alphanumeric | 200 + custom shortCode | |
| Custom Alias invalid | "ab" or "invalid!@#" | 400 Bad Request | Validation should catch |
| Custom Alias duplicate | Already exists | 400 or 409 | Should reject |
| Expiry Days | 1-365 | 200 + expiry set | Should work |

---

### 1.3 GET /{shortCode} - Expected Behavior

| Test Case | Input | Expected | Notes |
|-----------|-------|----------|-------|
| Valid shortCode | Existing code | 302 redirect | |
| Invalid shortCode | Nonexistent | 404 Not Found | |
| Expired URL | Past expiry date | 410 Gone | |
| Deactivated URL | Deleted | 404 or 410 | active=false |
| Click counting | Any valid redirect | Increment clickCount | |

---

## 2. Bugs & Issues Found (Static Analysis)

### BUG-1: CRITICAL - Rate Limiter Memory Leak

**File**: `RateLimiterService.java` (lines 13-20)

**Issue**:
```java
private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

public Bucket resolveBucket(String clientIp) {
    return buckets.computeIfAbsent(clientIp, this::createBucket);
}
```

**Problem**: The `buckets` map grows unbounded. Each unique IP that hits the server creates a new Bucket that is never removed. In production with 1M users, this causes:
- Memory exhaustion
- Gradual performance degradation

**Fix Required**:
```java
// Add TTL-based eviction or use Caffeine cache
@Configuration
public class RateLimiterService {
    private final Cache<String, Bucket> buckets = Caffeine.newBuilder()
        .expireAfterAccess(Duration.ofMinutes(30))
        .maximumSize(100_000)
        .build();
}
```

---

### BUG-2: HIGH - Click Count Race Condition

**File**: `UrlService.java` (lines 62-74) and `UrlMappingRepository.java` (lines 21-23)

**Issue**:
```java
// UrlService.java
urlMappingRepository.incrementClickCount(shortCode);

// Repository
@Modifying
@Query("UPDATE UrlMapping u SET u.clickCount = u.clickCount + 1 WHERE u.shortCode = :shortCode")
void incrementClickCount(@Param("shortCode") String shortCode);
```

**Problem**:
1. This is a fire-and-forget operation - no transaction guarantee
2. Race condition under high load - multiple requests may read same count
3. No retry mechanism if update fails
4. No consistency check

**Fix Required**:
```java
// Option 1: Use @Transactional with explicit lock
@Transactional
public String getOriginalUrl(String shortCode) {
    UrlMapping mapping = urlMappingRepository.findByShortCodeWithLock(shortCode)
            .orElseThrow(() -> new UrlNotFoundException(shortCode));
    mapping.incrementClickCount();
    // ... save happens in transaction
}

// Option 2: Atomic update with returning
@Query(value = "UPDATE url_mappings SET click_count = click_count + 1
                WHERE short_code = :shortCode RETURNING click_count", nativeQuery = true)
```

---

### BUG-3: MEDIUM - No URL Scheme Validation

**File**: `ShortenRequest.java` (line 11)

**Issue**:
```java
@Pattern(regexp = "^https?://.*", message = "URL must start with http:// or https://")
private String url;
```

**Problem**:
- `ftp://files.com` is rejected (possibly intentional)
- `javascript:alert(1)` could be dangerous if rendered
- No validation that URL is actually reachable
- No blocklist for malicious domains

**Recommendation**: Add URL sanitization and consider allowing more protocols if needed

---

### BUG-4: MEDIUM - Custom Alias Validation Mismatch

**File**: `UrlService.java` (line 24) vs `UrlMapping.java` (line 17)

**Issue**:
```java
// UrlService allows: 3-20 chars
private static final Pattern CUSTOM_ALIAS_PATTERN = Pattern.compile("^[a-zA-Z0-9_-]{3,20}$");

// But DB column is: length = 20
@Column(nullable = false, unique = true, length = 20)
private String shortCode;
```

**Problem**: "12345678901234567890" (20 chars) passes validation but 20 + special chars like "_" might exceed. Actually fixed already (was 10, now 20). **STATUS: RESOLVED**

---

### BUG-5: LOW - No Pagination in Repository

**File**: `UrlMappingRepository.java`

**Issue**: Methods like `findAll()` are inherited but no pagination defined.

**Problem**: If URL table grows to millions, admin operations could timeout.

**Recommendation**: Add `Pageable` support for list operations.

---

### BUG-6: MEDIUM - Missing Database Index

**File**: `UrlMapping.java`

**Issue**:
```java
@Table(name = "url_mappings", indexes = {
    @Index(name = "idx_short_code", columnList = "shortCode", unique = true),
    @Index(name = "idx_created_at", columnList = "createdAt")
})
```

**Problem**:
- Missing index on `active` column for filtering expired/inactive URLs
- Missing composite index for `(active, expiry)` for cleanup jobs
- Missing index on `(created_at, active)` for analytics queries

**Recommendation**: Add:
```java
@Index(name = "idx_active_expiry", columnList = "active, expiry")
@Index(name = "idx_click_count", columnList = "clickCount")
```

---

### BUG-7: HIGH - Rate Limit Not Applied to Redirects

**File**: `UrlController.java`

**Issue**:
```java
@PostMapping("/shorten")  // Rate limited
public ResponseEntity<ShortenResponse> shortenUrl(...) {
    Bucket bucket = rateLimiterService.resolveBucket(clientIp);
    if (!bucket.tryConsume(1)) { return 429; }
}

@GetMapping("/{shortCode}")  // NOT rate limited!
public ResponseEntity<Void> redirectToOriginal(@PathVariable String shortCode) {
    // No rate limiting here!
}
```

**Problem**: Attackers can bypass rate limiting by hitting redirect endpoint directly. Short code enumeration is also possible.

**Fix Required**: Apply rate limiting to ALL public endpoints.

---

### BUG-8: MEDIUM - CORS Misconfiguration

**File**: `WebConfig.java`

**Issue**:
```java
config.setAllowedOrigins(Arrays.asList(allowedOrigins.split(",")));
```

**Problem**:
- No validation of origin format
- Wildcard `*` could accidentally be set
- Subdomain takeover could allow malicious origins

**Recommendation**: Validate origins against an allowlist, not from config string.

---

## 3. Database Validation Checklist

| Check | SQL | Expected | Status |
|-------|-----|----------|--------|
| Table exists | `SHOW TABLES LIKE 'url_mappings'` | 1 row | PENDING |
| Primary key | `DESCRIBE url_mappings` | id BIGINT PK | PENDING |
| Unique index | `SHOW INDEX FROM url_mappings WHERE Non_unique = 0` | short_code unique | PENDING |
| Click count default | `SELECT click_count FROM url_mappings LIMIT 1` | 0 | PENDING |
| Expiry nullable | `SELECT expiry IS NULL FROM url_mappings LIMIT 1` | true | PENDING |
| Active default | `SELECT active FROM url_mappings LIMIT 1` | true | PENDING |

---

## 4. Frontend Testing Checklist

| Test Case | Steps | Expected | Status |
|-----------|-------|----------|--------|
| Valid URL shorten | Enter https://google.com, click Shorten | Show short URL | PENDING |
| Invalid URL | Enter "not-a-url", click | Show validation error | PENDING |
| Empty input | Click submit without URL | Show validation error | PENDING |
| Loading state | Click submit, observe | Button disabled, shows "Shortening..." | PENDING |
| Error display | Submit invalid | Show error message | PENDING |
| Copy button | After success, click Copy | Short URL copied to clipboard | PENDING |
| Link click | Click short URL | Opens in new tab | PENDING |
| Custom alias | Enter alias "test123" | Uses custom alias | PENDING |
| Expiry field | Enter 7 days | Shows expiry in response | PENDING |

---

## 5. Edge Case Test Matrix

| Scenario | Input | Expected | Priority |
|----------|-------|----------|----------|
| Same URL 10 times | `{"url": "https://same.com"}` x10 | 10 different shortCodes | HIGH |
| URL with query params | `https://a.com?x=1&y=2&z=测试` | Encode properly | HIGH |
| URL with fragment | `https://a.com#section` | Preserve fragment | MEDIUM |
| URL with auth | `https://user:pass@a.com` | Handle or reject | MEDIUM |
| Very long custom alias | 20 chars | Should work | LOW |
| Custom alias exactly 3 chars | "abc" | Should work | LOW |
| Custom alias 21 chars | "abcdefghijk1234567890" | Should reject | HIGH |
| Expiry = 0 days | `"expiryDays": 0` | Should be null/ignore | MEDIUM |
| Expiry = -1 days | `"expiryDays": -1` | Should reject | HIGH |
| Expiry = 366 days | `"expiryDays": 366` | Should reject or cap | MEDIUM |
| Concurrent requests (10) | 10 simultaneous POST | All succeed | HIGH |
| XSS in URL | `<script>alert(1)</script>` | Sanitize or reject | HIGH |
| SQL injection attempt | `'; DROP TABLE url_mappings;--` | Parameterized queries protect | MEDIUM |

---

## 6. Performance Benchmarks

### Expected Response Times (Target)

| Endpoint | P50 | P95 | P99 |
|----------|-----|-----|-----|
| POST /shorten | <50ms | <200ms | <500ms |
| GET /redirect | <20ms | <50ms | <100ms |
| GET /analytics | <30ms | <100ms | <200ms |

### Load Testing Checklist

| Metric | Target | Notes |
|--------|--------|-------|
| Concurrent users | 100 | Simulate with curl/ab |
| Requests/second | 500 | Before degradation |
| Memory usage | <512MB | Watch for leaks |
| CPU usage | <70% | Under sustained load |

---

## 7. Security Checklist

| Check | Status | Notes |
|-------|--------|-------|
| SQL Injection | PASS | JPA parameterized queries |
| XSS | PARTIAL | URL not sanitized on output |
| CSRF | N/A | Stateless API |
| Rate Limiting | PARTIAL | Only on /shorten |
| Input Validation | PASS | Bean validation in place |
| Error Info Leak | FAIL | Stack trace in dev mode |
| HTTPS | N/A | Configure at deployment |

---

## 8. Required Fixes Summary

### Must Fix (P0)

1. **Rate limiter memory leak** - Add TTL/eviction
2. **Rate limiting on redirects** - Apply to all endpoints
3. **Click count race condition** - Use transaction with lock

### Should Fix (P1)

4. **Missing database indexes** - Add composite indexes
5. **CORS validation** - Validate against allowlist
6. **Origin format validation** - Sanitize config input

### Nice to Have (P2)

7. **Pagination** - Add Pageable to repository
8. **URL blocklist** - Block known malicious domains
9. **Metrics** - Add Micrometer/Prometheus metrics

---

## 9. Test Execution Commands

### Start Backend
```bash
cd Backend
./mvnw spring-boot:run
```

### Run API Tests
```bash
# Linux/Mac
chmod +x test-api.sh
./test-api.sh http://localhost:8080

# Windows
test-api.bat
```

### Database Verification
```sql
-- Check table structure
DESCRIBE url_mappings;

-- Check indexes
SHOW INDEX FROM url_mappings;

-- Check sample data
SELECT * FROM url_mappings LIMIT 5;

-- Verify click count
SELECT short_code, click_count FROM url_mappings ORDER BY click_count DESC LIMIT 5;
```

### Frontend Testing
```bash
cd Frontend
npm install
npm start
# Open http://localhost:3000
```

---

## 10. Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| QA Engineer | [Name] | 2026-04-02 | Pending |
| Backend Dev | [Name] | [Date] | Pending |
| Tech Lead | [Name] | [Date] | Pending |

---

*Report Generated: 2026-04-02*
*Test Environment: Local development (MySQL on port 3306)*
*Backend Status: NOT RUNNING - Start before full testing*
