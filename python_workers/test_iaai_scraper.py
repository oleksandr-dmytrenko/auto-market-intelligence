#!/usr/bin/env python3
"""
Тестовый скрипт для IAAI scraper
Проверяет работу cloudscraper и Selenium fallback с вежливыми задержками
"""
import os
import sys
import json
import time
from kafka import KafkaProducer
from workers.iaai_scraper import IAAIScraper
from workers.rate_limiter import RateLimiter
from workers.auction_fetcher import AuctionFetcher
import redis

def main():
    print("=" * 60)
    print("Тест: IAAI Scraper (cloudscraper + Selenium)")
    print("=" * 60)
    print("\nЭтот скрапер использует:")
    print("  - cloudscraper как основной метод")
    print("  - undetected-chromedriver как fallback")
    print("  - Вежливые задержки между запросами")
    print("  - Имитацию человеческого поведения\n")
    
    # Настройки
    redis_url = os.getenv('REDIS_URL', 'redis://redis:6379/0')
    kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
    
    # Подключаемся к Redis
    print("1. Подключение к Redis...")
    try:
        redis_client = redis.from_url(redis_url)
        redis_client.ping()
        print("✓ Redis подключен")
    except Exception as e:
        print(f"✗ Ошибка подключения к Redis: {e}")
        return 1
    
    # Создаем rate limiter и fetcher
    print("\n2. Инициализация скрапера...")
    rate_limiter = RateLimiter(redis_client)
    fetcher = AuctionFetcher(rate_limiter)
    
    if fetcher.driver:
        print("✓ Chrome Driver доступен (будет использован как fallback)")
    else:
        print("⚠ Chrome Driver недоступен (только cloudscraper)")
    
    # Тестовые параметры
    print("\n3. Параметры поиска...")
    filters = {
        'make': 'Toyota',
        'model': 'Camry',
        'year': 2020
    }
    print(f"   Марка: {filters['make']}")
    print(f"   Модель: {filters['model']}")
    print(f"   Год: {filters['year']}")
    
    print("\n4. Запуск скрапинга...")
    print("   ⚠ Это может занять время из-за вежливых задержек")
    print("   Задержки имитируют человеческое поведение\n")
    
    try:
        # Получаем данные (limit=1 для быстрого теста)
        vehicles = fetcher.fetch_iaai_listings(filters, limit=1)
        
        if not vehicles:
            print("\n✗ Не удалось получить данные")
            print("\nВозможные причины:")
            print("  - Cloudflare (Incapsula) блокирует запросы")
            print("  - Нет результатов по указанным критериям")
            print("  - Проблемы с парсингом")
            print("  - Селекторы HTML могут требовать уточнения")
            print("\nРекомендации:")
            print("  - Использовать residential прокси")
            print("  - Попробовать другие параметры поиска")
            print("  - Проверить, доступен ли сайт IAAI вручную")
            print("  - Рассмотреть использование API, если доступно")
            return 1
        
        vehicle = vehicles[0]
        print(f"\n✓ Получена запись!")
        print(f"\nДетали:")
        print(f"   Марка: {vehicle.get('make', 'N/A')}")
        print(f"   Модель: {vehicle.get('model', 'N/A')}")
        print(f"   Год: {vehicle.get('year', 'N/A')}")
        print(f"   Пробег: {vehicle.get('mileage', 'N/A')}")
        print(f"   Цвет: {vehicle.get('color', 'N/A')}")
        print(f"   Цена: ${vehicle.get('price', 'N/A')}")
        print(f"   VIN: {vehicle.get('vin', 'N/A')}")
        print(f"   Повреждение: {vehicle.get('damage_type', 'N/A')}")
        print(f"   Локация: {vehicle.get('location', 'N/A')}")
        print(f"   URL: {vehicle.get('auction_url', 'N/A')}")
        print(f"   Source ID: {vehicle.get('source_id', 'N/A')}")
        print(f"   Статус: {vehicle.get('auction_status', 'N/A')}")
        
        images = vehicle.get('images', [])
        if images:
            print(f"   Фото: {len(images)} изображений")
            if len(images) <= 3:
                for img in images:
                    print(f"     - {img}")
        
        # Отправляем в Kafka
        print("\n5. Отправка данных в Kafka...")
        try:
            producer = KafkaProducer(
                bootstrap_servers=kafka_brokers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda k: k.encode('utf-8') if k else None
            )
            
            message = {
                'vehicles': vehicles
            }
            
            future = producer.send('iaai-vehicle-data', value=message)
            future.get(timeout=10)
            print("✓ Данные отправлены в Kafka топик 'iaai-vehicle-data'")
            
            producer.close()
            
            # Ждем обработки
            print("\n6. Ожидание обработки Kafka consumer...")
            print("   Ожидание 5 секунд...")
            time.sleep(5)
            
            print("\n7. Проверка сохранения в БД...")
            source_id = vehicle.get('source_id')
            print(f"   Выполните в Rails console:")
            print(f"   docker compose exec rails_api bundle exec rails console")
            print(f"\n   Затем:")
            print(f"   Vehicle.find_by(source: 'iaai', source_id: '{source_id}')")
            
            print("\n" + "=" * 60)
            print("Тест завершен успешно!")
            print("=" * 60)
            print(f"\n✓ Данные получены и отправлены в Kafka")
            print(f"  Source ID: {source_id}")
            if vehicle.get('vin'):
                print(f"  VIN: {vehicle.get('vin')}")
            print(f"  URL: {vehicle.get('auction_url')}")
            
            return 0
            
        except Exception as e:
            print(f"✗ Ошибка отправки в Kafka: {e}")
            import traceback
            traceback.print_exc()
            return 1
        
    except Exception as e:
        print(f"\n✗ Ошибка при скрапинге: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    finally:
        # Закрываем драйвер
        if fetcher.driver:
            try:
                fetcher.driver.quit()
                print("\n✓ Chrome Driver закрыт")
            except:
                pass

if __name__ == '__main__':
    sys.exit(main())

