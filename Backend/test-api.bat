@echo off
REM URL Shortener - QA Test Script
REM Requires: Backend running on http://localhost:8080, MySQL on localhost:3306

echo ================================================
echo URL Shortener - API Testing Suite
echo ================================================
echo.

set BASE_URL=http://localhost:8080

REM ============================================
REM TEST 1: Health Check
REM ============================================
echo [TEST 1] Health Check
curl -s -w "\nHTTP Status: %%{http_code}\n\n" %BASE_URL%/api/health
echo.

REM ============================================
REM TEST 2: POST /shorten - Valid URL
REM ============================================
echo [TEST 2] POST /shorten - Valid URL
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{\"url\": \"https://www.google.com/search?q=testing\"}"
echo.

REM ============================================
REM TEST 3: POST /shorten - Invalid URL (no protocol)
REM ============================================
echo [TEST 3] POST /shorten - Invalid URL (no http/https)
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{\"url\": \"not-a-valid-url\"}"
echo.

REM ============================================
REM TEST 4: POST /shorten - Empty URL
REM ============================================
echo [TEST 4] POST /shorten - Empty URL
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{\"url\": \"\"}"
echo.

REM ============================================
REM TEST 5: POST /shorten - Missing URL field
REM ============================================
echo [TEST 5] POST /shorten - Missing URL field
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{}"
echo.

REM ============================================
REM TEST 6: POST /shorten - Very Long URL
REM ============================================
echo [TEST 6] POST /shorten - Very Long URL (5000 chars)
set LONG_URL=https://example.com/%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%%~RANDOM%
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{\"url\": \"%LONG_URL%\"}"
echo.

REM ============================================
REM TEST 7: POST /shorten - With Custom Alias
REM ============================================
echo [TEST 7] POST /shorten - With Custom Alias
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{\"url\": \"https://github.com\", \"customAlias\": \"mytestlink\"}"
echo.

REM ============================================
REM TEST 8: POST /shorten - Duplicate Custom Alias
REM ============================================
echo [TEST 8] POST /shorten - Duplicate Custom Alias (should fail)
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{\"url\": \"https://twitter.com\", \"customAlias\": \"mytestlink\"}"
echo.

REM ============================================
REM TEST 9: POST /shorten - With Expiry
REM ============================================
echo [TEST 9] POST /shorten - With Expiry (30 days)
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X POST %BASE_URL%/shorten ^
  -H "Content-Type: application/json" ^
  -d "{\"url\": \"https://stackoverflow.com\", \"expiryDays\": 30}"
echo.

REM ============================================
REM TEST 10: GET /{shortCode} - Valid Redirect
REM ============================================
echo [TEST 10] GET /{shortCode} - Valid Redirect
curl -s -w "\nHTTP Status: %%{http_code}\nRedirect: %%{redirect_url}\n\n" -I %BASE_URL%/mytestlink
echo.

REM ============================================
REM TEST 11: GET /{shortCode} - Invalid Code (404)
REM ============================================
echo [TEST 11] GET /{shortCode} - Invalid Code (should 404)
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -I %BASE_URL%/nonexistent123
echo.

REM ============================================
REM TEST 12: GET /analytics/{shortCode}
REM ============================================
echo [TEST 12] GET /analytics/{shortCode}
curl -s -w "\nHTTP Status: %%{http_code}\n\n" %BASE_URL%/analytics/mytestlink
echo.

REM ============================================
REM TEST 13: DELETE /{shortCode} - Deactivate
REM ============================================
echo [TEST 13] DELETE /{shortCode} - Deactivate
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -X DELETE %BASE_URL%/mytestlink
echo.

REM ============================================
REM TEST 14: GET after DELETE - Should 404
REM ============================================
echo [TEST 14] GET after DELETE - Should return 404 or 410
curl -s -w "\nHTTP Status: %%{http_code}\n\n" -I %BASE_URL%/mytestlink
echo.

REM ============================================
REM TEST 15: Rate Limiting Test (31 rapid requests)
REM ============================================
echo [TEST 15] Rate Limiting Test (31 rapid requests)
for /L %%i in (1,1,31) do (
    curl -s -o nul -w "Request %%i: %%{http_code}\n" -X POST %BASE_URL%/shorten -H "Content-Type: application/json" -d "{\"url\": \"https://test%%i.com\"}"
)
echo.

REM ============================================
REM TEST 16: Duplicate URL (same URL twice)
REM ============================================
echo [TEST 16] POST - Same URL Twice (should create 2 different short codes)
for /L %%i in (1,1,2) do (
    curl -s -w "Request %%i: %%{http_code}\n" -X POST %BASE_URL%/shorten -H "Content-Type: application/json" -d "{\"url\": \"https://duplicate-test.com\"}" | findstr /C:"shortCode"
)
echo.

REM ============================================
echo ================================================
echo Testing Complete
echo ================================================
pause
