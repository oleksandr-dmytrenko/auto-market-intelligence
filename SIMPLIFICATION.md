# Architecture Simplification

## Goal
Make the architecture **flexible, scalable, and not too complex**.

## Changes Made

### Removed Sidekiq
**Why**: Sidekiq was only used to publish one message to Kafka - unnecessary complexity.

**Before**:
```
Controller → Sidekiq Job → Kafka Producer → Kafka
```

**After**:
```
Controller → Kafka Producer → Kafka
```

**Benefits**:
- One less service to run and maintain
- Simpler code path
- Fewer dependencies
- Still scalable (Kafka handles distribution)

### Simplified Services

**Removed**:
- ❌ Sidekiq service (Docker container)
- ❌ Sidekiq gem dependency
- ❌ Sidekiq configuration files
- ❌ `FindSimilarVehiclesJob` (ActiveJob)
- ❌ `JobOrchestrator` service

**Added**:
- ✅ `KafkaProducerService` - Simple, reusable Kafka producer

### Current Architecture

```
Telegram Bot
    ↓ HTTP
Rails API (Controller)
    ↓ Direct Kafka Publish
Kafka (scraping-jobs)
    ↓ Consumer Group
Python Workers (multiple instances)
    ↓ Kafka Publish
Kafka (vehicle-data)
    ↓ Consumer Group
Rails Kafka Consumer
    ↓ Database
PostgreSQL
```

## Benefits

### 1. Simplicity
- **Fewer moving parts**: Removed Sidekiq, Redis job queue
- **Direct communication**: Controller → Kafka (no intermediate queue)
- **Less code**: Removed job classes, orchestrators

### 2. Scalability
- **Kafka consumer groups**: Automatically distribute work across Python workers
- **Horizontal scaling**: Add more Python workers easily
- **Kafka partitioning**: Ensures ordering per query

### 3. Flexibility
- **Easy to add topics**: Just create new producer/consumer
- **Easy to add workers**: Just subscribe to Kafka topic
- **Easy to modify flow**: Change Kafka topics without touching job infrastructure

### 4. Maintainability
- **Single message broker**: All async communication via Kafka
- **Clear separation**: Each service has one responsibility
- **Less configuration**: No Sidekiq queues, Redis lists to manage

## Service Count

**Before**: 9 services (postgres, redis, zookeeper, kafka, rails_api, sidekiq, telegram_bot, python_workers, kafka_consumer)

**After**: 8 services (removed sidekiq)

## Dependencies

**Before**:
- Rails: Sidekiq, Redis, Kafka
- Python: Redis, Kafka

**After**:
- Rails: Redis (caching only), Kafka
- Python: Redis (rate limiting only), Kafka

## Redis Usage

**Before**: Caching + Job Queue + Rate Limiting

**After**: Caching + Rate Limiting only

## Kafka Topics

1. **`scraping-jobs`**: Rails → Python
   - Producer: Rails API (direct from controller)
   - Consumer: Python workers (consumer group: `python-workers`)

2. **`vehicle-data`**: Python → Rails
   - Producer: Python workers
   - Consumer: Rails API (consumer group: `rails-api-consumers`)

## Code Complexity

**Rails API**:
- Removed: ~50 lines (job class, orchestrator, Sidekiq config)
- Added: ~30 lines (simple Kafka producer service)
- **Net reduction**: ~20 lines + simpler flow

**Python Workers**:
- No changes (already simple)

## Performance

- **No impact**: Kafka handles message distribution efficiently
- **Better**: Direct publish (no Sidekiq overhead)
- **Same scalability**: Kafka consumer groups work the same

## Future Flexibility

Easy to add:
- More Kafka topics for different job types
- More Python worker types (just subscribe to different topics)
- More Rails consumers (just subscribe to different topics)
- Message routing based on content
- Dead letter queues in Kafka

## Conclusion

The architecture is now:
- ✅ **Simpler**: Removed unnecessary Sidekiq layer
- ✅ **Scalable**: Kafka handles all distribution
- ✅ **Flexible**: Easy to add new topics/consumers
- ✅ **Maintainable**: Fewer services, clearer responsibilities




