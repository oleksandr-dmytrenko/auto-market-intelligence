# Auto Market Intelligence - System Architecture

## Overview

The Auto Market Intelligence system is a **flexible, scalable, and simple** microservices architecture that analyzes used car prices and finds similar auction listings via a Telegram bot. The system uses Ruby on Rails for API orchestration, Python for data scraping, Kafka for all asynchronous messaging, and PostgreSQL for data persistence.

**Design Principles**: KISS (Keep It Simple), DRY (Don't Repeat Yourself), YAGNI (You Aren't Gonna Need It)

## System Components

### 1. Telegram Bot Service
- **Technology**: Ruby
- **Location**: `telegram_bot/`
- **Responsibilities**:
  - Handles user interactions via Telegram
  - Parses user input (car filters: make, model, year, mileage, color, damage type)
  - Sends requests to Rails API
  - Formats and displays results to users
  - Manages conversation state

### 2. Rails API
- **Technology**: Ruby on Rails 7.1
- **Location**: `rails_api/`
- **Responsibilities**:
  - Request validation and normalization
  - Price calculation (average/median with confidence metrics)
  - Database access (only component that interacts with PostgreSQL)
  - Job orchestration via Sidekiq
  - Kafka consumer for processing vehicle data
  - RESTful API endpoints

### 3. Python Workers
- **Technology**: Python 3.11
- **Location**: `python_workers/`
- **Responsibilities**:
  - Scrapes auction sites (Copart, IAAI)
  - Returns raw scraped data (no normalization, no business logic)
  - Publishes raw data to Kafka topics
  - Rate limiting and anti-bot protection

### 4. PostgreSQL Database
- **Version**: PostgreSQL 15
- **Responsibilities**:
  - Primary data store
  - Stores users, queries, vehicles, similarity matches, and auction listings
  - Only accessible by Rails API

### 5. Redis
- **Version**: Redis 7
- **Responsibilities**:
  - Caching layer for price calculations
  - Rate limiting counters for Python scrapers

### 6. Kafka
- **Version**: Confluent Kafka 7.5.0
- **Responsibilities**:
  - Message broker for asynchronous communication
  - Decouples Python workers from Rails API
  - Provides message persistence and replay capability

### 7. Zookeeper
- **Version**: Confluent Zookeeper 7.5.0
- **Responsibilities**:
  - Required for Kafka cluster coordination
  - Manages Kafka broker metadata


## Architecture Diagram

```
┌─────────────┐
│   User      │
└──────┬──────┘
       │ Telegram Messages
       ▼
┌─────────────────┐
│  Telegram Bot   │
│    (Ruby)        │
└──────┬───────────┘
       │ HTTP REST API
       ▼
┌─────────────────┐         ┌──────────────┐
│   Rails API     │────────▶│  PostgreSQL  │
│   (Rails 7.1)   │         │   Database   │
└──────┬──────────┘         └──────────────┘
       │
       │ Enqueue Job
       ▼
┌─────────────────┐
│   Rails API     │
│  (Controller)   │
└──────┬──────────┘
       │
       │ Publish Job
       ▼
┌─────────────┐
│    Kafka    │
│scraping-jobs│
└──────┬──────┘
       │
       │ Consume Jobs
       ▼
┌─────────────────┐
│ Python Workers  │
│  (Scrapers)     │
└──────┬──────────┘
       │
       │ Publish Results
       ▼
┌─────────────┐
│    Kafka    │
│vehicle-data │
└──────┬──────┘
       │
       │ Consume Results
       ▼
┌─────────────────┐         ┌──────────────┐
│ Kafka Consumer  │────────▶│  PostgreSQL  │
│  (Rails API)    │         │   Database   │
└─────────────────┘         └──────────────┘
```

## Data Flow

### 1. User Request Flow

```
User → Telegram Bot → Rails API → Redis Queue → Python Workers
                                                      │
                                                      ▼
                                              Auction Sites (Copart/IAAI)
                                                      │
                                                      ▼
                                              Kafka Topics
                                                      │
                                                      ▼
                                              Kafka Consumer (Rails)
                                                      │
                                                      ▼
                                              PostgreSQL Database
                                                      │
                                                      ▼
                                              Telegram Bot → User
```

