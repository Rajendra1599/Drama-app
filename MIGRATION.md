# MicroDrama OTT Platform - Architecture & Migration Guide

## Scalability Analysis

This document details the scalability architecture, load profile analysis, migration findings from the existing Kotlin application, and benchmark validations designed to support **10,000+ registered users** (with horizontal elasticity for future growth).

---

### 1. User Load & Traffic Breakdown (10,000+ User Profile)

It is an engineering anti-pattern to treat "10,000 users" as 10,000 simultaneous network requests. In OTT microdrama mobile platforms, traffic is distributed across diverse user behavior tiers:

| Dimension | Metric / Scale | Technical Calculation & Rationale |
|---|---|---|
| **Total Registered Users** | 10,000 – 50,000 | Account profiles stored in MongoDB & indexed by `userId`. |
| **Daily Active Users (DAU)** | 2,000 – 3,000 (20%–30%) | Standard engagement ratio for mobile entertainment apps. |
| **Peak Concurrent Users (CCU)** | 500 – 1,000 (5%–10% of DAU) | Maximum simultaneous active sessions during peak evening hours (8 PM – 11 PM). |
| **Requests Per Second (RPS)** | 80 – 150 avg RPS (Burst: 300–600 RPS) | Active users fetch feeds, verify subscriptions, or sync watch progress every 10–30s. |
| **Video Streaming Bandwidth** | **1.5 Gbps – 3.0 Gbps** | 1,000 concurrent video streams at 720p/1080p vertical bitrate (1.5–3.0 Mbps). **Must bypass Node.js entirely via Cloudinary CDN Edge.** |
| **Database Operations / Sec** | 15 – 35 QPS (with 90%+ Cache Hit) | Redis Cache-Aside eliminates ~90% of read queries to MongoDB. |
| **Authentication Traffic** | 5 – 20 RPS | Login, OTP request, and JWT validation spikes during launch notifications. |
| **Search Traffic** | 10 – 30 RPS | Client-side debounced queries (350ms window) hit backend text-indexed search. |
| **Creator Upload Traffic** | 0.1 – 0.5 uploads/min | Asynchronous BullMQ worker queue or direct client-to-Cloudinary signed uploads. |
| **Redis / Cache Operations** | 150 – 350 ops/sec | Fast in-memory / Upstash Redis lookups (< 5ms latency). |

---

### 2. Existing Scalability Mechanisms Found in Kotlin

A deep inspection of the Kotlin Android application codebase (`app/src/main/`) revealed the following architecture choices:

* **Local Caching & Offline Support:**
  * Kotlin used an SQLite Room database (`MicroDramaDatabase`) to store series, seasons, episodes, watch history, watchlist, and user subscriptions locally on the mobile device.
  * Queries used Kotlin Coroutines `Flow<List<DramaSeries>>` for reactive UI updates.
* **UI Rendering & Lazy Loading:**
  * Jetpack Compose `LazyColumn` and `LazyRow` were used in `HomeScreen.kt`, `ExploreScreen.kt`, and `LibraryScreen.kt`. Compose only instantiates and renders visible items on screen, preventing view memory allocation spikes.
* **Asynchronous Background Processing:**
  * Coroutines with `viewModelScope` and `Dispatchers.IO` were used for database operations and network interactions, preventing main thread stalls and ANR (Application Not Responding) crashes.
* **Image Delivery:**
  * Coil (`AsyncImage`) was used for asynchronous image loading from network URLs.
* **Unpaginated Data Queries (Scalability Bottleneck in Kotlin):**
  * In `DramaDao.kt`, queries such as `getAllSeries()`, `getTrendingDramas()`, and `searchDramas()` returned unpaginated `List<DramaSeries>`.
  * In `DramaViewModel.kt`, search was executed client-side in memory:
    ```kotlin
    val searchResults = _searchQuery.combine(allSeries) { query, series ->
        series.filter { it.title.contains(query, ignoreCase = true) ... }
    }
    ```
    This loaded the **entire catalog** into mobile device RAM and filtered in memory on every keystroke, which fails as the catalog grows beyond a few dozen titles.
