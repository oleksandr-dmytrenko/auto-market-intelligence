"""
Historical Data Scraper - сбор исторических данных за последние 12 месяцев
"""
import os
import json
import time
import random
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from kafka import KafkaProducer
from .iaai_scraper import IAAIScraper
from .iaai_parser import IAAIParser
from .adaptive_rate_limiter import AdaptiveRateLimiter
import redis


class HistoricalScraper:
    """
    Скрапер для сбора исторических данных
    
    Особенности:
    - Инкрементальное сканирование (только новые/обновлённые записи)
    - Глубина сканирования: до 12 месяцев назад
    - Батч-обработка через Kafka
    - Автоматическое определение новых записей
    """
    
    def __init__(
        self,
        redis_client: redis.Redis,
        rate_limiter: AdaptiveRateLimiter,
        kafka_brokers: List[str],
        months_back: int = 12,
        batch_size: int = 50
    ):
        """
        Args:
            redis_client: Redis клиент для хранения прогресса
            rate_limiter: Адаптивный rate limiter
            kafka_brokers: Список Kafka брокеров
            months_back: Количество месяцев назад для сканирования
            batch_size: Размер батча для отправки в Kafka
        """
        self.redis = redis_client
        self.rate_limiter = rate_limiter
        self.months_back = months_back
        self.batch_size = batch_size
        
        # Инициализируем IAAI scraper
        self.scraper = IAAIScraper(driver=None, rate_limiter=rate_limiter)
        self.parser = IAAIParser()
        
        # Kafka producer
        try:
            self.producer = KafkaProducer(
                bootstrap_servers=kafka_brokers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda k: k.encode('utf-8') if k else None
            )
        except Exception as e:
            print(f"Warning: Could not create Kafka producer: {e}")
            self.producer = None
        
        # Redis ключи для отслеживания прогресса
        self.last_scan_date_key = 'scraper:last_scan_date:iaai:historical'
        self.processed_ids_key_template = 'scraper:processed_ids:iaai:{date}'
        self.last_page_key_template = 'scraper:last_page:iaai:{date}'
        self.processed_count_key_template = 'scraper:processed_count:iaai:{date}'
    
    def get_last_scan_date(self) -> Optional[datetime]:
        """
        Получает дату последнего сканирования из Redis
        
        Returns:
            Дата последнего сканирования или None
        """
        try:
            date_str = self.redis.get(self.last_scan_date_key)
            if date_str:
                return datetime.fromisoformat(date_str.decode('utf-8'))
        except Exception as e:
            print(f"Warning: Error getting last scan date: {e}")
        return None
    
    def save_last_scan_date(self, date: datetime):
        """
        Сохраняет дату последнего сканирования в Redis
        
        Args:
            date: Дата сканирования
        """
        try:
            self.redis.set(self.last_scan_date_key, date.isoformat())
        except Exception as e:
            print(f"Warning: Error saving last scan date: {e}")
    
    def is_processed(self, source_id: str, date: datetime) -> bool:
        """
        Проверяет, был ли уже обработан данный source_id за указанную дату
        
        Args:
            source_id: ID записи
            date: Дата сканирования
            
        Returns:
            True если уже обработан, False если нет
        """
        try:
            date_str = date.strftime('%Y-%m-%d')
            key = self.processed_ids_key_template.format(date=date_str)
            return self.redis.sismember(key, source_id)
        except Exception as e:
            print(f"Warning: Error checking if processed: {e}")
            return False
    
    def mark_as_processed(self, source_id: str, date: datetime):
        """
        Помечает source_id как обработанный
        
        Args:
            source_id: ID записи
            date: Дата сканирования
        """
        try:
            date_str = date.strftime('%Y-%m-%d')
            key = self.processed_ids_key_template.format(date=date_str)
            # Сохраняем на 30 дней
            pipe = self.redis.pipeline()
            pipe.sadd(key, source_id)
            pipe.expire(key, 30 * 24 * 60 * 60)  # 30 дней
            pipe.execute()
        except Exception as e:
            print(f"Warning: Error marking as processed: {e}")
    
    def send_batch_to_kafka(self, vehicles: List[Dict]):
        """
        Отправляет батч автомобилей в Kafka
        
        Args:
            vehicles: Список данных об автомобилях
        """
        if not self.producer or not vehicles:
            return
        
        try:
            message = {
                'vehicles': vehicles,
                'source': 'historical_scraper',
                'timestamp': datetime.now().isoformat()
            }
            future = self.producer.send('historical-vehicle-data', value=message)
            future.get(timeout=10)
            print(f"  ✓ Sent batch of {len(vehicles)} vehicles to Kafka")
        except Exception as e:
            print(f"  ⚠ Error sending batch to Kafka: {e}")
    
    def scrape_historical_data(
        self,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        max_pages: Optional[int] = None,
        max_vehicles: Optional[int] = None,
        resume: bool = True
    ) -> Dict:
        """
        Сканирует исторические данные за указанный период
        
        Args:
            start_date: Начальная дата (по умолчанию: months_back месяцев назад)
            end_date: Конечная дата (по умолчанию: сегодня)
            max_pages: Максимальное количество страниц (None = без ограничений)
            max_vehicles: Максимальное количество автомобилей (None = без ограничений)
            resume: Продолжить с последней позиции (True) или начать заново (False)
            
        Returns:
            Словарь со статистикой сканирования
        """
        print(f"\n{'='*60}")
        print(f"Starting Historical Data Scraping")
        print(f"{'='*60}")
        
        # Определяем диапазон дат
        if end_date is None:
            end_date = datetime.now()
        
        if start_date is None:
            start_date = end_date - timedelta(days=self.months_back * 30)
        
        print(f"Date range: {start_date.date()} to {end_date.date()}")
        print(f"Depth: {(end_date - start_date).days} days")
        
        # Проверяем, нужно ли продолжить с последней позиции
        if resume:
            last_scan_date = self.get_last_scan_date()
            if last_scan_date and last_scan_date >= start_date:
                print(f"Resuming from last scan date: {last_scan_date.date()}")
                start_date = last_scan_date
        
        # Rate limiting ключ
        rate_limit_key = 'rate_limit:scraper:iaai:historical'
        
        # Проверяем rate limit
        if self.rate_limiter.wait_if_needed(rate_limit_key):
            print("Rate limit reached, aborting")
            return {'success': False, 'reason': 'rate_limit'}
        
        all_vehicles = []
        page = 1
        total_pages = None
        consecutive_empty_pages = 0
        max_empty_pages = 3
        
        # Статистика
        stats = {
            'total_vehicles': 0,
            'new_vehicles': 0,
            'updated_vehicles': 0,
            'skipped_vehicles': 0,
            'pages_scraped': 0,
            'errors': 0,
            'start_time': time.time()
        }
        
        current_date = datetime.now()
        
        while True:
            # Проверяем ограничение по страницам
            if max_pages and page > max_pages:
                print(f"\n  Reached max pages limit ({max_pages})")
                break
            
            print(f"\n  [Page {page}] Fetching listings...")
            
            # Получаем URL для текущей страницы
            if page == 1:
                url = self.parser.build_all_vehicles_url()
            else:
                url = self.parser.build_all_vehicles_url(page)
            
            # Rate limiting перед запросом
            self.rate_limiter.wait(rate_limit_key)
            
            # Получаем страницу
            html = None
            if self.scraper.page:
                html = self.scraper._fetch_with_playwright(url)
                if not html:
                    print("  Playwright failed, trying cloudscraper...")
                    html = self.scraper._fetch_with_cloudscraper(url)
            else:
                html = self.scraper._fetch_with_cloudscraper(url)
            
            if not html:
                print(f"  ✗ Failed to fetch page {page}")
                consecutive_empty_pages += 1
                stats['errors'] += 1
                
                if consecutive_empty_pages >= max_empty_pages:
                    print(f"  Stopping after {consecutive_empty_pages} consecutive empty pages")
                    break
                
                page += 1
                continue
            
            # Парсим страницу
            listings = self.parser.parse_listing_page(html)
            print(f"  Found {len(listings)} listings on page {page}")
            
            if not listings:
                consecutive_empty_pages += 1
                print(f"  ⚠ No listings found (empty pages: {consecutive_empty_pages}/{max_empty_pages})")
                
                if consecutive_empty_pages >= max_empty_pages:
                    print(f"  Stopping after {consecutive_empty_pages} consecutive empty pages")
                    break
            else:
                consecutive_empty_pages = 0
            
            # Обрабатываем каждую запись
            page_vehicles = []
            for i, listing in enumerate(listings, 1):
                detail_url = listing.get('detail_url')
                source_id = listing.get('source_id')
                
                if not detail_url or not source_id:
                    continue
                
                # Проверяем, был ли уже обработан
                if resume and self.is_processed(source_id, current_date):
                    stats['skipped_vehicles'] += 1
                    continue
                
                print(f"    [{i}/{len(listings)}] Fetching detail page (ID: {source_id})...")
                
                if i > 1:
                    self.rate_limiter.wait(rate_limit_key)
                
                # Получаем детальную страницу
                detail_html = None
                if self.scraper.page:
                    detail_html = self.scraper._fetch_with_playwright(detail_url, wait_for_ajax=False)
                if not detail_html:
                    detail_html = self.scraper._fetch_with_cloudscraper(detail_url)
                
                if detail_html:
                    detail_data = self.parser.parse_detail_page(detail_html, detail_url)
                    if detail_data:
                        # Фильтруем по дате аукциона
                        auction_date = None
                        if detail_data.get('auction_end_date'):
                            auction_date = datetime.fromtimestamp(detail_data['auction_end_date'])
                        elif detail_data.get('auction_end_date'):
                            # Пробуем парсить из raw_data
                            pass
                        
                        # Проверяем, попадает ли в диапазон дат
                        if auction_date:
                            if auction_date < start_date or auction_date > end_date:
                                print(f"      ⏭ Skipping (date out of range: {auction_date.date()})")
                                stats['skipped_vehicles'] += 1
                                continue
                        
                        # Устанавливаем статус как завершённый (исторические данные)
                        detail_data['auction_status'] = 'completed'
                        
                        # Отмечаем как обработанный
                        if resume:
                            self.mark_as_processed(source_id, current_date)
                        
                        page_vehicles.append(detail_data)
                        stats['new_vehicles'] += 1
                        print(f"      ✓ Parsed: {detail_data.get('make')} {detail_data.get('model')} {detail_data.get('year')}")
                    else:
                        print(f"      ⚠ Failed to parse detail page")
                        stats['errors'] += 1
                else:
                    print(f"      ✗ Failed to fetch detail page")
                    stats['errors'] += 1
                
                # Проверяем ограничение по количеству автомобилей
                if max_vehicles and len(all_vehicles) + len(page_vehicles) >= max_vehicles:
                    page_vehicles = page_vehicles[:max_vehicles - len(all_vehicles)]
                    break
            
            if page_vehicles:
                all_vehicles.extend(page_vehicles)
                stats['total_vehicles'] += len(page_vehicles)
                stats['pages_scraped'] += 1
                print(f"  ✓ Page {page}: {len(page_vehicles)} vehicles collected (total: {len(all_vehicles)})")
                
                # Отправляем батч в Kafka
                if len(all_vehicles) >= self.batch_size:
                    batch = all_vehicles[:self.batch_size]
                    self.send_batch_to_kafka(batch)
                    all_vehicles = all_vehicles[self.batch_size:]
                
                # Проверяем ограничение по количеству автомобилей
                if max_vehicles and len(all_vehicles) >= max_vehicles:
                    all_vehicles = all_vehicles[:max_vehicles]
                    print(f"  ✓ Reached max vehicles limit ({max_vehicles})")
                    # Отправляем финальный батч
                    if all_vehicles:
                        self.send_batch_to_kafka(all_vehicles)
                    break
            
            # Проверяем пагинацию
            from bs4 import BeautifulSoup
            pagination_info = self.parser.find_pagination(BeautifulSoup(html, 'html.parser'))
            
            if pagination_info.get('total_pages') and not total_pages:
                total_pages = pagination_info['total_pages']
                print(f"  Total pages detected: {total_pages}")
            
            if pagination_info.get('has_next'):
                page += 1
                self.rate_limiter.wait(rate_limit_key)
            else:
                print(f"  No more pages available")
                break
            
            if total_pages and page > total_pages:
                print(f"  Reached total pages limit ({total_pages})")
                break
        
        # Отправляем оставшиеся данные
        if all_vehicles:
            self.send_batch_to_kafka(all_vehicles)
        
        # Сохраняем дату последнего сканирования
        self.save_last_scan_date(end_date)
        
        # Финальная статистика
        stats['end_time'] = time.time()
        stats['duration_seconds'] = stats['end_time'] - stats['start_time']
        stats['success'] = True
        
        print(f"\n{'='*60}")
        print(f"Historical Scraping Completed")
        print(f"{'='*60}")
        print(f"Total vehicles: {stats['total_vehicles']}")
        print(f"New vehicles: {stats['new_vehicles']}")
        print(f"Skipped vehicles: {stats['skipped_vehicles']}")
        print(f"Pages scraped: {stats['pages_scraped']}")
        print(f"Errors: {stats['errors']}")
        print(f"Duration: {stats['duration_seconds']:.1f} seconds")
        print(f"{'='*60}\n")
        
        return stats