### 2. Detailed Step-by-Step Flow

1. **User Input**: User sends car filters to Telegram bot
   - Format: Make, Model, Year, Mileage, Color, Damage Type

2. **Telegram Bot Processing**:
   - Parses user input
   - Validates required fields (Make, Model, Year)
   - Sends HTTP POST to Rails API `/api/queries`

3. **Rails API Processing**:
   - Validates and normalizes filters
   - Creates `PriceQuery` record in database
   - Calculates average/median price from existing vehicle data
   - Publishes scraping job directly to Kafka `scraping-jobs` topic
   - Returns initial price result to Telegram bot

4. **Kafka Job Distribution**:
   - Kafka `scraping-jobs` topic distributes jobs to Python workers

5. **Python Worker Processing**:
   - Worker consumes job from Kafka `scraping-jobs` topic
   - Scrapes auction sites (Copart, IAAI) with rate limiting
   - Returns raw scraped data (no normalization, no scoring)
   - Publishes raw vehicle data to Kafka `vehicle-data` topic

6. **Kafka Message Processing**:
   - Kafka stores messages in `vehicle-data` topic
   - Messages are partitioned by `query_id` for ordering

7. **Rails Kafka Consumer**:
   - Consumer processes messages from `vehicle-data` topic
   - Normalizes raw vehicle data
   - Calculates similarity scores
   - Ranks vehicles
   - Creates/updates `Vehicle` records
   - Creates `SimilarityMatch` records
   - Creates `AuctionListing` records
   - Updates `PriceQuery` status to `completed`

8. **Result Retrieval**:
   - Telegram bot polls Rails API for results
   - Rails API returns formatted list of similar vehicles
   - Bot displays results to user

## Database Schema

### Core Tables

#### `users`
- `id` (UUID, primary key)
- `telegram_id` (bigint, unique, indexed)
- `username` (string)
- `created_at`, `updated_at`

#### `price_queries`
- `id` (UUID, primary key)
- `user_id` (UUID, foreign key)
- `make`, `model`, `year` (indexed)
- `mileage`, `color`, `damage_type`, `production_year`
- `normalized_filters` (JSONB)
- `average_price`, `median_price`, `price_confidence`
- `status` (enum: pending, calculating, completed, failed)
- `created_at`, `updated_at`

#### `vehicles`
- `id` (UUID, primary key)
- `source`, `source_id` (unique index)
- `make`, `model`, `year` (indexed)
- `mileage`, `color`, `damage_type`, `production_year`
- `price`, `location`, `auction_url`
- `raw_data` (JSONB)
- `normalized_at`, `created_at`, `updated_at`

#### `similarity_matches`
- `id` (UUID, primary key)
- `price_query_id` (UUID, foreign key, indexed)
- `vehicle_id` (UUID, foreign key, indexed)
- `similarity_score` (decimal, indexed)
- `rank` (integer)
- `created_at`

#### `auction_listings`
- `id` (UUID, primary key)
- `price_query_id` (UUID, foreign key, indexed)
- `vehicle_id` (UUID, foreign key)
- `auction_platform` (string: 'copart', 'iaai')
- `listing_url` (string)
- `estimated_price`, `similarity_score`
- `rank` (integer)
- `created_at`

## Kafka Topics

### `scraping-jobs`
- **Purpose**: Jobs for Python workers to scrape vehicles
- **Key**: `query_id` (for partitioning)
- **Value**: JSON containing query_id and filters
- **Producer**: Rails API (Sidekiq job)
- **Consumer**: Python workers
- **Partitioning**: By query_id ensures ordering per query

### `vehicle-data`
- **Purpose**: Raw vehicle data from Python workers
- **Key**: `query_id` (for partitioning)
- **Value**: JSON containing query_id and array of raw vehicles
- **Producer**: Python workers
- **Consumer**: Rails API Kafka Consumer
- **Partitioning**: By query_id ensures all vehicles for a query go to same partition

Note: Failure handling is done by updating query status directly in the database when processing errors occur.

## Similarity Scoring Algorithm

The system uses a priority-based scoring algorithm (0-100 scale):

### Tier 1: Make/Model/Year (60% weight)
- Make match: +20 points
- Model match: +20 points
- Year exact match: +20 points
- Year within ±2 years: +10 points

