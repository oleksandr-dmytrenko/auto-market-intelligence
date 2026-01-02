"""
Copart.com scraper with Cloudflare bypass
Uses Playwright (primary) and cloudscraper (fallback)
Implements polite delays and human-like behavior
"""
import cloudscraper
import time
import random
import os
from typing import List, Dict, Optional
from .copart_parser import CopartParser
from .rate_limiter import RateLimiter
from bs4 import BeautifulSoup

try:
    from playwright.sync_api import sync_playwright, Browser, Page
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False
    print("Warning: playwright not available. Install with: pip install playwright && playwright install chromium")


class CopartScraper:
    """Скрапер для Copart.com с обходом Cloudflare"""
    
    # Ротация User-Agents для лучшего обхода
    USER_AGENTS = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
    ]
    
    def __init__(self, driver=None, rate_limiter: Optional[RateLimiter] = None):
        """
        Инициализация скрапера
        
        Args:
            driver: Selenium driver (опционально, для fallback)
            rate_limiter: Rate limiter для контроля частоты запросов
        """
        self.driver = driver
        self.rate_limiter = rate_limiter
        self.parser = CopartParser()
        self.scraper = None
        self.session_initialized = False
        self.playwright = None
        self.browser = None
        self.page = None
        self._init_playwright()
        self._init_cloudscraper()
    
    def _init_playwright(self):
        """Инициализирует Playwright для JavaScript-рендеринга"""
        if not PLAYWRIGHT_AVAILABLE:
            return
        
        try:
            self.playwright = sync_playwright().start()
            # Запускаем браузер в headless режиме с улучшенным обходом детекции
            self.browser = self.playwright.chromium.launch(
                headless=True,
                args=[
                    '--disable-blink-features=AutomationControlled',
                    '--disable-dev-shm-usage',
                    '--no-sandbox',
                ]
            )
            
            # Создаем контекст с реалистичными настройками
            context = self.browser.new_context(
                viewport={'width': 1920, 'height': 1080},
                user_agent=random.choice(self.USER_AGENTS),
                locale='en-US',
                timezone_id='America/New_York',
            )
            
            # Добавляем stealth скрипты
            context.add_init_script("""
                Object.defineProperty(navigator, 'webdriver', {
                    get: () => undefined
                });
                window.chrome = {
                    runtime: {},
                };
            """)
            
            self.page = context.new_page()
            print("  ✓ Playwright initialized for Copart (best for JavaScript rendering)")
        except Exception as e:
            print(f"  ⚠ Could not initialize Playwright: {e}")
            self.playwright = None
            self.browser = None
            self.page = None
    
    def __del__(self):
        """Закрываем Playwright при удалении объекта"""
        if self.browser:
            try:
                self.browser.close()
            except:
                pass
        if self.playwright:
            try:
                self.playwright.stop()
            except:
                pass
    
    def _init_cloudscraper(self):
        """Инициализирует cloudscraper для обхода Cloudflare"""
        try:
            self.scraper = cloudscraper.create_scraper(
                browser={
                    'browser': 'chrome',
                    'platform': 'windows',
                    'desktop': True
                }
            )
            self.session_initialized = True
            print("  ✓ Cloudscraper initialized for Copart")
        except Exception as e:
            print(f"  ⚠ Could not initialize cloudscraper: {e}")
            self.scraper = None
    
    def _fetch_with_playwright(self, url: str, wait_for_ajax: bool = True) -> Optional[str]:
        """
        Получает HTML через Playwright
        
        Args:
            url: URL для запроса
            wait_for_ajax: Ждать ли загрузки AJAX контента
            
        Returns:
            HTML содержимое или None при ошибке
        """
        if not self.page:
            return None
        
        try:
            # Переходим на страницу
            self.page.goto(url, wait_until='networkidle', timeout=30000)
            
            # Ждём загрузки контента
            if wait_for_ajax:
                time.sleep(2)  # Даём время на загрузку AJAX контента
            
            # Получаем HTML
            html = self.page.content()
            return html
            
        except Exception as e:
            print(f"  ⚠ Playwright fetch error: {e}")
            return None
    
    def _fetch_with_cloudscraper(self, url: str) -> Optional[str]:
        """
        Получает HTML через cloudscraper
        
        Args:
            url: URL для запроса
            
        Returns:
            HTML содержимое или None при ошибке
        """
        if not self.scraper:
            return None
        
        try:
            headers = {
                'User-Agent': random.choice(self.USER_AGENTS),
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'Accept-Encoding': 'gzip, deflate, br',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1',
            }
            
            response = self.scraper.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                return response.text
            else:
                print(f"  ⚠ Cloudscraper returned status {response.status_code}")
                return None
                
        except Exception as e:
            print(f"  ⚠ Cloudscraper fetch error: {e}")
            return None
    
    def scrape_listings(self, make: str, model: str, from_year: int = None, to_year: int = None, limit: int = 10) -> List[Dict]:
        """
        Скрапит список результатов с вежливыми задержками
        
        Args:
            make: Марка автомобиля
            model: Модель
            from_year: Год от
            to_year: Год до
            limit: Максимальное количество результатов
            
        Returns:
            Список словарей с данными автомобилей
        """
        search_url = self.parser.build_search_url(make, model, from_year, to_year)
        print(f"Scraping Copart: {search_url}")
        print(f"Being polite: using delays between requests to mimic human behavior")
        
        if self.rate_limiter:
            key = 'rate_limit:scraper:copart'
            if self.rate_limiter.wait_if_needed(key):
                print("  ⚠ Rate limit reached, waiting...")
                return []
            self.rate_limiter.record_request(key)
        
        # Пробуем сначала Playwright, затем cloudscraper
        html = None
        if self.page:
            html = self._fetch_with_playwright(search_url, wait_for_ajax=True)
        
        if not html:
            html = self._fetch_with_cloudscraper(search_url)
        
        if not html:
            print("✗ Failed to fetch search page")
            return []
        
        listings = self.parser.parse_listing_page(html)
        print(f"  Found {len(listings)} listings on search page")
        
        # Ограничиваем количество результатов
        if limit:
            listings = listings[:limit]
        
        return listings
    
    def scrape_detail_page(self, detail_url: str) -> Optional[Dict]:
        """
        Скрапит детальную страницу автомобиля
        
        Args:
            detail_url: URL детальной страницы
            
        Returns:
            Словарь с данными автомобиля или None при ошибке
        """
        if self.rate_limiter:
            key = 'rate_limit:scraper:copart:detail'
            if self.rate_limiter.wait_if_needed(key):
                print("  ⚠ Rate limit reached, waiting...")
                return None
            self.rate_limiter.record_request(key)
        
        # Вежливая задержка между запросами
        time.sleep(random.uniform(2, 4))
        
        # Пробуем сначала Playwright, затем cloudscraper
        html = None
        if self.page:
            html = self._fetch_with_playwright(detail_url, wait_for_ajax=True)
        
        if not html:
            html = self._fetch_with_cloudscraper(detail_url)
        
        if not html:
            print(f"✗ Failed to fetch detail page: {detail_url}")
            return None
        
        # Парсим детальную страницу
        data = self.parser.parse_detail_page(html, detail_url)
        
        return data



