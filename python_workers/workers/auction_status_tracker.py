"""
Auction Status Tracker - отслеживание завершённых аукционов
"""
import os
import json
import time
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from kafka import KafkaProducer
from .iaai_scraper import IAAIScraper
from .iaai_parser import IAAIParser
from .adaptive_rate_limiter import AdaptiveRateLimiter
import redis


class AuctionStatusTracker:
    """
    Трекер для отслеживания завершённых аукционов
    
    Особенности:
    - Проверка активных аукционов на завершение
    - Сохранение финальной цены и статуса
    - Обновление auction_status: 'completed'
    - Сохранение final_price
    """
    
    def __init__(
        self,
        redis_client: redis.Redis,
        rate_limiter: AdaptiveRateLimiter,
        kafka_brokers: List[str],
        batch_size: int = 50
    ):
        """
        Args:
            redis_client: Redis клиент
            rate_limiter: Адаптивный rate limiter
            kafka_brokers: Список Kafka брокеров
            batch_size: Размер батча для отправки в Kafka
        """
        self.redis = redis_client
        self.rate_limiter = rate_limiter
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
        
        # Redis ключи
        self.last_check_key = 'scraper:last_status_check:iaai'
        self.processed_auctions_key = 'scraper:processed_auctions:iaai:{date}'
    
    def get_active_auctions_from_db(self, limit: int = 100) -> List[Dict]:
        """
        Получает список активных аукционов из БД через API
        
        В реальной реализации это должно быть обращение к Rails API
        или прямой запрос к БД через SQLAlchemy/psycopg2
        
        Args:
            limit: Максимальное количество аукционов для проверки
            
        Returns:
            Список словарей с данными об активных аукционах
        """
        # TODO: Реализовать получение из БД
        # Пока возвращаем пустой список
        # В реальности это должно быть:
        # SELECT * FROM vehicles 
        # WHERE auction_status = 'active' 
        # AND auction_end_date < NOW()
        # LIMIT {limit}
        
        print(f"  Note: get_active_auctions_from_db needs to be implemented")
        print(f"  Should query: SELECT * FROM vehicles WHERE auction_status = 'active' AND auction_end_date < NOW() LIMIT {limit}")
        
        return []
    
    def check_auction_status(self, auction_url: str, source_id: str) -> Optional[Dict]:
        """
        Проверяет статус аукциона по URL
        
        Args:
            auction_url: URL детальной страницы аукциона
            source_id: ID записи
            
        Returns:
            Словарь с обновлёнными данными или None при ошибке
            {
                'source_id': str,
                'auction_status': 'active' | 'completed',
                'final_price': float | None,
                'auction_end_date': float | None
            }
        """
        rate_limit_key = 'rate_limit:scraper:iaai:status_check'
        
        # Rate limiting
        self.rate_limiter.wait(rate_limit_key)
        
        # Получаем детальную страницу
        detail_html = None
        if self.scraper.page:
            detail_html = self.scraper._fetch_with_playwright(auction_url, wait_for_ajax=False)
        if not detail_html:
            detail_html = self.scraper._fetch_with_cloudscraper(auction_url)
        
        if not detail_html:
            print(f"    ✗ Failed to fetch auction page: {source_id}")
            return None
        
        # Парсим страницу
        detail_data = self.parser.parse_detail_page(detail_html, auction_url)
        
        if not detail_data:
            print(f"    ⚠ Failed to parse auction page: {source_id}")
            return None
        
        # Определяем статус аукциона
        # Проверяем индикаторы завершённого аукциона:
        # - Наличие "Sold" или "Closed" в тексте
        # - Отсутствие "Bidding" или "Active"
        # - Наличие финальной цены
        
        page_text = detail_html.lower()
        auction_status = 'active'
        
        # Проверяем статусы
        sold_indicators = ['sold', 'sale complete', 'winning bid', 'purchased']
        not_sold_indicators = ['not sold', 'no sale', 'passed', 'reserve not met']
        buy_now_indicators = ['buy now', 'buy it now', 'purchased via buy now']
        upcoming_indicators = ['upcoming', 'scheduled', 'starts', 'begins']
        archived_indicators = ['archived', 'removed', 'no longer available']
        
        active_indicators = [
            'bidding', 'active', 'current bid', 'ends in', 'time remaining'
        ]
        
        # Определяем статус по индикаторам
        if any(indicator in page_text for indicator in archived_indicators):
            auction_status = 'archived'
        elif any(indicator in page_text for indicator in buy_now_indicators):
            auction_status = 'buy_now'
        elif any(indicator in page_text for indicator in sold_indicators):
            auction_status = 'sold'
        elif any(indicator in page_text for indicator in not_sold_indicators):
            auction_status = 'not_sold'
        elif any(indicator in page_text for indicator in upcoming_indicators):
            auction_status = 'upcoming'
        elif any(indicator in page_text for indicator in active_indicators):
            auction_status = 'active'
        
        # Также проверяем дату окончания аукциона
        auction_end_date = detail_data.get('auction_end_date')
        if auction_end_date:
            end_datetime = datetime.fromtimestamp(auction_end_date) if isinstance(auction_end_date, (int, float)) else auction_end_date
            if isinstance(auction_end_date, (int, float)):
                end_datetime = datetime.fromtimestamp(auction_end_date)
            elif isinstance(auction_end_date, str):
                try:
                    end_datetime = datetime.fromisoformat(auction_end_date.replace('Z', '+00:00'))
                except:
                    end_datetime = None
            
            if end_datetime:
                now = datetime.now(end_datetime.tzinfo) if end_datetime.tzinfo else datetime.now()
                if end_datetime < now and auction_status == 'active':
                    # Если дата прошла, но статус ещё active, проверяем детальнее
                    if any(indicator in page_text for indicator in sold_indicators):
                        auction_status = 'sold'
                    else:
                        auction_status = 'not_sold'
        
        # Извлекаем финальную цену
        final_price = detail_data.get('price') or detail_data.get('final_price')
        
        # Если аукцион завершён, но цена не найдена, пробуем найти в тексте
        if auction_status in ['sold', 'buy_now'] and not final_price:
            import re
            price_patterns = [
                r'sold for[\s:]*\$?([\d,]+)',
                r'final price[\s:]*\$?([\d,]+)',
                r'sale price[\s:]*\$?([\d,]+)',
                r'winning bid[\s:]*\$?([\d,]+)',
                r'buy now[\s:]*\$?([\d,]+)',
                r'purchased[\s:]*\$?([\d,]+)'
            ]
            
            for pattern in price_patterns:
                match = re.search(pattern, page_text, re.I)
                if match:
                    try:
                        final_price = float(match.group(1).replace(',', ''))
                        break
                    except:
                        continue
        
        result = {
            'source_id': source_id,
            'auction_status': auction_status,
            'final_price': final_price,
            'auction_end_date': auction_end_date
        }
        
        return result
    
    def send_status_updates_to_kafka(self, updates: List[Dict]):
        """
        Отправляет обновления статусов в Kafka
        
        Args:
            updates: Список обновлений статусов
        """
        if not self.producer or not updates:
            return
        
        try:
            message = {
                'updates': updates,
                'source': 'auction_status_tracker',
                'timestamp': datetime.now().isoformat()
            }
            future = self.producer.send('auction-status-updates', value=message)
            future.get(timeout=10)
            print(f"  ✓ Sent {len(updates)} status updates to Kafka")
        except Exception as e:
            print(f"  ⚠ Error sending status updates to Kafka: {e}")
    
    def track_completed_auctions(
        self,
        max_auctions: Optional[int] = None,
        days_back: int = 7
    ) -> Dict:
        """
        Отслеживает завершённые аукционы
        
        Args:
            max_auctions: Максимальное количество аукционов для проверки (None = без ограничений)
            days_back: Проверять аукционы, которые должны были завершиться за последние N дней
            
        Returns:
            Словарь со статистикой
        """
        print(f"\n{'='*60}")
        print(f"Starting Auction Status Tracking")
        print(f"{'='*60}")
        
        # Получаем активные аукционы из БД
        # В реальной реализации это должно быть обращение к Rails API
        active_auctions = self.get_active_auctions_from_db(limit=max_auctions or 1000)
        
        if not active_auctions:
            print("  ⚠ No active auctions found to check")
            return {
                'success': False,
                'reason': 'no_active_auctions',
                'checked': 0,
                'completed': 0,
                'still_active': 0,
                'errors': 0
            }
        
        print(f"  Found {len(active_auctions)} active auctions to check")
        
        # Фильтруем по дате окончания (проверяем только те, что должны были завершиться)
        cutoff_date = datetime.now() - timedelta(days=days_back)
        auctions_to_check = []
        
        for auction in active_auctions:
            auction_end_date = auction.get('auction_end_date')
            if auction_end_date:
                if isinstance(auction_end_date, str):
                    try:
                        auction_end_date = datetime.fromisoformat(auction_end_date)
                    except:
                        continue
                elif isinstance(auction_end_date, (int, float)):
                    auction_end_date = datetime.fromtimestamp(auction_end_date)
                
                # Проверяем только те, что должны были завершиться
                if auction_end_date < datetime.now():
                    auctions_to_check.append(auction)
            else:
                # Если дата не указана, проверяем все
                auctions_to_check.append(auction)
        
        print(f"  Filtered to {len(auctions_to_check)} auctions that should be checked")
        
        if not auctions_to_check:
            print("  ⚠ No auctions to check after filtering")
            return {
                'success': True,
                'checked': 0,
                'completed': 0,
                'still_active': 0,
                'errors': 0
            }
        
        # Статистика
        stats = {
            'checked': 0,
            'completed': 0,
            'still_active': 0,
            'errors': 0,
            'start_time': time.time()
        }
        
        updates = []
        rate_limit_key = 'rate_limit:scraper:iaai:status_check'
        
        # Проверяем каждый аукцион
        for i, auction in enumerate(auctions_to_check, 1):
            if max_auctions and i > max_auctions:
                break
            
            source_id = auction.get('source_id')
            auction_url = auction.get('auction_url')
            
            if not source_id or not auction_url:
                stats['errors'] += 1
                continue
            
            print(f"  [{i}/{len(auctions_to_check)}] Checking auction {source_id}...")
            
            # Проверяем статус
            status_data = self.check_auction_status(auction_url, source_id)
            
            if not status_data:
                stats['errors'] += 1
                continue
            
            stats['checked'] += 1
            
            if status_data['auction_status'] == 'completed':
                stats['completed'] += 1
                print(f"    ✓ Auction {source_id} is completed (final price: ${status_data.get('final_price')})")
            else:
                stats['still_active'] += 1
                print(f"    → Auction {source_id} is still active")
            
            # Добавляем в список обновлений
            updates.append({
                'source': auction.get('source', 'iaai'),
                'source_id': source_id,
                **status_data
            })
            
            # Отправляем батч в Kafka
            if len(updates) >= self.batch_size:
                self.send_status_updates_to_kafka(updates)
                updates = []
        
        # Отправляем оставшиеся обновления
        if updates:
            self.send_status_updates_to_kafka(updates)
        
        # Сохраняем дату последней проверки
        try:
            self.redis.set(self.last_check_key, datetime.now().isoformat())
        except:
            pass
        
        # Финальная статистика
        stats['end_time'] = time.time()
        stats['duration_seconds'] = stats['end_time'] - stats['start_time']
        stats['success'] = True
        
        print(f"\n{'='*60}")
        print(f"Auction Status Tracking Completed")
        print(f"{'='*60}")
        print(f"Checked: {stats['checked']}")
        print(f"Completed: {stats['completed']}")
        print(f"Still active: {stats['still_active']}")
        print(f"Errors: {stats['errors']}")
        print(f"Duration: {stats['duration_seconds']:.1f} seconds")
        print(f"{'='*60}\n")
        
        return stats