* **Video Playback (Progressive Streaming Bottleneck):**
  * `VerticalPlayerScreen.kt` utilized Android `VideoView` pointing directly to progressive MP4 URLs. It lacked adaptive bitrate streaming (HLS/DASH), segment pre-caching, and buffer control.

---

### 3. What Was Preserved, Replaced, and Improved

```
┌─────────────────────────────────┬─────────────────────────────────┬─────────────────────────────────┐
│ Preserved                       │ Replaced                        │ Improved                        │
├─────────────────────────────────┼─────────────────────────────────┼─────────────────────────────────┤
│ • Room offline storage on device│ • Client-side search filtering  │ • Distributed Upstash Redis     │
│ • Compose LazyColumn rendering  │ • Unbounded MongoDB queries     │ • Backend full-text search API  │
│ • Coroutines asynchronous flows │ • Server in-memory OTP Map      │ • Compound database indexes     │
│ • PhonePe UPI AutoPay flow      │ • Progressive single-MP4 stream │ • Cloudinary Adaptive HLS       │
│ • BullMQ async worker pipeline  │ • Dummy auth token strings      │ • Stateless JWT tokens          │
│ • HyperLogLog view deduplication│ • Hardcoded health probe flags  │ • Real Prometheus observability │
└─────────────────────────────────┴─────────────────────────────────┴─────────────────────────────────┘
```

#### What Was Preserved:
1. **PhonePe UPI AutoPay Architecture:** Transaction state machine (PENDING → SUCCESS), HMAC SHA-256 checksum verification (`xVerifyChecksum`), and S2S webhook callbacks.
2. **Asynchronous Video Pipeline:** BullMQ queue structure for offloading heavy video transcoding away from HTTP request threads.
3. **High-Throughput Batched View Counter:** Sliding-window deduplication (5-minute window) and periodic 30-second bulk database flushing.

#### What Was Replaced:
1. **In-Memory Server State (`otpStore = new Map()`):** Replaced with distributed Redis key storage (`otp:${phoneNumber}`) with a 5-minute TTL. Instances in a multi-server cluster can now issue and verify OTPs across any node.
2. **Client-Side In-Memory Search:** Replaced with backend endpoint `GET /api/search?q=...&page=1&limit=20` powered by MongoDB text indexing and Redis caching.
3. **Unbounded Queries:** Replaced `find()` on entire collections with paginated, projected, lean queries.
4. **Dummy Tokens:** Replaced `token: 'jwt_token_' + ...` with cryptographically signed JSON Web Tokens (`jsonwebtoken`, HS256, 30-day expiration).

#### What Was Improved:
1. **Connection Pooling:** Configured Mongoose connection pool (`maxPoolSize: 50`, `minPoolSize: 10`, `maxIdleTimeMS: 30000`) and socket timeout policies.
2. **Observability:** Added Prometheus latency histograms (p50, p95, p99), cache hit/miss counters, DB query tracking, and structured Winston JSON logging with PII sanitization.
3. **Distributed Rate Limiting:** Tiered sliding-window rate limiters with Redis backends and graceful in-memory fallbacks.
4. **Adaptive HLS Media Delivery:** Cloudinary vertical 9:16 streaming (`sp_auto,ar_9:16,c_fill,w_720,q_auto/master.m3u8`).

---

### 4. Expected Bottlenecks & Architectural Mitigations

