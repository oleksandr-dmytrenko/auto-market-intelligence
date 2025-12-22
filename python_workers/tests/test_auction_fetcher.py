import pytest
from unittest.mock import Mock, patch, MagicMock
from workers.auction_fetcher import AuctionFetcher

class TestAuctionFetcher:
    def test_init(self, mock_rate_limiter):
        fetcher = AuctionFetcher(mock_rate_limiter)
        assert fetcher.rate_limiter == mock_rate_limiter

    def test_fetch_copart_listings(self, mock_auction_fetcher):
        filters = {'make': 'Toyota', 'model': 'Camry', 'year': 2020}
        result = mock_auction_fetcher.fetch_copart_listings(filters, limit=5)
        assert isinstance(result, list)

    def test_fetch_iaai_listings(self, mock_auction_fetcher):
        filters = {'make': 'Toyota', 'model': 'Camry', 'year': 2020}
        with patch('workers.auction_fetcher.IAAIScraper') as mock_scraper_class:
            mock_scraper = Mock()
            mock_scraper.scrape_listings.return_value = []
            mock_scraper_class.return_value = mock_scraper
            
            result = mock_auction_fetcher.fetch_iaai_listings(filters, limit=5)
            assert isinstance(result, list)

    def test_fetch_copart_listings_rate_limited(self, mock_auction_fetcher):
        mock_auction_fetcher.rate_limiter.wait_if_needed = Mock(return_value=True)
        filters = {'make': 'Toyota', 'model': 'Camry', 'year': 2020}
        result = mock_auction_fetcher.fetch_copart_listings(filters, limit=5)
        assert result == []

    def test_fetch_iaai_listings_rate_limited(self, mock_auction_fetcher):
        mock_auction_fetcher.rate_limiter.wait_if_needed = Mock(return_value=True)
        filters = {'make': 'Toyota', 'model': 'Camry', 'year': 2020}
        result = mock_auction_fetcher.fetch_iaai_listings(filters, limit=5)
        assert result == []

    def test_scan_all_iaai_listings(self, mock_auction_fetcher):
        with patch('workers.auction_fetcher.IAAIScraper') as mock_scraper_class:
            mock_scraper = Mock()
            mock_scraper.scrape_all_listings.return_value = []
            mock_scraper_class.return_value = mock_scraper
            
            result = mock_auction_fetcher.scan_all_iaai_listings(months_back=1, max_pages=1)
            assert isinstance(result, list)


