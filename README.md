# URL Shortener Application

A production-ready URL shortener service built with Java Spring Boot and React.

## Features

- **URL Shortening**: Generate compact short codes using Base62 encoding
- **Custom Aliases**: Support for user-defined short codes (3-20 alphanumeric characters)
- **Expiry Support**: Optional expiration date for temporary links
- **Analytics**: Track click counts per shortened URL
- **Rate Limiting**: Per-IP rate limiting (30 requests/minute, 100/hour)
- **CORS Enabled**: Ready for frontend integration

## Tech Stack

- **Backend**: Java 17, Spring Boot 3.2, JPA/Hibernate, MySQL
- **Frontend**: React 18, CSS3
- **Database**: MySQL 8.0

## Quick Start

### Prerequisites

- Java 17+
- Maven 3.6+
- Node.js 16+
- MySQL 8.0+

### Database Setup

```sql
CREATE DATABASE urlshortener;
```

### Backend

```bash
cd Backend
./mvnw spring-boot:run
```

Or with Maven:
```bash
mvn spring-boot:run
```

### Frontend

```bash
cd Frontend
npm install
npm start
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/shorten` | Create short URL |
| GET | `/{shortCode}` | Redirect to original URL |
| GET | `/analytics/{shortCode}` | Get URL analytics |
| DELETE | `/{shortCode}` | Deactivate URL |
| GET | `/api/health` | Health check |

### POST /shorten

**Request:**
```json
{
  "url": "https://example.com/very/long/url",
  "customAlias": "my-link",     // optional
  "expiryDays": 30              // optional
}
```

**Response:**
```json
{
  "shortCode": "my-link",
  "shortUrl": "http://localhost:8080/my-link",
  "originalUrl": "https://example.com/very/long/url",
  "createdAt": "2026-04-02T10:30:00",
  "expiry": "2026-05-02T10:30:00",
  "clickCount": 0
}
```

---

## Deployment Guide

### Backend: Render

