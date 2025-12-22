import pytest
from unittest.mock import Mock, MagicMock
import redis

@pytest.fixture
def mock_redis():
    mock = Mock(spec=redis.Redis)
    mock.get = Mock(return_value=None)
    mock.setex = Mock(return_value=True)
    mock.incr = Mock(return_value=1)
    mock.expire = Mock(return_value=True)
    mock.pipeline = Mock(return_value=Mock(execute=Mock()))
    return mock

@pytest.fixture
def mock_rate_limiter(mock_redis):
    from workers.rate_limiter import RateLimiter
    return RateLimiter(mock_redis)

@pytest.fixture
def mock_auction_fetcher(mock_rate_limiter):
    from workers.auction_fetcher import AuctionFetcher
    fetcher = AuctionFetcher(mock_rate_limiter)
    fetcher.driver = None
    return fetcher


