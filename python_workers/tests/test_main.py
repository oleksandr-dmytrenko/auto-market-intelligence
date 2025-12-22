import pytest
from unittest.mock import Mock, patch, MagicMock
from workers.main import Worker

class TestWorker:
    @patch('workers.main.redis')
    @patch('workers.main.KafkaProducer')
    @patch('workers.main.KafkaConsumer')
    def test_init(self, mock_consumer, mock_producer, mock_redis):
        mock_redis_client = Mock()
        mock_redis.from_url.return_value = mock_redis_client
        
        worker = Worker()
        assert worker.fetcher is not None
        assert worker.producer is not None
        assert worker.consumer is not None

    @patch('workers.main.redis')
    @patch('workers.main.KafkaProducer')
    @patch('workers.main.KafkaConsumer')
    def test_process_active_auction_job(self, mock_consumer, mock_producer, mock_redis):
        mock_redis_client = Mock()
        mock_redis.from_url.return_value = mock_redis_client
        
        worker = Worker()
        worker.fetcher = Mock()
        worker.fetcher.fetch_copart_listings = Mock(return_value=[])
        worker.fetcher.fetch_iaai_listings = Mock(return_value=[])
        worker._send_to_kafka = Mock()
        
        job_data = {
            'filters': {'make': 'Toyota', 'model': 'Camry', 'year': 2020},
            'telegram_chat_id': 123456789,
            'telegram_user_id': 987654321
        }
        
        worker.process_active_auction_job(job_data)
        worker.fetcher.fetch_copart_listings.assert_called_once()
        worker.fetcher.fetch_iaai_listings.assert_called_once()

    @patch('workers.main.redis')
    @patch('workers.main.KafkaProducer')
    @patch('workers.main.KafkaConsumer')
    def test_send_to_kafka(self, mock_consumer, mock_producer, mock_redis):
        mock_redis_client = Mock()
        mock_redis.from_url.return_value = mock_redis_client
        
        worker = Worker()
        mock_future = Mock()
        mock_future.get = Mock(return_value=True)
        worker.producer.send = Mock(return_value=mock_future)
        
        message = {'test': 'data'}
        worker._send_to_kafka('test-topic', message)
        
        worker.producer.send.assert_called_once()
        mock_future.get.assert_called_once()

    @patch('workers.main.redis')
    @patch('workers.main.KafkaProducer')
    @patch('workers.main.KafkaConsumer')
    def test_process_job(self, mock_consumer, mock_producer, mock_redis):
        mock_redis_client = Mock()
        mock_redis.from_url.return_value = mock_redis_client
        
        worker = Worker()
        worker.process_active_auction_job = Mock()
        
        job_data = {'filters': {}}
        worker.process_job(job_data, 'active-auction-jobs')
        
        worker.process_active_auction_job.assert_called_once_with(job_data)