1. **Create Render Account**: Sign up at [render.com](https://render.com)

2. **Create a Web Service**:
   - Connect your GitHub repository
   - Select "Backend" folder
   - Configure:
     - **Root Directory**: `Backend`
     - **Build Command**: `./mvnw package -DskipTests`
     - **Start Command**: `java -jar target/url-shortener-1.0.0.jar`

3. **Environment Variables** (in Render dashboard):
   ```
   DATABASE_URL=mysql://user:password@host:3306/urlshortener
   DATABASE_USERNAME=your_db_user
   DATABASE_PASSWORD=your_db_password
   APP_BASE_URL=https://your-backend.onrender.com
   ALLOWED_ORIGINS=https://your-github-username.github.io
   SPRING_PROFILES_ACTIVE=prod
   ```

4. **MySQL on Render**:
   - Create a Render MySQL instance (or use a cloud provider like PlanetScale, Railway, or Neon)
   - Get the connection string and set as `DATABASE_URL`

### Frontend: GitHub Pages

1. **Update Configuration**:
   - Edit `Frontend/.env.production`:
     ```
     REACT_APP_API_URL=https://your-backend.onrender.com
     ```
   - Update `package.json`:
     ```json
     "homepage": "https://your-github-username.github.io/url-shortener"
     ```

2. **Deploy**:
   ```bash
   cd Frontend
   npm run build
   ```

3. **GitHub Pages Setup**:
   - Go to repository **Settings** > **Pages**
   - Source: Deploy from a branch
   - Branch: `gh-pages` /root

4. **Using gh-pages**:
   ```bash
   npm install --save-dev gh-pages
   ```

   Add to `package.json`:
   ```json
   "scripts": {
     "deploy": "npm run build && gh-pages -d build"
   }
   ```

---

## System Design: Scaling to Millions

### Current Architecture (Single Instance)

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│   Browser   │────▶│   Load Balancer │────▶│  Backend    │
└─────────────┘     └─────────────────┘     │  (Spring)   │
                                            └──────┬──────┘
                                                   │
                                            ┌──────▼──────┐
                                            │   MySQL     │
                                            └─────────────┘
```

### Scaling Strategies

#### 1. **Caching (Redis)**
```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
┌──────▼──────┐     ┌─────────────┐     ┌─────────────┐
│   CDN/Edge  │────▶│ Load Balancer│────▶│  Backend    │
└─────────────┘     └─────────────┘     │  Cluster    │
                                        └──────┬──────┘
                                               │
                                        ┌──────▼──────┐
                                        │    Redis    │◀── Cache hits (95%)
                                        │   Cluster   │
                                        └──────┬──────┘
                                               │
                                        ┌──────▼──────┐
                                        │   MySQL     │◀── Persistent
                                        │   Primary   │
                                        └─────────────┘
```

**Cache Strategy:**
- Cache hot URLs (top 1% get 99% of traffic)
- TTL: Match URL expiry or 24 hours default
- Invalidate on URL deactivation

#### 2. **Database Sharding**

Sharding by `shortCode` hash:
```
Shard Key = hash(shortCode) % num_shards
```

| Shard | Range | Example Codes |
|-------|-------|---------------|
| 0 | a-f | `abc123`, `xyz789` |
| 1 | g-n | `google`, `help42` |
| 2 | o-u | `store`, `user1` |
| 3 | v-z | `video`, `zipfile` |

#### 3. **Read Replicas**

```
Write ──▶ Primary DB
          │
          ├──▶ Replica 1 (reads)
          ├──▶ Replica 2 (reads)
          └──▶ Replica 3 (reads)
```

#### 4. **Global Distribution**

```
┌─────────────────────────────────────────────────────┐
│                   Cloudflare CDN                     │
└─────────────────────┬───────────────────────────────┘
                      │
     ┌────────────────┼────────────────┐
     ▼                ▼                ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│  US-E   │    │  EU-W   │    │  AP-SE  │
│ Pop     │    │ Pop     │    │ Pop     │
└────┬────┘    └────┬────┘    └────┬────┘
     │              │              │
     └──────────────┼──────────────┘
                    ▼
            ┌─────────────┐
            │   Backend   │
            │   Cluster   │
            └──────┬──────┘
                   │
          ┌────────┴────────┐
          ▼                 ▼
    ┌──────────┐      ┌──────────┐
    │  MySQL   │      │  Redis   │
    │ Primary  │      │  Cache   │
    └──────────┘      └──────────┘
```

### Capacity Calculations

| Metric | Single Instance | Scaled (10 nodes) |
|--------|-----------------|-------------------|
| URLs Created | ~100/sec | ~1,000/sec |
| Redirects | ~1,000/sec | ~50,000/sec |
| Storage (10M URLs) | ~2 GB | Sharded |
| Memory (Redis) | ~5 GB hot | Distributed |

### Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| **Redis Cache** | Fast reads | Extra infrastructure cost |
| **DB Sharding** | Horizontal scale | Complex queries, rebalancing hard |
| **Read Replicas** | Offload reads | Replication lag |
| **CDN** | Low latency globally | Cost, cache invalidation |

---

## Database Schema

```sql
CREATE TABLE url_mappings (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    short_code VARCHAR(20) NOT NULL UNIQUE,
    original_url VARCHAR(2048) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiry TIMESTAMP NULL,
    click_count BIGINT NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT TRUE,

    INDEX idx_short_code (short_code),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB;
```

### Optimization Notes
- `short_code` is the primary lookup key - indexed
- `active` flag for soft deletes (avoid expensive DELETEs)
- `click_count` denormalized to avoid JOIN on analytics
- `created_at` indexed for time-based queries

---

## Resume Improvements

1. **Add User Authentication**
   - Spring Security + JWT
   - User-owned URLs dashboard
   - API keys for developers

2. **QR Code Generation**
   - Generate QR codes for each shortened URL
   - Use `ZXing` library

3. **URL Tags & Categories**
   - Group URLs by campaign, project, etc.

4. **Browser Extension**
   - One-click shortening from browser toolbar

5. **API Rate Tiers**
   - Free: 100/day
   - Pro: 10,000/day
   - Enterprise: Unlimited

6. **Real-time Analytics Dashboard**
   - Live click tracking
   - Geographic data
   - Referrer analysis

---

## Interview Talking Points

### "How would you handle 1M concurrent redirects?"

**Answer**: Cache hot URLs in Redis (90% of traffic is top 10% of URLs). Use CDN at edge for global distribution. Scale backend horizontally behind load balancer. Use read replicas for database.

### "How does Base62 encoding work?"

**Answer**: Encode a unique number (like auto-increment ID) using 62 characters (0-9, A-Z, a-z). For 7 characters: 62^7 = 3.5 trillion combinations. We use random generation with collision detection.

### "What happens when two users pick the same custom alias?"

**Answer**: Unique constraint on `short_code` column. When collision detected, return HTTP 409 Conflict with message to try another alias.

### "How would you prevent abuse?"

**Answer**: Rate limiting per IP (token bucket). CAPTCHA for suspicious patterns. User authentication for higher limits. Monitor and block malicious actors.

### "Database design for billions of URLs?"

**Answer**: Sharding by hash of short_code. Each shard is independent with its own connection pool. For analytics, use a separate OLAP system (ClickHouse, BigQuery) that receives async events from message queue.

---

## Project Structure

```
URL Shortner app/
├── Backend/
│   ├── src/main/java/com/urlshortener/
│   │   ├── config/         # CORS, Security, etc.
│   │   ├── controller/      # REST endpoints
│   │   ├── dto/            # Request/Response objects
│   │   ├── entity/         # JPA entities
│   │   ├── exception/      # Custom exceptions
│   │   ├── repository/      # Data access
│   │   └── service/        # Business logic
│   └── src/main/resources/
│       ├── application.yml         # Dev config
│       └── application-prod.yml    # Production config
│
└── Frontend/
    ├── src/
    │   ├── App.js           # Main component
    │   ├── App.css          # Styles
    │   └── index.js         # Entry point
    ├── public/
    └── package.json
```

## Environment Variables

### Backend (Development)
```bash
MYSQL_PASSWORD=your_password
```

### Backend (Production - Render)
```bash
DATABASE_URL=mysql://user:pass@host:3306/db
DATABASE_USERNAME=user
DATABASE_PASSWORD=pass
APP_BASE_URL=https://your-app.onrender.com
ALLOWED_ORIGINS=https://username.github.io
SPRING_PROFILES_ACTIVE=prod
PORT=8080
```

### Frontend (Production)
```bash
REACT_APP_API_URL=https://your-backend.onrender.com
```