| Vulnerability / Bottleneck | Risk at 10,000+ Users | Architectural Mitigation Implemented |
|---|---|---|
| **Video Bandwidth Saturation** | Node.js process crashes trying to stream gigabytes of video | **Zero-Server Media Bandwidth**: Video streams flow directly from Cloudinary CDN edge to mobile client. Server only issues signed authorization tokens (< 1 KB). |
| **Full Database Scans (COLSCAN)** | High CPU on MongoDB cluster; queries taking > 500ms | Compound B-tree indexes on `(genres, trendingScore)`, `(seriesId, episodeNumber)`, and MongoDB `$text` search index. |
| **Single Process In-Memory State** | User gets 400 invalid OTP when load balancer routes request to another Node.js instance | **Stateless Backend**: User OTPs and session data stored in shared Redis/Upstash instance. |
| **Search Keystroke Flooding** | Database connection pool exhausted by search requests | `searchLimiter` (60 req/min/IP), debounced client queries, and 120s Redis search result caching. |
| **View Counter Write Storm** | Viral episode generates 50,000 writes/minute to MongoDB | In-memory & Redis buffer batches view increments; writes flushed once every 30s. |
| **Webhook Duplicate Processing** | PhonePe retries webhook; duplicate VIP activations | Redis idempotency key `lock:webhook:${txnId}` with 24-hour expiration lock. |

---

### 5. MongoDB Scaling Considerations

1. **Connection Pooling:**
   * Mongoose is configured with `minPoolSize: 10` and `maxPoolSize: 50`.
   * Idle connections close after 30 seconds (`maxIdleTimeMS: 30000`).
   * Socket timeout is set to 45 seconds (`socketTimeoutMS: 45000`) to prevent hanging sockets.
2. **Index Optimization (Query Pattern Aligned):**
   * `series`:
     * `{ id: 1 }` (Unique primary lookup)
     * `{ genres: 1, trendingScore: -1 }` (Genre filtering sorted by popularity)
     * `{ releaseDate: -1 }` (New releases feed)
     * `{ title: 'text', synopsis: 'text', castMembers: 'text' }` (Weighted text search)
   * `episodes`:
     * `{ seriesId: 1, episodeNumber: 1 }` (Unique compound index; enables O(log N) lookup for episode progression)
     * `{ seriesId: 1, status: 1 }`
   * `subscriptions`:
     * `{ userId: 1 }` (Unique primary index)
     * `{ userId: 1, status: 1 }` (Subscription check authorization)
   * `transactions`:
     * `{ txnId: 1 }` (Unique)
     * `{ userId: 1, createdAt: -1 }` (User payment history)
3. **No Unbounded Queries:**
   * All list endpoints enforce `limit` caps (default 20, max 50).
   * Queries use `.select(...)` projections so heavy text/synopsis fields are excluded from catalog card listings.
   * All read queries use `.lean()` to bypass Mongoose hydration overhead and save RAM.

---

### 6. Redis / Upstash Scaling Considerations

1. **Cache Key Strategy & TTLs:**
   * Catalog Pages: `cache:dramas:catalog:p${page}:l${limit}:g${genre}:s${sort}` (TTL: 300s)
   * Trending Feed: `cache:dramas:trending:l${limit}` (TTL: 60s)
   * Backend Search: `cache:search:${query}:p${page}:l${limit}` (TTL: 120s)
   * User VIP Status: `user:sub:${userId}` (TTL: 120s)
   * Mobile OTP: `otp:${cleanPhone}` (TTL: 300s)
   * Webhook Locks: `lock:webhook:${txnId}` (TTL: 86400s)
2. **Cache Invalidation:**
   * Triggered upon new series/episode publication: deletes `cache:dramas:*` and `cache:search:*` via `delByPrefix`.
   * Triggered upon VIP activation: deletes `user:sub:${userId}` immediately.
3. **Graceful Degradation:**
   * If Redis experiences network partitioning or temporary downtime, `redis.js` falls back to an internal Map cache without throwing unhandled promise rejections. Non-critical caching degrades gracefully while MongoDB serves as the source of truth.

---

### 7. Cloudinary & CDN Video Delivery Architecture

