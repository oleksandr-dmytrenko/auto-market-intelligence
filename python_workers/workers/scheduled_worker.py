"""
Scheduled Worker - ежедневный запуск исторического скрапинга и отслеживания статусов
"""
import os
import sys
import time
import redis
from datetime import datetime
from .historical_scraper import HistoricalScraper
from .auction_status_tracker import AuctionStatusTracker
from .adaptive_rate_limiter import AdaptiveRateLimiter


class ScheduledWorker:
    """
    Воркер для ежедневного запуска задач скрапинга
    
    Задачи:
    - Historical Data Scraping (02:00 UTC)
    - Auction Status Tracking (06:00 UTC)
    """
    
    def __init__(self):
        """Инициализация воркера"""
        self.redis_url = os.getenv('REDIS_URL', 'redis://redis:6379/0')
        self.kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
        
        # Redis клиент
        self.redis = redis.from_url(self.redis_url)
        
        # Rate limiter
        self.rate_limiter = AdaptiveRateLimiter(
            redis_client=self.redis,
            base_delay=2.0,
            max_delay=300.0,
            min_delay=1.0,
            max_requests_per_window=10,
            window_seconds=60
        )
        
        # Инициализируем скраперы
        self.historical_scraper = HistoricalScraper(
            redis_client=self.redis,
            rate_limiter=self.rate_limiter,
            kafka_brokers=self.kafka_brokers,
            months_back=12,
            batch_size=50
        )
        
        self.status_tracker = AuctionStatusTracker(
            redis_client=self.redis,
            rate_limiter=self.rate_limiter,
            kafka_brokers=self.kafka_brokers,
            batch_size=50
        )
    
    def run_historical_scraping(self, months_back: int = 12, max_pages: int = None, max_vehicles: int = None):
        """
        Запускает исторический скрапинг
        
        Args:
            months_back: Количество месяцев назад
            max_pages: Максимальное количество страниц
            max_vehicles: Максимальное количество автомобилей
        """
        print(f"\n{'='*60}")
        print(f"Scheduled Historical Scraping Task")
        print(f"Time: {datetime.now().isoformat()}")
        print(f"{'='*60}\n")
        
        try:
            stats = self.historical_scraper.scrape_historical_data(
                max_pages=max_pages,
                max_vehicles=max_vehicles,
                resume=True
            )
            
            if stats.get('success'):
                print(f"✓ Historical scraping completed successfully")
                print(f"  Total vehicles: {stats.get('total_vehicles', 0)}")
                print(f"  New vehicles: {stats.get('new_vehicles', 0)}")
                print(f"  Duration: {stats.get('duration_seconds', 0):.1f} seconds")
            else:
                print(f"✗ Historical scraping failed: {stats.get('reason', 'unknown')}")
                sys.exit(1)
                
        except Exception as e:
            print(f"✗ Error in historical scraping: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)
    
    def run_status_tracking(self, max_auctions: int = None, days_back: int = 7):
        """
        Запускает отслеживание статусов аукционов
        
        Args:
            max_auctions: Максимальное количество аукционов для проверки
            days_back: Проверять аукционы за последние N дней
        """
        print(f"\n{'='*60}")
        print(f"Scheduled Auction Status Tracking Task")
        print(f"Time: {datetime.now().isoformat()}")
        print(f"{'='*60}\n")
        
        try:
            stats = self.status_tracker.track_completed_auctions(
                max_auctions=max_auctions,
                days_back=days_back
            )
            
            if stats.get('success'):
                print(f"✓ Status tracking completed successfully")
                print(f"  Checked: {stats.get('checked', 0)}")
                print(f"  Completed: {stats.get('completed', 0)}")
                print(f"  Duration: {stats.get('duration_seconds', 0):.1f} seconds")
            else:
                print(f"✗ Status tracking failed: {stats.get('reason', 'unknown')}")
                sys.exit(1)
                
        except Exception as e:
            print(f"✗ Error in status tracking: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)
    
    def run_all(self):
        """Запускает все задачи (для ручного запуска)"""
        print(f"\n{'='*60}")
        print(f"Running All Scheduled Tasks")
        print(f"Time: {datetime.now().isoformat()}")
        print(f"{'='*60}\n")
        
        # Исторический скрапинг
        self.run_historical_scraping()
        
        # Небольшая пауза между задачами
        print("\nWaiting 60 seconds before status tracking...")
        time.sleep(60)
        
        # Отслеживание статусов
        self.run_status_tracking()


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Scheduled Worker for Historical Scraping and Status Tracking')
    parser.add_argument('--task', choices=['historical', 'status', 'all'], default='all',
                       help='Task to run: historical scraping, status tracking, or all')
    parser.add_argument('--months-back', type=int, default=12,
                       help='Months back for historical scraping (default: 12)')
    parser.add_argument('--max-pages', type=int, default=None,
                       help='Maximum pages to scrape (default: unlimited)')
    parser.add_argument('--max-vehicles', type=int, default=None,
                       help='Maximum vehicles to scrape (default: unlimited)')
    parser.add_argument('--max-auctions', type=int, default=None,
                       help='Maximum auctions to check (default: unlimited)')
    parser.add_argument('--days-back', type=int, default=7,
                       help='Days back for status tracking (default: 7)')
    
    args = parser.parse_args()
    
    worker = ScheduledWorker()
    
    if args.task == 'historical':
        worker.run_historical_scraping(
            months_back=args.months_back,
            max_pages=args.max_pages,
            max_vehicles=args.max_vehicles
        )
    elif args.task == 'status':
        worker.run_status_tracking(
            max_auctions=args.max_auctions,
            days_back=args.days_back
        )
    else:
        worker.run_all()



