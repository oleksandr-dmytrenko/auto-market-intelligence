#!/usr/bin/env python3
"""
Простой тест IAAI скрапера для одной страницы
"""
import os
import sys
import json
import time
from workers.iaai_scraper import IAAIScraper
from workers.rate_limiter import RateLimiter
import redis

def main():
    print("=" * 60)
    print("Тест: IAAI Scraper (1 страница)")
    print("=" * 60)
    
    # Настройки
    redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    
    # Подключаемся к Redis
    print("\n1. Подключение к Redis...")
    try:
        redis_client = redis.from_url(redis_url)
        redis_client.ping()
        print("✓ Redis подключен")
    except Exception as e:
        print(f"⚠ Redis недоступен: {e}")
        print("  Продолжаем без Redis (rate limiter не будет работать)")
        redis_client = None
    
    # Создаем rate limiter и scraper
    print("\n2. Инициализация скрапера...")
    rate_limiter = RateLimiter(redis_client) if redis_client else None
    scraper = IAAIScraper(rate_limiter=rate_limiter)
    
    if scraper.page:
        print("✓ Playwright инициализирован")
    if scraper.scraper:
        print("✓ Cloudscraper инициализирован")
    
    # Тестовые параметры - получаем все автомобили с первой страницы
    print("\n3. Параметры поиска...")
    print("   Получаем все автомобили с первой страницы списка")
    
    print("\n4. Запуск скрапинга...")
    print("   Скрапим первую страницу списка всех автомобилей\n")
    
    try:
        # Используем метод для получения всех автомобилей с первой страницы
        # Сначала получаем список с listing page
        listing_url = scraper.parser.build_all_vehicles_url(page=1)
        print(f"URL списка: {listing_url}")
        
        # Получаем HTML страницы списка
        html = None
        if scraper.page:
            print("  Используем Playwright для получения страницы списка...")
            html = scraper._fetch_with_playwright(listing_url, wait_for_ajax=True)
        
        if not html:
            print("  Playwright не сработал, пробуем Cloudscraper...")
            html = scraper._fetch_with_cloudscraper(listing_url)
        
        if not html:
            print("✗ Не удалось получить страницу списка")
            return 1
        
        print(f"✓ Страница списка получена ({len(html)} символов)")
        
        # Парсим страницу списка
        listings = scraper.parser.parse_listing_page(html)
        print(f"✓ Найдено {len(listings)} лотов на странице")
        
        if not listings:
            print("⚠ Лоты не найдены. Возможные причины:")
            print("  - Изменилась структура HTML")
            print("  - Cloudflare блокирует запросы")
            print("  - Нет активных лотов")
            return 1
        
        # Ограничиваем до 3 лотов для теста
        test_listings = listings[:3]
        print(f"\n5. Получаем детальную информацию для {len(test_listings)} лотов...")
        
        vehicles = []
        for i, listing in enumerate(test_listings, 1):
            detail_url = listing.get('detail_url') or listing.get('auction_url')
            source_id = listing.get('source_id')
            
            if not detail_url:
                print(f"  [{i}] Пропуск - нет URL")
                continue
            
            print(f"\n  [{i}/{len(test_listings)}] Лот {source_id}")
            print(f"      URL: {detail_url}")
            
            # Вежливая задержка между запросами
            if i > 1:
                delay = 3.0
                print(f"      Ожидание {delay} сек...")
                time.sleep(delay)
            
            # Получаем детальную страницу
            detail_html = None
            if scraper.page:
                detail_html = scraper._fetch_with_playwright(detail_url, wait_for_ajax=True)
            
            if not detail_html:
                detail_html = scraper._fetch_with_cloudscraper(detail_url)
            
            if not detail_html:
                print(f"      ✗ Не удалось получить детальную страницу")
                continue
            
            print(f"      ✓ Детальная страница получена")
            
            # Парсим детальную страницу
            detail_data = scraper.parser.parse_detail_page(detail_html, detail_url)
            
            if not detail_data:
                print(f"      ✗ Не удалось распарсить детальную страницу")
                continue
            
            detail_data['auction_status'] = 'active'
            vehicles.append(detail_data)
            
            # Выводим основную информацию
            print(f"      ✓ Распарсено:")
            print(f"         Make: {detail_data.get('make', 'N/A')}")
            print(f"         Model: {detail_data.get('model', 'N/A')}")
            print(f"         Year: {detail_data.get('year', 'N/A')}")
            print(f"         Stock #: {detail_data.get('stock_number', 'N/A')}")
            print(f"         Partial VIN: {detail_data.get('partial_vin', 'N/A')}")
            print(f"         VIN: {detail_data.get('vin', 'N/A')}")
            print(f"         Price: ${detail_data.get('price', 'N/A')}")
            print(f"         Mileage: {detail_data.get('mileage', 'N/A')}")
            print(f"         Images: {len(detail_data.get('images', []))}")
        
        print("\n" + "=" * 60)
        print("Результаты теста")
        print("=" * 60)
        print(f"\n✓ Успешно обработано: {len(vehicles)} из {len(test_listings)} лотов")
        
        if vehicles:
            print("\nДетали первого автомобиля:")
            vehicle = vehicles[0]
            print(json.dumps({
                'source': vehicle.get('source'),
                'source_id': vehicle.get('source_id'),
                'stock_number': vehicle.get('stock_number'),
                'lot_id': vehicle.get('lot_id'),
                'make': vehicle.get('make'),
                'model': vehicle.get('model'),
                'year': vehicle.get('year'),
                'partial_vin': vehicle.get('partial_vin'),
                'vin': vehicle.get('vin'),
                'price': vehicle.get('price'),
                'mileage': vehicle.get('mileage'),
                'color': vehicle.get('color'),
                'damage_type': vehicle.get('damage_type'),
                'auction_status': vehicle.get('auction_status'),
                'image_count': len(vehicle.get('images', []))
            }, indent=2, ensure_ascii=False))
        
        print("\n✓ Тест завершен успешно!")
        return 0
        
    except Exception as e:
        print(f"\n✗ Ошибка при скрапинге: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    finally:
        # Закрываем Playwright
        if scraper.browser:
            try:
                scraper.browser.close()
                print("\n✓ Playwright закрыт")
            except:
                pass
        if scraper.playwright:
            try:
                scraper.playwright.stop()
            except:
                pass

if __name__ == '__main__':
    sys.exit(main())