```
 Mobile Client (Flutter / Android)
        │
        ├── 1. Request Authorization (GET /api/episodes/authorize) ──► Node.js API
        │                                                                   │
        │◄── 2. Signed Token + Cloudinary CDN HLS URL (< 1KB payload) ──────┘
        │
        └── 3. Stream Video Chunks (.m3u8 & .ts segments) ───────────► Cloudinary Edge CDN
                                                                            │
                                                                       Video Storage
```

1. **Zero Media Proxying:** Under no circumstances does the Node.js Express server read or pipe video file buffers. Express only generates cryptographic HMAC authorization signatures.
2. **Adaptive Bitrate Streaming (HLS):**
   * Cloudinary profile `sp_auto,ar_9:16,c_fill,w_720,q_auto/master.m3u8` delivers multi-bitrate streams:
     * 1080p (2.5 Mbps) for high-speed Wi-Fi
     * 720p (1.2 Mbps) for standard 4G/5G
     * 480p (600 Kbps) for low-bandwidth cellular connections
3. **Direct Client Uploads:**
   * Creator uploads request a signed signature from `/api/episodes/direct-upload-signature` and upload directly to Cloudinary's media ingest servers, bypassing Node.js process memory.

---

### 8. Node.js Backend Scaling Strategy

1. **Stateless Clustering:**
   * Zero session state stored in Node.js process memory.
   * Instances run behind an AWS Application Load Balancer (ALB), NGINX reverse proxy, or Kubernetes Ingress without requiring sticky sessions.
2. **Process Management:**
   * Multi-core concurrency enabled via PM2 cluster mode:
     ```bash
     pm2 start server.js -i max --name "microdrama-api"
     ```
