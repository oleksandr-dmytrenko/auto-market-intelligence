import time
import redis
from typing import Optional

class RateLimiter:
    """Rate limiter using Redis to prevent hitting rate limits"""
    
    def __init__(self, redis_client: redis.Redis, max_requests: int = 10, window: int = 60):
        self.redis = redis_client
        self.max_requests = max_requests
        self.window = window
    
    def can_make_request(self, key: str) -> bool:
        """Check if we can make a request"""
        current = self.redis.get(key)
        if current is None or int(current) < self.max_requests:
            return True
        return False
    
    def record_request(self, key: str):
        """Record that a request was made"""
        pipe = self.redis.pipeline()
        pipe.incr(key)
        pipe.expire(key, self.window)
        pipe.execute()
    
    def wait_if_needed(self, key: str, base_delay: float = 1.0):
        """Wait if rate limit is reached"""
        if not self.can_make_request(key):
            time.sleep(base_delay * 2)
            return True
        return False




