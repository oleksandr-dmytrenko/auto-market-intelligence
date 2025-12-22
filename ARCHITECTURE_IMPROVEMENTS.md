# Architecture Improvements

## Changes Made

### Simplified Communication Flow

**Before:**
```
Rails → Redis List → Python → Kafka → Rails
```

**After:**
```
Rails → Kafka (scraping-jobs) → Python → Kafka (vehicle-data) → Rails
```

### Benefits

1. **Unified Message Broker**: All async communication via Kafka
2. **Removed Redis Dependency**: Redis only used for caching and Sidekiq (Rails internal)
3. **Better Scalability**: Kafka consumer groups allow multiple Python workers
4. **Simpler Architecture**: One message broker instead of two
5. **Better Monitoring**: All messages in Kafka, easier to track

### What Changed

#### Rails API
- `FindSimilarVehiclesJob` now publishes to Kafka `scraping-jobs` topic
- Removed Redis list `python_jobs:find_similar`
- Removed `python_jobs` queue from Sidekiq config

#### Python Workers
- Now consumes from Kafka `scraping-jobs` topic (instead of Redis)
- Uses Kafka consumer groups for load balancing
- Still publishes to `vehicle-data` topic

#### Redis Usage
- **Kept for**: Sidekiq (Rails internal jobs), caching, rate limiting
- **Removed from**: Python job queue

### Kafka Topics

1. **`scraping-jobs`**: Jobs from Rails to Python workers
   - Producer: Rails API
   - Consumer: Python workers (consumer group: `python-workers`)

2. **`vehicle-data`**: Raw vehicle data from Python to Rails
   - Producer: Python workers
   - Consumer: Rails API (consumer group: `rails-api-consumers`)

### Migration Notes

- No data migration needed
- Python workers will automatically start consuming from Kafka
- Old Redis list can be safely removed
- Both systems can run in parallel during transition




