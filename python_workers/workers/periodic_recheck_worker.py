"""
Periodic Recheck Worker - проверка статусов аукционов в T-1, T, T+1 дни
"""
import os
import json
import time
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from kafka import KafkaProducer
import redis
import psycopg2
from psycopg2.extras import RealDictCursor


class PeriodicRecheckWorker:
    """
    Воркер для периодических проверок статусов аукционов
    
    Проверяет аукционы в:
    - T-1 день (за день до аукциона)
    - T день (день аукциона)
    - T+1 день (фиксация финального статуса)
    """
    
    def __init__(
        self,
        redis_client: redis.Redis,
        kafka_brokers: List[str],
        db_config: Dict
    ):
        """
        Args:
            redis_client: Redis клиент
            kafka_brokers: Список Kafka брокеров
            db_config: Конфигурация БД (host, port, database, user, password)
        """
        self.redis = redis_client
        self.kafka_brokers = kafka_brokers
        self.db_config = db_config
        
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
        self.recheck_queue_key = 'recheck:queue'
        self.recheck_processed_key = 'recheck:processed:{vehicle_id}'
    
    def get_db_connection(self):
        """Получает соединение с БД"""
        return psycopg2.connect(
            host=self.db_config['host'],
            port=self.db_config.get('port', 5432),
            database=self.db_config['database'],
            user=self.db_config['user'],
            password=self.db_config['password']
        )
    
    def get_vehicles_for_recheck(self, days_offset: int = 0, limit: int = 100) -> List[Dict]:
        """
        Получает список автомобилей для проверки
        
        Args:
            days_offset: Смещение в днях (0 = сегодня, -1 = вчера, +1 = завтра)
            limit: Максимальное количество записей
            
        Returns:
            Список словарей с данными об автомобилях
        """
        conn = None
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
            # Вычисляем дату для проверки
            target_date = datetime.now().date() + timedelta(days=days_offset)
            target_date_start = datetime.combine(target_date, datetime.min.time())
            target_date_end = datetime.combine(target_date, datetime.max.time())
            
            # Запрос для получения активных аукционов с auction_end_date в указанный день
            query = """
                SELECT 
                    id, source, source_id, stock_number, lot_id,
                    auction_url, auction_end_date, auction_status,
                    price, final_price
                FROM vehicles
                WHERE auction_status IN ('active', 'upcoming')
                  AND auction_end_date >= %s
                  AND auction_end_date <= %s
                ORDER BY auction_end_date ASC
                LIMIT %s
            """
            
            cursor.execute(query, (target_date_start, target_date_end, limit))
            vehicles = cursor.fetchall()
            
            return [dict(vehicle) for vehicle in vehicles]
            
        except Exception as e:
            print(f"Error getting vehicles for recheck: {e}")
            return []
        finally:
            if conn:
                conn.close()
    
    def schedule_recheck(self, vehicle_id: str, auction_end_date: datetime):
        """
        Планирует проверку для автомобиля в T-1, T, T+1 дни
        
        Args:
            vehicle_id: ID автомобиля
            auction_end_date: Дата окончания аукциона
        """
        if not auction_end_date:
            return
        
        # Вычисляем даты проверок
        t_minus_1 = auction_end_date - timedelta(days=1)
        t_day = auction_end_date
        t_plus_1 = auction_end_date + timedelta(days=1)
        
        # Добавляем в очередь Redis с приоритетом по дате
        recheck_data = {
            'vehicle_id': vehicle_id,
            'auction_end_date': auction_end_date.isoformat(),
            'check_dates': [
                {'date': t_minus_1.isoformat(), 'type': 'T-1'},
                {'date': t_day.isoformat(), 'type': 'T'},
                {'date': t_plus_1.isoformat(), 'type': 'T+1'}
            ]
        }
        
        # Используем sorted set для хранения очереди с приоритетом по дате
        for check_date in recheck_data['check_dates']:
            check_datetime = datetime.fromisoformat(check_date['date'])
            score = check_datetime.timestamp()
            
            queue_item = {
                'vehicle_id': vehicle_id,
                'check_date': check_date['date'],
                'check_type': check_date['type']
            }
            
            self.redis.zadd(
                self.recheck_queue_key,
                {json.dumps(queue_item): score}
            )
    
    def process_recheck_queue(self, max_items: int = 50):
        """
        Обрабатывает очередь проверок
        
        Args:
            max_items: Максимальное количество элементов для обработки
        """
        now = datetime.now()
        cutoff_score = now.timestamp()
        
        # Получаем элементы из очереди, которые должны быть проверены сейчас или ранее
        items = self.redis.zrangebyscore(
            self.recheck_queue_key,
            '-inf',
            cutoff_score,
            start=0,
            num=max_items
        )
        
        if not items:
            return 0
        
        processed_count = 0
        
        for item_json in items:
            try:
                item = json.loads(item_json)
                vehicle_id = item['vehicle_id']
                check_date = datetime.fromisoformat(item['check_date'])
                check_type = item['check_type']
                
                # Проверяем, не обработан ли уже этот элемент
                processed_key = self.recheck_processed_key.format(vehicle_id=vehicle_id)
                if self.redis.exists(f"{processed_key}:{check_type}"):
                    # Удаляем из очереди
                    self.redis.zrem(self.recheck_queue_key, item_json)
                    continue
                
                # Получаем данные автомобиля из БД
                vehicle = self.get_vehicle_by_id(vehicle_id)
                
                if not vehicle:
                    # Удаляем из очереди, если автомобиль не найден
                    self.redis.zrem(self.recheck_queue_key, item_json)
                    continue
                
                # Отправляем задачу на проверку в Kafka
                self.send_recheck_task(vehicle, check_type)
                
                # Помечаем как обработанное
                self.redis.setex(
                    f"{processed_key}:{check_type}",
                    86400 * 2,  # TTL: 2 дня
                    '1'
                )
                
                # Удаляем из очереди
                self.redis.zrem(self.recheck_queue_key, item_json)
                
                processed_count += 1
                
            except Exception as e:
                print(f"Error processing recheck item: {e}")
                continue
        
        return processed_count
    
    def get_vehicle_by_id(self, vehicle_id: str) -> Optional[Dict]:
        """Получает данные автомобиля по ID"""
        conn = None
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor(cursor_factory=RealDictCursor)
            
            query = """
                SELECT 
                    id, source, source_id, stock_number, lot_id,
                    auction_url, auction_end_date, auction_status,
                    price, final_price
                FROM vehicles
                WHERE id = %s
            """
            
            cursor.execute(query, (vehicle_id,))
            vehicle = cursor.fetchone()
            
            return dict(vehicle) if vehicle else None
            
        except Exception as e:
            print(f"Error getting vehicle by ID: {e}")
            return None
        finally:
            if conn:
                conn.close()
    
    def send_recheck_task(self, vehicle: Dict, check_type: str):
        """
        Отправляет задачу на проверку в Kafka
        
        Args:
            vehicle: Данные автомобиля
            check_type: Тип проверки ('T-1', 'T', 'T+1')
        """
        if not self.producer:
            return
        
        try:
            message = {
                'vehicle_id': str(vehicle['id']),
                'source': vehicle['source'],
                'source_id': vehicle['source_id'],
                'stock_number': vehicle.get('stock_number'),
                'lot_id': vehicle.get('lot_id'),
                'auction_url': vehicle['auction_url'],
                'check_type': check_type,
                'auction_end_date': vehicle['auction_end_date'].isoformat() if vehicle['auction_end_date'] else None,
                'timestamp': datetime.now().isoformat()
            }
            
            future = self.producer.send('auction-status-updates', value=message)
            future.get(timeout=10)
            
            print(f"  ✓ Sent recheck task for vehicle {vehicle['source_id']} ({check_type})")
            
        except Exception as e:
            print(f"  ⚠ Error sending recheck task: {e}")
    
    def run_daily_recheck(self):
        """
        Ежедневная проверка: получает автомобили для проверки сегодня
        и отправляет задачи в Kafka
        """
        print(f"\n{'='*60}")
        print(f"Starting Daily Recheck")
        print(f"Time: {datetime.now().isoformat()}")
        print(f"{'='*60}\n")
        
        # Проверяем автомобили для T-1, T, T+1
        for days_offset in [-1, 0, 1]:
            check_type = ['T-1', 'T', 'T+1'][days_offset + 1]
            print(f"\nChecking vehicles for {check_type} (days_offset: {days_offset})...")
            
            vehicles = self.get_vehicles_for_recheck(days_offset=days_offset, limit=100)
            
            if not vehicles:
                print(f"  No vehicles found for {check_type}")
                continue
            
            print(f"  Found {len(vehicles)} vehicles for {check_type}")
            
            for vehicle in vehicles:
                self.send_recheck_task(vehicle, check_type)
        
        print(f"\n{'='*60}")
        print(f"Daily Recheck Completed")
        print(f"{'='*60}\n")
    
    def process_queue(self, max_items: int = 50):
        """Обрабатывает очередь проверок"""
        print(f"\nProcessing recheck queue (max_items: {max_items})...")
        
        processed = self.process_recheck_queue(max_items=max_items)
        
        print(f"Processed {processed} items from queue")
        
        return processed


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Periodic Recheck Worker')
    parser.add_argument('--mode', choices=['daily', 'queue'], default='daily',
                       help='Mode: daily recheck or process queue')
    parser.add_argument('--max-items', type=int, default=50,
                       help='Maximum items to process from queue')
    
    args = parser.parse_args()
    
    # Конфигурация из переменных окружения
    redis_url = os.getenv('REDIS_URL', 'redis://redis:6379/0')
    kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
    
    db_config = {
        'host': os.getenv('POSTGRES_HOST', 'postgres'),
        'port': int(os.getenv('POSTGRES_PORT', 5432)),
        'database': os.getenv('POSTGRES_DB', 'auto_market_intelligence'),
        'user': os.getenv('POSTGRES_USER', 'postgres'),
        'password': os.getenv('POSTGRES_PASSWORD', 'postgres')
    }
    
    redis_client = redis.from_url(redis_url)
    
    worker = PeriodicRecheckWorker(
        redis_client=redis_client,
        kafka_brokers=kafka_brokers,
        db_config=db_config
    )
    
    if args.mode == 'daily':
        worker.run_daily_recheck()
    else:
        worker.process_queue(max_items=args.max_items)