### Tier 2: Mileage (25% weight)
- Within 10%: +25 points
- Within 25%: +15 points
- Within 50%: +5 points

### Tier 3: Damage Type (10% weight)
- Exact match: +10 points

### Tier 4: Color (5% weight)
- Exact match: +5 points

## Caching Strategy

### Redis Caching
- **Price Cache**: `price:make:model:year:color:damage` → average price (TTL: 24h)
- **Query Cache**: `query:hash(filters)` → query_id (TTL: 1h)
- **Rate Limiting**: `rate_limit:scraper:platform` → request count (sliding window)

## Rate Limiting & Anti-Bot Protection

### Python Workers
- **Rotating User-Agents**: Pool of realistic browser user agents
- **Request Delays**: Exponential backoff between requests
- **Redis Rate Limiter**: Tracks requests per domain/IP
- **Session Management**: Maintains cookies/sessions where needed

## Error Handling

### Python Workers
- Simple error handling - logs errors
- No business logic - just scrapes and sends raw data

### Rails API
- Transaction-based processing in Kafka consumer
- Rollback on validation errors
- Updates query status to `failed` on errors
- Comprehensive error logging

## Scalability Considerations

### Horizontal Scaling
- **Python Workers**: Can run multiple instances (stateless)
- **Kafka Consumers**: Can run multiple instances in same consumer group
- **Rails API**: Can run multiple instances behind load balancer

### Kafka Partitioning
- Messages partitioned by `query_id` ensures ordering per query
- Allows parallel processing of different queries
- Enables horizontal scaling of consumers

## Security

### Data Protection
- Strong parameters in Rails controllers
- Input validation and normalization
- SQL injection prevention via ActiveRecord
- UUID primary keys prevent enumeration attacks

### Service Communication
- Internal services communicate via Docker network
- Kafka topics are internal (not exposed externally)
- API endpoints use standard HTTP security practices

## Deployment

### Docker Compose Services
- `postgres`: PostgreSQL database
- `redis`: Redis cache and job queue
- `zookeeper`: Kafka coordination
- `kafka`: Message broker
- `rails_api`: Rails API server
- `sidekiq`: Background job processor
- `telegram_bot`: Telegram bot service
- `python_workers`: Python scraping workers
- `kafka_consumer`: Rails Kafka consumer

### Environment Variables
- `TELEGRAM_BOT_TOKEN`: Telegram bot authentication
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `KAFKA_BROKERS`: Kafka broker addresses
- `RAILS_ENV`: Rails environment

## Monitoring & Observability

### Logging
- All services log to stdout/stderr
- Rails logs include request IDs and error traces
- Python workers log scraping progress and errors
- Kafka consumer logs message processing

### Health Checks
- Rails API: `/up` endpoint
- PostgreSQL: `pg_isready` check
- Redis: `redis-cli ping` check
- Kafka: `kafka-broker-api-versions` check

## Future Enhancements

### Potential Improvements
1. **Message Queue Migration**: Consider moving job queue from Redis to Kafka
2. **Monitoring**: Add Prometheus metrics and Grafana dashboards
3. **Caching**: Implement more sophisticated caching strategies
4. **Search**: Add Elasticsearch for advanced vehicle search
5. **ML Models**: Replace rule-based similarity with ML models
6. **API Rate Limiting**: Add rate limiting to Rails API endpoints
7. **Webhooks**: Replace polling with webhooks for real-time updates

## Technology Stack Summary

| Component | Technology | Version |
|-----------|-----------|---------|
| API Framework | Ruby on Rails | 7.1 |
| Database | PostgreSQL | 15 |
| Cache/Queue | Redis | 7 |
| Message Broker | Kafka | 7.5.0 |
| Background Jobs | Sidekiq | 7.2 |
| Scraping | Python | 3.11 |
| Bot Framework | Telegram Bot API | - |
| Containerization | Docker Compose | 3.8 |

## Conclusion

This architecture provides a scalable, maintainable, and production-ready system for analyzing car prices and finding similar auction listings. The use of Kafka for asynchronous messaging ensures loose coupling between services and enables horizontal scaling. The clear separation of concerns (Rails for orchestration, Python for scraping, Kafka for messaging) makes the system easy to maintain and extend.

