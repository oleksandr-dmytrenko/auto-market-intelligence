import os
import json
import time
from kafka import KafkaConsumer, KafkaProducer
from typing import Dict
from .auction_fetcher import AuctionFetcher
from .rate_limiter import RateLimiter
import redis

class Worker:
    """Python worker: handles on-demand active auction search"""
    
    def __init__(self):
        self.kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
        self.redis_url = os.getenv('REDIS_URL', 'redis://redis:6379/0')
        
        # Use AuctionFetcher directly since ScraperService is removed
        redis_client = redis.from_url(self.redis_url)
        rate_limiter = RateLimiter(redis_client)
        self.fetcher = AuctionFetcher(rate_limiter)
        
        # Kafka producer for sending results
        self.producer = KafkaProducer(
            bootstrap_servers=self.kafka_brokers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None
        )
        
        # Kafka consumer for receiving jobs
        self.consumer = KafkaConsumer(
            'active-auction-jobs',
            bootstrap_servers=self.kafka_brokers,
            group_id='python-workers',
            value_deserializer=lambda m: json.loads(m.decode('utf-8'))
        )
    
    def process_job(self, job_data: Dict, topic: str):
        """Process job based on topic"""
        if topic == 'active-auction-jobs':
            self.process_active_auction_job(job_data)
    
    def process_active_auction_job(self, job_data: Dict):
        """On-demand: Search active auctions on IAAI and Copart"""
        filters = job_data.get('filters', {})
        telegram_chat_id = job_data.get('telegram_chat_id')
        telegram_user_id = job_data.get('telegram_user_id')
        
        print(f"Searching active auctions for chat {telegram_chat_id}")
        
        try:
            # Search both IAAI and Copart
            vehicles = []
            copart_vehicles = self.fetcher.fetch_copart_listings(filters, limit=30)
            iaai_vehicles = self.fetcher.fetch_iaai_listings(filters, limit=30)
            vehicles.extend(copart_vehicles)
            vehicles.extend(iaai_vehicles)
            
            if vehicles:
                self._send_to_kafka('active-auction-data', {
                    'telegram_chat_id': telegram_chat_id,
                    'telegram_user_id': telegram_user_id,
                    'filters': filters,
                    'vehicles': vehicles
                })
                print(f"Sent {len(vehicles)} active auction vehicles to Kafka")
            else:
                # Send empty result to Telegram
                self._send_to_kafka('active-auction-data', {
                    'telegram_chat_id': telegram_chat_id,
                    'telegram_user_id': telegram_user_id,
                    'filters': filters,
                    'vehicles': []
                })
        except Exception as e:
            print(f"Error processing active auction job: {e}")
            import traceback
            traceback.print_exc()
    
    def _send_to_kafka(self, topic: str, message: dict):
        """Send data to Kafka"""
        future = self.producer.send(topic, value=message)
        future.get(timeout=10)
    
    def run(self):
        """Main worker loop"""
        print("Worker started, consuming from Kafka...")
        
        try:
            for message in self.consumer:
                try:
                    self.process_job(message.value, message.topic)
                except Exception as e:
                    print(f"Error processing message: {e}")
                    import traceback
                    traceback.print_exc()
                    
        except KeyboardInterrupt:
            print("Worker shutting down...")
        finally:
            self.consumer.close()
            self.producer.close()

if __name__ == '__main__':
    Worker().run()
