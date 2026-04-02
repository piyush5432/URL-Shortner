#!/bin/bash
# URL Shortener - QA Test Script (Bash version)
# Usage: ./test-api.sh

BASE_URL="${1:-http://localhost:8080}"

echo "================================================"
echo "URL Shortener - API Testing Suite"
echo "Target: $BASE_URL"
echo "================================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper function
test_endpoint() {
    local name="$1"
    local method="$2"
    local url="$3"
    local data="$4"
    local extra_opts="$5"

    echo -e "${YELLOW}[TEST] $name${NC}"
    echo "Command: $method $url"

    if [ -n "$data" ]; then
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" $extra_opts -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$data" 2>&1)
    else
        response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" $extra_opts -X "$method" "$url" 2>&1)
    fi

    http_code=$(echo "$response" | grep "HTTP_STATUS" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_STATUS/d')

    echo "HTTP Status: $http_code"
    echo "Response: $body"
    echo ""
}

# ============================================
# TEST 1: Health Check
# ============================================
echo -e "${GREEN}[TEST 1] Health Check${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/health"
echo ""

# ============================================
# TEST 2: POST /shorten - Valid URL
# ============================================
test_endpoint "POST /shorten - Valid URL" "POST" "$BASE_URL/shorten" \
    '{"url": "https://www.google.com/search?q=testing"}'

# ============================================
# TEST 3: POST /shorten - Invalid URL
# ============================================
test_endpoint "POST /shorten - Invalid URL (no protocol)" "POST" "$BASE_URL/shorten" \
    '{"url": "not-a-valid-url"}'

# ============================================
# TEST 4: POST /shorten - Empty URL
# ============================================
test_endpoint "POST /shorten - Empty URL" "POST" "$BASE_URL/shorten" \
    '{"url": ""}'

# ============================================
# TEST 5: POST /shorten - Missing URL
# ============================================
test_endpoint "POST /shorten - Missing URL field" "POST" "$BASE_URL/shorten" \
    '{}'

# ============================================
# TEST 6: POST /shorten - Very Long URL
# ============================================
LONG_URL="https://example.com/$(printf 'a%.0s' {1..5000})"
test_endpoint "POST /shorten - Very Long URL (5000 chars)" "POST" "$BASE_URL/shorten" \
    "{\"url\": \"$LONG_URL\"}"

# ============================================
# TEST 7: POST /shorten - With Custom Alias
# ============================================
test_endpoint "POST /shorten - Custom Alias" "POST" "$BASE_URL/shorten" \
    '{"url": "https://github.com", "customAlias": "qatest001"}'

# ============================================
# TEST 8: POST /shorten - Duplicate Custom Alias
# ============================================
test_endpoint "POST /shorten - Duplicate Custom Alias (expect 400)" "POST" "$BASE_URL/shorten" \
    '{"url": "https://twitter.com", "customAlias": "qatest001"}'

# ============================================
# TEST 9: POST /shorten - With Expiry
# ============================================
test_endpoint "POST /shorten - With Expiry (7 days)" "POST" "$BASE_URL/shorten" \
    '{"url": "https://stackoverflow.com", "expiryDays": 7}'

# ============================================
# TEST 10: GET /{shortCode} - Valid Redirect
# ============================================
echo -e "${GREEN}[TEST 10] GET /{shortCode} - Valid Redirect${NC}"
echo "Command: HEAD $BASE_URL/qatest001"
curl -s -w "\nHTTP Status: %{http_code}\nRedirect: %{redirect_url}\n" -I "$BASE_URL/qatest001"
echo ""

# ============================================
# TEST 11: GET /{shortCode} - Invalid Code
# ============================================
echo -e "${GREEN}[TEST 11] GET /{shortCode} - Invalid Code (expect 404)${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -I "$BASE_URL/nonexistent999xyz"
echo ""

# ============================================
# TEST 12: GET /analytics/{shortCode}
# ============================================
echo -e "${GREEN}[TEST 12] GET /analytics/{shortCode}${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/analytics/qatest001"
echo ""

# ============================================
# TEST 13: DELETE /{shortCode}
# ============================================
echo -e "${GREEN}[TEST 13] DELETE /{shortCode}${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -X DELETE "$BASE_URL/qatest001"
echo ""

# ============================================
# TEST 14: GET after DELETE
# ============================================
echo -e "${GREEN}[TEST 14] GET after DELETE (expect 404 or 410)${NC}"
curl -s -w "\nHTTP Status: %{http_code}\n" -I "$BASE_URL/qatest001"
echo ""

# ============================================
# TEST 15: Rate Limiting (31 rapid requests)
# ============================================
echo -e "${GREEN}[TEST 15] Rate Limiting - 31 Rapid Requests${NC}"
for i in $(seq 1 31); do
    status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/shorten" \
        -H "Content-Type: application/json" \
        -d "{\"url\": \"https://ratelimit-test-$i.com\"}")
    echo "Request $i: HTTP $status"
done
echo ""

# ============================================
# TEST 16: Same URL Multiple Times
# ============================================
echo -e "${GREEN}[TEST 16] Same URL Twice - Should Create Different Codes${NC}"
echo "First request:"
curl -s -X POST "$BASE_URL/shorten" -H "Content-Type: application/json" \
    -d '{"url": "https://duplicate-test.com"}' | grep -o '"shortCode":"[^"]*"'
echo "Second request:"
curl -s -X POST "$BASE_URL/shorten" -H "Content-Type: application/json" \
    -d '{"url": "https://duplicate-test.com"}' | grep -o '"shortCode":"[^"]*"'
echo ""

# ============================================
# TEST 17: Click Count Increment
# ============================================
echo -e "${GREEN}[TEST 17] Click Count Increment${NC}"
echo "Before clicks:"
curl -s "$BASE_URL/analytics/qatest001" | grep -o '"clickCount":[0-9]*'
echo "Triggering 3 redirects..."
curl -s -o /dev/null -I "$BASE_URL/qatest001"
curl -s -o /dev/null -I "$BASE_URL/qatest001"
curl -s -o /dev/null -I "$BASE_URL/qatest001"
echo "After clicks:"
curl -s "$BASE_URL/analytics/qatest001" | grep -o '"clickCount":[0-9]*'
echo ""

# ============================================
# TEST 18: Special Characters in URL
# ============================================
test_endpoint "Special Characters in URL" "POST" "$BASE_URL/shorten" \
    '{"url": "https://example.com/path?param=value&other=测试"}'

# ============================================
# TEST 19: Custom Alias - Invalid Characters
# ============================================
test_endpoint "Custom Alias - Invalid Characters (expect 400)" "POST" "$BASE_URL/shorten" \
    '{"url": "https://example.com", "customAlias": "invalid alias!@#"}'

# ============================================
# TEST 20: Custom Alias - Too Short
# ============================================
test_endpoint "Custom Alias - Too Short (expect 400)" "POST" "$BASE_URL/shorten" \
    '{"url": "https://example.com", "customAlias": "ab"}'

echo ""
echo "================================================"
echo "Testing Complete"
echo "================================================"
