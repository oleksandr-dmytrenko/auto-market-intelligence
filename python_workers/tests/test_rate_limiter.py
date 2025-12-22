import pytest
import time
from unittest.mock import Mock, patch
from workers.rate_limiter import RateLimiter

class TestRateLimiter:
    def test_init(self, mock_redis):
        limiter = RateLimiter(mock_redis, max_requests=10, window=60)
        assert limiter.max_requests == 10
        assert limiter.window == 60
        assert limiter.redis == mock_redis

    def test_can_make_request_when_under_limit(self, mock_redis):
        mock_redis.get.return_value = None
        limiter = RateLimiter(mock_redis, max_requests=10, window=60)
        assert limiter.can_make_request('test_key') is True

    def test_can_make_request_when_at_limit(self, mock_redis):
        mock_redis.get.return_value = '10'
        limiter = RateLimiter(mock_redis, max_requests=10, window=60)
        assert limiter.can_make_request('test_key') is False

    def test_can_make_request_when_below_limit(self, mock_redis):
        mock_redis.get.return_value = '5'
        limiter = RateLimiter(mock_redis, max_requests=10, window=60)
        assert limiter.can_make_request('test_key') is True

    def test_record_request(self, mock_redis):
        mock_pipeline = Mock()
        mock_pipeline.incr = Mock(return_value=mock_pipeline)
        mock_pipeline.expire = Mock(return_value=mock_pipeline)
        mock_pipeline.execute = Mock()
        mock_redis.pipeline.return_value = mock_pipeline
        
        limiter = RateLimiter(mock_redis)
        limiter.record_request('test_key')
        
        mock_pipeline.incr.assert_called_once_with('test_key')
        mock_pipeline.expire.assert_called_once_with('test_key', 60)
        mock_pipeline.execute.assert_called_once()

    def test_wait_if_needed_when_can_make_request(self, mock_redis):
        mock_redis.get.return_value = None
        limiter = RateLimiter(mock_redis)
        assert limiter.wait_if_needed('test_key') is False

    @patch('time.sleep')
    def test_wait_if_needed_when_cannot_make_request(self, mock_sleep, mock_redis):
        mock_redis.get.return_value = '10'
        limiter = RateLimiter(mock_redis, max_requests=10)
        result = limiter.wait_if_needed('test_key', base_delay=1.0)
        assert result is True
        mock_sleep.assert_called_once_with(2.0)


