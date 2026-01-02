#!/usr/bin/env python3
"""
Скрипт для анализа структуры страницы IAAI с помощью Playwright
Помогает найти правильные селекторы для парсинга
"""
import os
from playwright.sync_api import sync_playwright
import time
from bs4 import BeautifulSoup

def main():
    print("=" * 60)
    print("Анализ структуры страницы IAAI")
    print("=" * 60)
    
    url = 'https://www.iaai.com/Vehicles'
    
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )
        page = context.new_page()
        
        print(f"\n1. Загрузка страницы: {url}")
        page.goto(url, wait_until='domcontentloaded', timeout=120000)
        
        print("2. Ожидание загрузки JavaScript...")
        time.sleep(10)
        
        # Прокручиваем страницу
        print("3. Прокрутка страницы...")
        page.evaluate("window.scrollTo(0, document.body.scrollHeight/2);")
        time.sleep(3)
        page.evaluate("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(3)
        
        # Проверяем наличие результатов
        html = page.content()
        soup = BeautifulSoup(html, 'html.parser')
        
        print("\n4. Анализ структуры:")
        print(f"   Размер HTML: {len(html)} bytes")
        
        # Ищем searchHistory
        search_history = soup.find('div', id='searchHistory')
        if search_history:
            print(f"\n   ✓ Найден div#searchHistory")
            print(f"     data-resultcount: {search_history.get('data-resultcount', 'N/A')}")
            print(f"     data-currentpage: {search_history.get('data-currentpage', 'N/A')}")
            print(f"     data-pagesize: {search_history.get('data-pagesize', 'N/A')}")
        
        # Ищем все ссылки
        links = soup.find_all('a', href=True)
        print(f"\n   Всего ссылок: {len(links)}")
        
        # Ищем ссылки на автомобили
        vehicle_links = [a for a in links if any(pattern in a.get('href', '') for pattern in ['/Vehicle/', '/Lot/', '/Detail/', '/vehicle/', '/lot/', '/detail/'])]
        print(f"   Ссылок на Vehicle/Lot/Detail: {len(vehicle_links)}")
        
        if vehicle_links:
            print("\n   Примеры ссылок:")
            for link in vehicle_links[:5]:
                print(f"     - {link.get('href')}")
        
        # Ищем контейнеры с результатами
        result_containers = soup.find_all(['div', 'ul', 'section'], class_=lambda x: x and any(word in str(x).lower() for word in ['result', 'listing', 'item', 'vehicle', 'lot', 'grid', 'search']))
        print(f"\n   Контейнеров с результатами: {len(result_containers)}")
        
        # Сохраняем HTML для анализа
        debug_file = '/app/iaai_analysis_debug.html'
        with open(debug_file, 'w', encoding='utf-8') as f:
            f.write(html)
        print(f"\n   💾 HTML сохранен в {debug_file}")
        
        # Проверяем наличие AJAX запросов
        print("\n5. Проверка сетевых запросов...")
        # Ждем еще немного для AJAX
        time.sleep(10)
        html_after_wait = page.content()
        if len(html_after_wait) != len(html):
            print(f"   ⚠ HTML изменился после ожидания ({len(html)} -> {len(html_after_wait)} bytes)")
            soup2 = BeautifulSoup(html_after_wait, 'html.parser')
            vehicle_links2 = [a for a in soup2.find_all('a', href=True) if any(pattern in a.get('href', '') for pattern in ['/Vehicle/', '/Lot/', '/Detail/'])]
            print(f"   Ссылок на Vehicle/Lot/Detail после ожидания: {len(vehicle_links2)}")
            if vehicle_links2:
                print("\n   Примеры ссылок после ожидания:")
                for link in vehicle_links2[:5]:
                    print(f"     - {link.get('href')}")
        
        browser.close()
        
        print("\n" + "=" * 60)
        print("Анализ завершен")
        print("=" * 60)

if __name__ == '__main__':
    main()




