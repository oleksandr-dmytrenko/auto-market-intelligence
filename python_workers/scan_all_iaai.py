#!/usr/bin/env python3
"""
Скрипт для сканирования всех записей IAAI за последние 3 месяца
Сканирует страницу за страницей и сохраняет данные в базу через Kafka
"""
import os
import sys
import time
from workers.auction_fetcher import AuctionFetcher
from workers.rate_limiter import RateLimiter
import redis

def main():
    print("=" * 60)
    print("IAAI Full Site Scanner")
    print("=" * 60)
    print("\nЭтот скрипт сканирует все записи IAAI за последний год")
    print("Данные сохраняются в базу данных через Kafka\n")
    
    # Настройки
    redis_url = os.getenv('REDIS_URL', 'redis://redis:6379/0')
    months_back = int(os.getenv('MONTHS_BACK', '12'))
    max_pages = os.getenv('MAX_PAGES')
    max_pages = int(max_pages) if max_pages else None
    max_vehicles = os.getenv('MAX_VEHICLES')
    max_vehicles = int(max_vehicles) if max_vehicles else None
    
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
        print("✓ Chrome Driver доступен")
    else:
        print("⚠ Chrome Driver недоступен (только cloudscraper)")
    
    print(f"\n3. Параметры сканирования...")
    print(f"   Период: последние {months_back} месяцев")
    if max_pages:
        print(f"   Максимальное количество страниц: {max_pages}")
    else:
        print(f"   Максимальное количество страниц: без ограничений")
    if max_vehicles:
        print(f"   Максимальное количество автомобилей: {max_vehicles}")
    else:
        print(f"   Максимальное количество автомобилей: без ограничений")
    print(f"   Размер батча для Kafka: 50 записей")
    
    print("\n4. Запуск сканирования...")
    print("   ⚠ Это может занять много времени")
    print("   Данные будут сохраняться в базу по мере сканирования\n")
    
    start_time = time.time()
    
    try:
        vehicles = fetcher.scan_all_iaai_listings(
            months_back=months_back,
            max_pages=max_pages,
            max_vehicles=max_vehicles
        )
        
        elapsed_time = time.time() - start_time
        
        print("\n" + "=" * 60)
        print("Сканирование завершено!")
        print("=" * 60)
        print(f"\n✓ Всего обработано: {len(vehicles)} автомобилей")
        elapsed_minutes = elapsed_time / 60
        print(f"✓ Время выполнения: {elapsed_minutes:.1f} минут")
        if elapsed_minutes > 0:
            print(f"✓ Средняя скорость: {len(vehicles)/elapsed_minutes:.1f} автомобилей/минуту")
        else:
            print(f"✓ Средняя скорость: N/A (слишком быстро)")
        
        print("\n5. Проверка сохранения в БД...")
        print(f"   Выполните в Rails console:")
        print(f"   docker compose exec rails_api bundle exec rails console")
        print(f"\n   Затем:")
        print(f"   Vehicle.where(source: 'iaai').count")
        print(f"   Vehicle.where(source: 'iaai').order(created_at: :desc).limit(10)")
        
        return 0
        
    except KeyboardInterrupt:
        print("\n\n⚠ Сканирование прервано пользователем")
        return 1
    except Exception as e:
        print(f"\n✗ Ошибка при сканировании: {e}")
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

