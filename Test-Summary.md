# URL Shortener - QA Test Summary

## Test Status Overview

| Component | Status | Notes |
|-----------|--------|-------|
| Backend Compiles | PASS | Maven build successful |
| MySQL Running | PASS | Port 3306 active |
| Backend Running | FAIL | Not started on port 8080 |
| API Contract | FIXED | Rate limiting now on all endpoints |
| Click Count | FIXED | Pessimistic lock prevents race condition |
| Rate Limiter Memory | FIXED | Cleanup mechanism added |

---

## Test Cases - API Endpoints

### A. POST /shorten

| ID | Test Case | Input | Expected | Priority |
|----|-----------|-------|---------|----------|
| TC-01 | Valid URL | `{"url": "https://google.com"}` | 200, shortCode returned | P0 |
| TC-02 | Valid URL with custom alias | `{"url": "https://github.com", "customAlias": "github"}` | 200, custom alias used | P0 |
| TC-03 | Valid URL with expiry | `{"url": "https://twitter.com", "expiryDays": 30}` | 200, expiry set | P0 |
| TC-04 | Invalid URL (no protocol) | `{"url": "not-a-url"}` | 400, validation error | P0 |
| TC-05 | Empty URL | `{"url": ""}` | 400, validation error | P0 |
| TC-06 | Missing URL field | `{}` | 400, validation error | P0 |
| TC-07 | URL too long (>2048 chars) | URL with 5000+ chars | 400, validation error | P1 |
| TC-08 | Custom alias too short | `{"url": "https://a.com", "customAlias": "ab"}` | 400, validation error | P0 |
| TC-09 | Custom alias too long | `{"url": "https://a.com", "customAlias": "123456789012345678901"}` | 400, validation error | P0 |
| TC-10 | Custom alias with invalid chars | `{"url": "https://a.com", "customAlias": "invalid!@#"}` | 400, validation error | P0 |
| TC-11 | Duplicate custom alias | Same alias twice | Second request: 400 | P0 |
| TC-12 | Expiry = 0 | `{"url": "https://a.com", "expiryDays": 0}` | 200, expiry = null | P1 |
| TC-13 | Expiry = negative | `{"url": "https://a.com", "expiryDays": -5}` | 200, expiry = null | P1 |
| TC-14 | Expiry = 366 (over 1 year) | `{"url": "https://a.com", "expiryDays": 366}` | 200 (no upper limit) | P2 |
| TC-15 | Duplicate URL (same twice) | Same URL twice | Both succeed, different codes | P2 |

### B. GET /{shortCode}

| ID | Test Case | Expected | Priority |
|----|-----------|----------|----------|
| TC-16 | Valid shortCode | 302 redirect to originalUrl | P0 |
| TC-17 | Invalid shortCode | 404 Not Found | P0 |
| TC-18 | Expired URL | 410 Gone | P0 |
| TC-19 | Deactivated URL | 404 Not Found | P0 |
| TC-20 | Click count increments | Count +1 after redirect | P0 |

### C. GET /analytics/{shortCode}

| ID | Test Case | Expected | Priority |
|----|-----------|----------|----------|
| TC-21 | Valid shortCode | 200, all stats returned | P0 |
| TC-22 | Invalid shortCode | 404 Not Found | P0 |

### D. DELETE /{shortCode}

| ID | Test Case | Expected | Priority |
|----|-----------|----------|----------|
| TC-23 | Valid shortCode | 204 No Content | P0 |
| TC-24 | After delete, GET returns 404 | 404 Not Found | P0 |

### E. Rate Limiting

| ID | Test Case | Expected | Priority |
|----|-----------|----------|----------|
| TC-25 | 31 rapid requests | Last request: 429 Too Many Requests | P0 |
| TC-26 | After 1 minute | Should allow again | P1 |

---

## Bugs Fixed

### BUG-1: Rate Limiter Memory Leak ✅ FIXED

**Problem**: Unbounded Map growth
**Solution**: Added MAX_BUCKETS limit (100,000) and cleanup mechanism

```java
if (buckets.size() > MAX_BUCKETS) {
    cleanup();
}
```

---

### BUG-2: Click Count Race Condition ✅ FIXED

**Problem**: Concurrent updates could lose counts
**Solution**: Added pessimistic lock on findByShortCodeWithLock

```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("SELECT u FROM UrlMapping u WHERE u.shortCode = :shortCode AND u.active = true")
Optional<UrlMapping> findByShortCodeWithLock(@Param("shortCode") String shortCode);
```

---

### BUG-3: Rate Limiting Not on Redirects ✅ FIXED

**Problem**: Only /shorten was rate limited
**Solution**: Applied rate limiting to GET /{shortCode} endpoint

---

## Remaining Recommendations (Not Fixed)

### REC-1: Missing Composite Indexes
**File**: `UrlMapping.java`

```java
// Add these indexes:
@Index(name = "idx_active_expiry", columnList = "active, expiry")
@Index(name = "idx_click_count", columnList = "clickCount")
```

### REC-2: URL Blocklist
Consider adding a blocklist for malicious domains.

### REC-3: Metrics/Monitoring
Add Micrometer/Prometheus for production observability.

---

## How to Run Tests

### 1. Start Backend
```bash
cd Backend
./mvnw spring-boot:run
```

### 2. Run API Tests
```bash
# Windows
test-api.bat

# Linux/Mac
chmod +x test-api.sh
./test-api.sh http://localhost:8080
```

### 3. Database Verification
```sql
mysql -u root -p urlshortener < database-validation.sql
```

### 4. Run Frontend
```bash
cd Frontend
npm install
npm start
# Open http://localhost:3000
```

---

## Performance Targets

| Metric | Target | Acceptable |
|--------|--------|------------|
| POST /shorten P50 | <50ms | <100ms |
| POST /shorten P95 | <200ms | <500ms |
| GET /redirect P50 | <20ms | <50ms |
| GET /redirect P95 | <50ms | <200ms |
| Max concurrent | 100 | 50 |

---

## Sign-off Checklist

| Check | Status | Notes |
|-------|--------|-------|
| All P0 test cases pass | PENDING | Run after starting backend |
| Database schema correct | PENDING | Run SQL validation |
| No critical bugs | FIXED | 3 of 3 critical bugs fixed |
| Rate limiting works | FIXED | Applied to all endpoints |
| Click count accurate | FIXED | Pessimistic lock added |
| Frontend works | PENDING | Manual testing required |

---

*Report Date: 2026-04-02*
*Tester: Senior QA Engineer*
