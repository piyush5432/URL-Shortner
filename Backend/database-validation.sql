-- URL Shortener - Database Validation Queries
-- Run these against PostgreSQL on localhost:5432

-- ============================================
-- 1. CHECK TABLE EXISTS
-- ============================================
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'url_mappings';

-- ============================================
-- 2. VERIFY TABLE STRUCTURE
-- ============================================
\d url_mappings

-- Expected columns:
-- id           | bigint       | NOT NULL | auto_increment
-- short_code   | varchar(20)  | NOT NULL | UNIQUE
-- original_url | varchar(2048)| NOT NULL |
-- created_at   | timestamp    | NOT NULL |
-- expiry       | timestamp    | YES      |
-- click_count  | bigint       | NOT NULL | default 0
-- active       | boolean      | NOT NULL | default true

-- ============================================
-- 3. CHECK INDEXES
-- ============================================
SELECT indexname, indexdef FROM pg_indexes
WHERE tablename = 'url_mappings';

-- Expected indexes:
-- url_mappings_pkey (PRIMARY)
-- idx_short_code (unique) on short_code
-- idx_created_at on created_at

-- ============================================
-- 4. SAMPLE DATA CHECK
-- ============================================
SELECT * FROM url_mappings LIMIT 10;

-- ============================================
-- 5. UNIQUE CONSTRAINT TEST
-- ============================================
-- This should FAIL (duplicate short_code)
-- INSERT INTO url_mappings (short_code, original_url, created_at, click_count, active)
-- VALUES ('test123', 'https://test.com', NOW(), 0, true);

-- ============================================
-- 6. CLICK COUNT VERIFICATION
-- ============================================
SELECT
    short_code,
    original_url,
    click_count,
    active
FROM url_mappings
ORDER BY click_count DESC
LIMIT 5;

-- ============================================
-- 7. EXPIRY LOGIC CHECK
-- ============================================
-- Find expired URLs (should return empty if all URLs are valid)
SELECT * FROM url_mappings
WHERE expiry IS NOT NULL
  AND expiry < NOW()
  AND active = TRUE;

-- ============================================
-- 8. ACTIVE/INACTIVE BREAKDOWN
-- ============================================
SELECT
    active,
    COUNT(*) as count
FROM url_mappings
GROUP BY active;

-- ============================================
-- 9. TEST INSERT WITH ALL FIELDS
-- ============================================
INSERT INTO url_mappings (short_code, original_url, created_at, expiry, click_count, active)
VALUES ('test123', 'https://example.com', NOW(), NOW() + INTERVAL '30 days', 0, true);

-- Cleanup
DELETE FROM url_mappings WHERE short_code = 'test123';

-- ============================================
-- 10. CLICK COUNT INCREMENT TEST
-- ============================================
-- Before
SELECT click_count FROM url_mappings WHERE short_code = 'test123';

-- Increment
UPDATE url_mappings SET click_count = click_count + 1 WHERE short_code = 'test123';

-- After
SELECT click_count FROM url_mappings WHERE short_code = 'test123';

-- ============================================
-- 11. VERIFY COLUMN SIZES
-- ============================================
SELECT
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_key
FROM information_schema.columns
WHERE table_name = 'url_mappings'
  AND table_schema = 'public';

-- ============================================
-- 12. PERFORMANCE CHECK (if data exists)
-- ============================================
-- Check table size
SELECT
    pg_size_pretty(pg_total_relation_size('url_mappings')) as total_size,
    pg_size_pretty(pg_relation_size('url_mappings')) as table_size,
    pg_size_pretty(pg_indexes_size('url_mappings')) as index_size;

-- ============================================
-- 13. SEQUENCE CHECK
-- ============================================
SELECT sequence_name FROM information_schema.sequences
WHERE sequence_schema = 'public';

-- ============================================
-- 14. AUTO_INCREMENT (SERIAL) CHECK
-- ============================================
SELECT column_name, column_default
FROM information_schema.columns
WHERE table_name = 'url_mappings'
  AND table_schema = 'public'
  AND column_default LIKE 'nextval%';