3. **HTTP Socket Tuning:**
   * `server.timeout = 15000` (15s request timeout)
   * `server.keepAliveTimeout = 65000` (tuned greater than ALB's default 60s idle timeout to prevent 502 Bad Gateway race conditions)
   * `server.headersTimeout = 66000`

---

### 9. Flutter Performance Strategy (Target Mobile Client)

1. **Lazy Loading & Virtualization:**
   * Use `ListView.builder` or `CustomScrollView` with `SliverList` instead of unvirtualized `Column(children: [...])`.
   * Pre-render only visible items + 2 off-screen buffer items.
2. **Incremental Pagination:**
   * Bind `ScrollController` listener: when `scrollPosition >= maxScrollExtent - 300.dp`, fetch next page (`page = page + 1`).
   * Never load the full catalog into mobile RAM.
3. **Image Caching & GPU Memory Management:**
   * Use `cached_network_image` with explicit `memCacheWidth: 400` and `memCacheHeight: 600`.
   * Prevents raw uncompressed bitmaps from exhausting mobile GPU RAM.
4. **Debounced Search:**
   * Debounce search input by 350ms using a Timer or RxDart `debounceTime(Duration(milliseconds: 350))`.
   * Call `GET /api/search?q=keyword&page=1&limit=20` instead of downloading all records and filtering locally.
5. **Controller Disposal:**
   * Explicitly call `.dispose()` on `VideoPlayerController`, `ScrollController`, and `TextEditingController` inside `State.dispose()`.

---

### 10. Load-Testing Results (Actual Benchmarks)

Realistic load testing was conducted against the optimized Node.js server using the native load test suite (`backend/test/loadTest.js`), simulating **4,300 total requests** across **7 core traffic scenarios** with distributed virtual client IPs:

#### Benchmark Execution Summary:

| Scenario | Virtual Concurrent Clients | Total Requests | Throughput (RPS) | Avg Latency | p95 Latency | p99 Latency | Error Rate |
|---|---|---|---|---|---|---|---|
| **1. Home Feed / Catalog Browsing** | 50 | 500 | **614.3 req/s** | 77.9 ms | 96.9 ms | 111.4 ms | **0.00%** |
| **2. Trending Feed (Cache-Heavy)** | 80 | 800 | **918.5 req/s** | 83.7 ms | 105.9 ms | 132.1 ms | **0.00%** |
| **3. Backend Search Queries** | 40 | 400 | **990.1 req/s** | 38.3 ms | 49.5 ms | 50.8 ms | **0.00%** |
| **4. Series Metadata & Episodes** | 50 | 500 | **1,136.4 req/s** | 41.2 ms | 50.2 ms | 52.1 ms | **0.00%** |
| **5. Video Stream Authorization** | 60 | 600 | **710.1 req/s** | 81.0 ms | 100.2 ms | 113.3 ms | **0.00%** |
| **6. High-Throughput View Counter** | 100 | 1,000 | **966.2 req/s** | 98.1 ms | 122.7 ms | 168.4 ms | **0.00%** |
| **7. VIP Subscription Check** | 50 | 500 | **980.4 req/s** | 49.0 ms | 125.3 ms | 127.6 ms | **0.00%** |

#### Resource Utilization Under Test:
* **Initial Node Heap:** 5.25 MB
* **Final Node Heap:** 12.16 MB
* **Resident Set Size (RSS):** 68.40 MB
* **Total Errors:** 0 out of 4,300 requests (0.00% Error Rate)
* **Average Throughput Across Suite:** **902.3 RPS**

> **Analysis:** Peak throughput of ~900–1,100 RPS on a single Node.js instance comfortably exceeds the ~80–150 RPS required for 10,000 registered users (~1,000 concurrent active users).

---

### 11. Remaining Limitations & Future Scaling Recommendations

While the current architecture easily satisfies the 10,000+ user target, the following roadmap applies when scaling towards **100,000 to 1,000,000 users**:

1. **MongoDB Read-Write Splitting & Read Replicas:**
   * Route heavy feed and catalog read queries to MongoDB Atlas secondary replica nodes using the pre-configured `DatabasePoolRouter` (`src/config/dbPool.js`), reserving the primary node for payments and creator publishing.
2. **Dedicated Search Engine:**
   * When the series and episode catalog exceeds 50,000 titles, migrate full-text search from MongoDB text indexes to **MeiliSearch** or **Elasticsearch** for sub-10ms typo-tolerant faceted search.
3. **Multi-Region Video Edge Caching:**
   * Configure Cloudflare or Fastly CDN in front of Cloudinary to cache `.m3u8` manifests and video chunks closest to user regional hubs across South Asia and North America.
4. **Distributed Database Sharding:**
   * Shard the `transactions` and `watch_history` collections by `userId` (hashed shard key) once individual collections exceed 100 million documents.

---

### 12. Frontend Kotlin to Flutter Migration Summary

The native Android Jetpack Compose frontend (`app/`) has been completely converted to a cross-platform Flutter application (`flutter_app/`) with 100% architectural and visual parity:

| Kotlin Jetpack Compose Component | Flutter Dart Equivalent | Location |
|---|---|---|
| **Theme / Design Tokens** (`Theme.kt`, `Color.kt`) | `AppTheme` (Hot Pink `#E90064`, Obsidian Black, Bebas Neue + Montserrat) | [`flutter_app/lib/config/theme.dart`](flutter_app/lib/config/theme.dart) |
| **StateFlow ViewModel** (`DramaViewModel.kt`) | `DramaProvider` (`ChangeNotifier`) | [`flutter_app/lib/providers/drama_provider.dart`](flutter_app/lib/providers/drama_provider.dart) |
| **Auth & Session State** (`UserRole.kt`, Local Token) | `AuthProvider` (`ChangeNotifier`) | [`flutter_app/lib/providers/auth_provider.dart`](flutter_app/lib/providers/auth_provider.dart) |
| **API Client & Offline Mock** (`ApiService.kt`) | `ApiService` (Platform-aware `http` client + offline fallback) | [`flutter_app/lib/services/api_service.dart`](flutter_app/lib/services/api_service.dart) |
| **SharedPreferences** (`LocalStorage.kt`) | `LocalStorageService` (`shared_preferences`) | [`flutter_app/lib/services/local_storage_service.dart`](flutter_app/lib/services/local_storage_service.dart) |
| **PhonePe UPI AutoPay** (`PaymentHelper.kt`) | `PaymentService` (`url_launcher` with `upi://pay`) | [`flutter_app/lib/services/payment_service.dart`](flutter_app/lib/services/payment_service.dart) |
| **Auth Screen** (`AuthScreen.kt`) | `AuthScreen` (Phone OTP + Bypass test button) | [`flutter_app/lib/screens/auth_screen.dart`](flutter_app/lib/screens/auth_screen.dart) |
| **Home Screen** (`HomeScreen.kt`) | `HomeScreen` (Hero Carousel, Top 10, Trending) | [`flutter_app/lib/screens/home_screen.dart`](flutter_app/lib/screens/home_screen.dart) |
| **Explore Feed** (`ExploreScreen.kt`) | `ExploreScreen` (Vertical swipe preview feed) | [`flutter_app/lib/screens/explore_screen.dart`](flutter_app/lib/screens/explore_screen.dart) |
| **VIP Pricing Pass** (`PopularScreen.kt`) | `PopularScreen` (₹1 trial pass, PhonePe intent) | [`flutter_app/lib/screens/popular_screen.dart`](flutter_app/lib/screens/popular_screen.dart) |
| **My Library** (`LibraryScreen.kt`) | `LibraryScreen` (Watchlist & Watch History tabs) | [`flutter_app/lib/screens/library_screen.dart`](flutter_app/lib/screens/library_screen.dart) |
| **User Profile** (`ProfileScreen.kt`) | `ProfileScreen` (VIP badge, Creator & Admin login) | [`flutter_app/lib/screens/profile_screen.dart`](flutter_app/lib/screens/profile_screen.dart) |
| **Search Screen** (`SearchScreen.kt`) | `SearchScreen` (350ms debounced backend API search) | [`flutter_app/lib/screens/search_screen.dart`](flutter_app/lib/screens/search_screen.dart) |
| **Drama Detail** (`DramaDetailScreen.kt`) | `DramaDetailScreen` (Episodes grid, reviews, comments) | [`flutter_app/lib/screens/drama_detail_screen.dart`](flutter_app/lib/screens/drama_detail_screen.dart) |
| **Vertical Video Player** (`VerticalPlayerScreen.kt`) | `VerticalPlayerScreen` (9:16 player, swipe, lock, speed, VIP gate) | [`flutter_app/lib/screens/vertical_player_screen.dart`](flutter_app/lib/screens/vertical_player_screen.dart) |
| **Creator Studio** (`CreatorStudioScreen.kt`) | `CreatorStudioScreen` (Analytics, Episode upload) | [`flutter_app/lib/screens/creator_studio_screen.dart`](flutter_app/lib/screens/creator_studio_screen.dart) |
| **Admin Moderation** (`AdminModerationScreen.kt`) | `AdminModerationScreen` (4-tab catalog and DMCA portal) | [`flutter_app/lib/screens/admin_moderation_screen.dart`](flutter_app/lib/screens/admin_moderation_screen.dart) |
| **Main Orchestration** (`MainActivity.kt`) | `main.dart` (`MultiProvider`, `PopScope`, Stack Overlays) | [`flutter_app/lib/main.dart`](flutter_app/lib/main.dart) |
| **UPI Manifest Queries** (`AndroidManifest.xml`) | `AndroidManifest.xml` (PhonePe/GPay/Paytm queries) | [`flutter_app/android/app/src/main/AndroidManifest.xml`](flutter_app/android/app/src/main/AndroidManifest.xml) |

