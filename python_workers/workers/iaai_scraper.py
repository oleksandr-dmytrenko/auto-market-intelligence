"""
IAAI.com scraper with Cloudflare bypass
Uses Playwright (primary), cloudscraper (secondary) and undetected-chromedriver (fallback)
Implements polite delays and human-like behavior
"""
import cloudscraper
import time
import random
import os
from typing import List, Dict, Optional
from .iaai_parser import IAAIParser
from .rate_limiter import RateLimiter
from bs4 import BeautifulSoup

try:
    from playwright.sync_api import sync_playwright, Browser, Page
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False
    print("Warning: playwright not available. Install with: pip install playwright && playwright install chromium")

class IAAIScraper:
    """Скрапер для IAAI.com с обходом Cloudflare"""
    
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
        self.parser = IAAIParser()
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
            print("  ✓ Playwright initialized (best for JavaScript rendering)")
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
        """Инициализирует cloudscraper с оптимальными настройками"""
        try:
            self.scraper = cloudscraper.create_scraper(
                browser={
                    'browser': 'chrome',
                    'platform': 'windows',
                    'desktop': True
                },
                delay=15
            )
        except Exception as e:
            print(f"Warning: Could not create advanced cloudscraper: {e}")
            try:
                self.scraper = cloudscraper.create_scraper(delay=15)
            except:
                self.scraper = cloudscraper.create_scraper()
        
        self._setup_headers()
    
    def _setup_headers(self):
        """Настраивает реалистичные заголовки с ротацией User-Agent"""
        user_agent = random.choice(self.USER_AGENTS)
        
        if 'Macintosh' in user_agent:
            platform = 'MacIntel'
            accept_language = 'en-US,en;q=0.9'
        elif 'Firefox' in user_agent:
            platform = 'Win32'
            accept_language = 'en-US,en;q=0.5'
        else:
            platform = 'Win32'
            accept_language = 'en-US,en;q=0.9'
        
        self.scraper.headers.update({
            'User-Agent': user_agent,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
            'Accept-Language': accept_language,
            'Accept-Encoding': 'gzip, deflate, br',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
            'Sec-Ch-Ua': '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
            'Sec-Ch-Ua-Mobile': '?0',
            'Sec-Ch-Ua-Platform': f'"{platform}"',
            'Cache-Control': 'max-age=0',
            'DNT': '1',
        })
    
    def _polite_delay(self, min_seconds: float = 2.0, max_seconds: float = 5.0):
        """Вежливая задержка между запросами"""
        delay = random.uniform(min_seconds, max_seconds)
        time.sleep(delay)
    
    def _longer_delay(self, base_seconds: float = 5.0):
        """Более длительная задержка"""
        delay = random.uniform(base_seconds, base_seconds * 2)
        time.sleep(delay)
    
    def _initialize_session(self):
        """Инициализирует сессию с получением cookies"""
        if self.session_initialized:
            return True
        
        try:
            print("  Initializing session (getting cookies)...")
            
            referrers = [
                'https://www.google.com/',
                'https://www.google.com/search?q=iaai+auctions',
                'https://www.bing.com/',
            ]
            referrer = random.choice(referrers)
            self.scraper.headers['Referer'] = referrer
            
            response = self.scraper.get('https://www.iaai.com/', timeout=20)
            
            self._polite_delay(3.0, 6.0)
            
            if response.status_code == 200 and len(response.text) > 1000:
                print("  ✓ Session initialized, cookies received")
                self.session_initialized = True
                self.scraper.headers['Referer'] = 'https://www.iaai.com/'
                return True
            else:
                print(f"  ⚠ Homepage response: {response.status_code}, size: {len(response.text)}")
                self.session_initialized = True
                return True
                
        except Exception as e:
            print(f"  ⚠ Session initialization warning: {e}")
            self.session_initialized = True
            return False
    
    def _fetch_with_cloudscraper(self, url: str, retries: int = 3) -> str:
        """Получает страницу используя cloudscraper"""
        if not self.session_initialized:
            self._initialize_session()
        
        for attempt in range(retries):
            try:
                print(f"  Fetching {url} (attempt {attempt + 1}/{retries})...")
                
                if attempt > 0:
                    self._setup_headers()
                    delay = random.uniform(10, 20) * (attempt + 1)
                    print(f"  Waiting {delay:.1f} seconds before retry (being polite)...")
                    time.sleep(delay)
                
                if 'iaai.com' in url:
                    self.scraper.headers['Referer'] = 'https://www.iaai.com/'
                else:
                    self.scraper.headers['Referer'] = 'https://www.google.com/'
                
                if attempt == 0:
                    self._polite_delay(1.0, 3.0)
                
                response = self.scraper.get(
                    url, 
                    timeout=45,
                    allow_redirects=True,
                    verify=True
                )
                
                self._polite_delay(2.0, 4.0)
                
                if response.status_code == 403:
                    print(f"  ✗ 403 Forbidden - Cloudflare blocking")
                    if attempt < retries - 1:
                        continue
                    return ""
                
                if response.status_code == 429:
                    print(f"  ✗ 429 Too Many Requests - Rate limit")
                    if attempt < retries - 1:
                        delay = random.uniform(30, 60)
                        print(f"  Waiting {delay:.1f} seconds (rate limit)...")
                        time.sleep(delay)
                    continue
                
                response.raise_for_status()
                
                page_text = response.text.lower()
                cloudflare_indicators = [
                    'checking your browser',
                    'just a moment',
                    'ddos protection',
                    'cf-browser-verification',
                    '403 forbidden',
                    'access denied',
                    'ray id',
                    '__cf_bm',
                    'cf_clearance',
                    'challenge-platform'
                ]
                
                is_challenge = any(indicator in page_text for indicator in cloudflare_indicators)
                min_size = 2000
                page_size_ok = len(response.text) > min_size
                
                if not is_challenge and page_size_ok:
                    print(f"  ✓ Successfully fetched page ({len(response.text)} bytes)")
                    # Сохраняем HTML для анализа
                    try:
                        debug_file = '/app/iaai_cloudscraper_debug.html'
                        with open(debug_file, 'w', encoding='utf-8') as f:
                            f.write(response.text)
                        print(f"  💾 HTML saved to {debug_file} for analysis")
                    except:
                        pass
                    return response.text
                else:
                    if is_challenge:
                        print(f"  ⚠ Cloudflare challenge detected")
                    elif not page_size_ok:
                        print(f"  ⚠ Page too short ({len(response.text)} bytes)")
                    
                    if attempt < retries - 1:
                        delay = random.uniform(10, 20) * (attempt + 1)
                        print(f"  Waiting {delay:.1f} seconds before retry...")
                        time.sleep(delay)
                    
            except Exception as e:
                error_msg = str(e)
                if '403' in error_msg or 'Forbidden' in error_msg:
                    print(f"  ✗ 403 Forbidden - Cloudflare blocking (attempt {attempt + 1})")
                elif '429' in error_msg or 'Too Many Requests' in error_msg:
                    print(f"  ✗ 429 Rate Limit (attempt {attempt + 1})")
                elif 'timeout' in error_msg.lower():
                    print(f"  ✗ Timeout (attempt {attempt + 1})")
                else:
                    print(f"  ✗ Error on attempt {attempt + 1}: {e}")
                
                if attempt < retries - 1:
                    delay = random.uniform(5, 15) * (2 ** attempt)
                    print(f"  Waiting {delay:.1f} seconds before retry...")
                    time.sleep(delay)
        
        return ""
    
    def _fetch_with_playwright(self, url: str, wait_for_ajax: bool = True) -> Optional[str]:
        """
        Получает страницу используя Playwright (лучший для JavaScript-рендеринга)
        
        Returns:
            HTML содержимое страницы или None
        """
        if not self.page:
            return None
        
        try:
            print(f"  Using Playwright for {url} (JavaScript rendering)...")
            
            self._polite_delay(2.0, 4.0)
            
            # Переходим на страницу с разумным timeout
            try:
                # Для детальных страниц используем меньший timeout
                timeout = 30000 if wait_for_ajax else 20000
                self.page.goto(url, wait_until='domcontentloaded', timeout=timeout)
            except Exception as e:
                if 'timeout' in str(e).lower():
                    print("  ⚠ Timeout, but page may have loaded partially")
                    # Продолжаем, возможно страница загрузилась частично
                else:
                    print(f"  ⚠ Navigation error: {e}, continuing...")
            
            # Ждем загрузки JavaScript контента (меньше для детальных страниц)
            if wait_for_ajax:
                print("  Waiting for JavaScript content to load...")
                time.sleep(random.uniform(3, 5))
            else:
                time.sleep(random.uniform(1, 2))  # Быстрее для детальных страниц
            
            # Ждем загрузки результатов поиска (AJAX) только для страниц поиска
            if wait_for_ajax and '/Search' in url:
                print("  Waiting for search results to load via AJAX...")
                try:
                    waited = 0
                    max_wait = 20  # Уменьшено с 30 до 20
                    found_results = False
                    
                    while waited < max_wait and not found_results:
                        # Проверяем наличие результатов в HTML
                        html_content = self.page.content()
                        if 'data-resultcount' in html_content:
                            # Проверяем, что data-resultcount не пустой
                            soup = BeautifulSoup(html_content, 'html.parser')
                            search_history = soup.find('div', id='searchHistory')
                            if search_history:
                                result_count = search_history.get('data-resultcount', '')
                                if result_count and result_count != '':
                                    print(f"  ✓ Results loaded (count: {result_count})")
                                    found_results = True
                                    break
                        
                        time.sleep(2)
                        waited += 2
                        if waited % 10 == 0:
                            print(f"  ... still waiting for results ({waited}/{max_wait} sec)")
                    
                    if not found_results:
                        print("  ⚠ Results may not have loaded, continuing anyway...")
                    
                except Exception as e:
                    print(f"  ⚠ Error waiting for results: {e}")
            
            # Дополнительное ожидание для полной загрузки (уменьшено)
            time.sleep(random.uniform(1, 2))
            
            # Прокручиваем страницу для загрузки ленивых элементов (только для страниц поиска)
            if wait_for_ajax:
                print("  Scrolling page to trigger lazy loading...")
                try:
                    self.page.evaluate("window.scrollTo(0, document.body.scrollHeight/2);")
                    time.sleep(1)
                    self.page.evaluate("window.scrollTo(0, document.body.scrollHeight);")
                    time.sleep(1)
                except:
                    pass
            
            # Проверяем размер страницы
            page_length = len(self.page.content())
            print(f"  Page length: {page_length} bytes")
            
            if page_length < 1000:
                print("  ⚠ Page seems too short, waiting more...")
                time.sleep(5)
                page_length = len(self.page.content())
                print(f"  Page length after wait: {page_length} bytes")
            
            # Проверяем на Incapsula challenge
            page_text = self.page.content().lower()
            challenge_indicators = [
                'incapsula', '_incapsula_resource', 'checking your browser',
                'just a moment', 'ddos protection'
            ]
            
            is_challenge = any(indicator in page_text for indicator in challenge_indicators)
            
            if is_challenge:
                print("  ⚠ Incapsula challenge detected, waiting...")
                max_wait = 15 if wait_for_ajax else 5  # Меньше для детальных страниц
                waited = 0
                while waited < max_wait:
                    time.sleep(1)  # Быстрее проверяем
                    waited += 1
                    page_text = self.page.content().lower()
                    if not any(indicator in page_text for indicator in challenge_indicators):
                        print(f"  ✓ Challenge passed after {waited} seconds")
                        break
                    if waited % 5 == 0:
                        print(f"  ... still waiting ({waited}/{max_wait} sec)")
            
            self._polite_delay(2.0, 4.0)
            
            html = self.page.content()
            
            # Сохраняем HTML для анализа
            try:
                debug_file = '/app/iaai_playwright_debug.html'
                with open(debug_file, 'w', encoding='utf-8') as f:
                    f.write(html)
                print(f"  💾 HTML saved to {debug_file} for analysis ({len(html)} bytes)")
            except:
                pass
            
            return html
            
        except Exception as e:
            print(f"  ✗ Playwright error: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def _fetch_with_selenium(self, url: str) -> Optional[str]:
        """Получает страницу используя Selenium (fallback)"""
        if not self.driver:
            return None
        
        try:
            print(f"  Using Selenium for {url}")
            
            self._polite_delay(2.0, 4.0)
            
            self.driver.get(url)
            
            # Ждем загрузки страницы и JavaScript
            print("  Waiting for page to load...")
            time.sleep(random.uniform(8, 12))
            
            # Проверяем, что страница загрузилась (не пустая)
            page_length = len(self.driver.page_source)
            print(f"  Page length: {page_length} bytes")
            
            if page_length < 1000:
                print("  ⚠ Page seems too short, waiting more...")
                time.sleep(5)
                page_length = len(self.driver.page_source)
                print(f"  Page length after wait: {page_length} bytes")
            
            # Прокручиваем страницу для загрузки ленивых элементов
            print("  Scrolling page to load lazy elements...")
            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight/3);")
            time.sleep(3)
            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight/2);")
            time.sleep(3)
            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(3)
            self.driver.execute_script("window.scrollTo(0, 0);")
            time.sleep(2)
            
            # Проверяем количество ссылок
            try:
                links_count = len(self.driver.find_elements("tag name", "a"))
                print(f"  Found {links_count} links on page")
            except:
                links_count = 0
                print(f"  Could not count links")
            
            page_text = self.driver.page_source.lower()
            
            # Сохраняем HTML для отладки если страница короткая
            if page_length < 5000:
                try:
                    debug_file = '/app/iaai_selenium_debug.html'
                    with open(debug_file, 'w', encoding='utf-8') as f:
                        f.write(self.driver.page_source)
                    print(f"  💾 Short page saved to {debug_file} for analysis")
                    print(f"  Page preview (first 500 chars): {self.driver.page_source[:500]}")
                except:
                    pass
            # Проверяем различные индикаторы Incapsula/Cloudflare challenge
            challenge_indicators = [
                'checking your browser',
                'just a moment',
                'incapsula',
                '_incapsula_resource',
                'ddos protection',
                'cf-browser-verification',
                'challenge-platform',
                'ray id',
                'cf_clearance',
                '__cf_bm',
                'access denied',
                '403 forbidden'
            ]
            
            is_challenge = any(indicator in page_text for indicator in challenge_indicators)
            
            if is_challenge:
                print("  ⚠ Incapsula/Cloudflare challenge detected, waiting...")
                print("  Performing human-like interactions to bypass...")
                
                # Имитируем человеческое поведение
                try:
                    # Прокручиваем страницу (человек обычно прокручивает)
                    self.driver.execute_script("window.scrollTo(0, 100);")
                    time.sleep(random.uniform(1, 2))
                    self.driver.execute_script("window.scrollTo(0, 200);")
                    time.sleep(random.uniform(1, 2))
                    
                    # Движения мыши (если возможно)
                    try:
                        from selenium.webdriver.common.action_chains import ActionChains
                        actions = ActionChains(self.driver)
                        actions.move_by_offset(random.randint(10, 50), random.randint(10, 50)).perform()
                        time.sleep(random.uniform(0.5, 1))
                    except:
                        pass
                except:
                    pass
                
                max_wait = 90  # Увеличено до 90 секунд для Incapsula
                waited = 0
                check_interval = 3
                
                while waited < max_wait:
                    time.sleep(check_interval)
                    waited += check_interval
                    
                    # Обновляем содержимое страницы
                    page_text = self.driver.page_source.lower()
                    page_length = len(self.driver.page_source)
                    
                    # Проверяем, прошла ли challenge
                    is_still_challenge = any(indicator in page_text for indicator in challenge_indicators)
                    
                    if not is_still_challenge and page_length > 5000:
                        print(f"  ✓ Challenge bypassed after {waited} seconds (page: {page_length} bytes)")
                        break
                    
                    # Периодически имитируем активность
                    if waited % 15 == 0:
                        try:
                            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight/4);")
                            time.sleep(1)
                        except:
                            pass
                    
                    if waited % 10 == 0:
                        print(f"  ... still waiting ({waited}/{max_wait} sec), page: {page_length} bytes")
                
                # Финальная проверка
                page_text = self.driver.page_source.lower()
                page_length = len(self.driver.page_source)
                is_still_challenge = any(indicator in page_text for indicator in challenge_indicators)
                
                if is_still_challenge or page_length < 5000:
                    print(f"  ✗ Challenge not bypassed after {max_wait} seconds")
                    print(f"  Page length: {page_length} bytes")
                    found_indicators = [ind for ind in challenge_indicators if ind in page_text]
                    if found_indicators:
                        print(f"  Challenge indicators found: {found_indicators}")
                    return None
            
            self._polite_delay(2.0, 4.0)
            
            return self.driver.page_source
            
        except Exception as e:
            print(f"  ✗ Selenium error: {e}")
            return None
    
    def scrape_all_listings(self, months_back: int = 12, max_pages: int = None, max_vehicles: int = None, batch_size: int = 50) -> List[Dict]:
        """
        Сканирует все записи сайта за указанный период с пагинацией
        
        Args:
            months_back: Количество месяцев назад для фильтрации (по умолчанию 12 - год)
            max_pages: Максимальное количество страниц для сканирования (None = без ограничений)
            max_vehicles: Максимальное количество автомобилей для сканирования (None = без ограничений)
            batch_size: Размер батча для отправки в Kafka
            
        Returns:
            Список всех найденных автомобилей
        """
        from datetime import datetime, timedelta
        from kafka import KafkaProducer
        import json
        import os
        
        print(f"Scraping all IAAI listings from last {months_back} months")
        print(f"Being polite: using delays between requests to mimic human behavior")
        
        if self.rate_limiter:
            key = 'rate_limit:scraper:iaai'
            if self.rate_limiter.wait_if_needed(key):
                print("  ⚠ Rate limit reached, waiting...")
                return []
        
        all_vehicles = []
        page = 1
        total_pages = None
        consecutive_empty_pages = 0
        max_empty_pages = 3  # Останавливаемся после 3 пустых страниц подряд
        
        # Kafka producer для батч-отправки
        kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
        producer = None
        try:
            producer = KafkaProducer(
                bootstrap_servers=kafka_brokers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda k: k.encode('utf-8') if k else None
            )
        except Exception as e:
            print(f"  ⚠ Could not create Kafka producer: {e}")
        
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
            
            # Получаем страницу (приоритет: Playwright > Selenium > cloudscraper)
            html = None
            if self.page:
                html = self._fetch_with_playwright(url)
                if not html:
                    print("  Playwright failed, trying cloudscraper...")
                    html = self._fetch_with_cloudscraper(url)
            elif self.driver:
                html = self._fetch_with_selenium(url)
                if not html:
                    print("  Selenium failed, trying cloudscraper...")
                    html = self._fetch_with_cloudscraper(url)
            else:
                html = self._fetch_with_cloudscraper(url)
            
            if not html:
                print(f"  ✗ Failed to fetch page {page}")
                consecutive_empty_pages += 1
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
            
            # Получаем детальную информацию для каждого листинга
            page_vehicles = []
            for i, listing in enumerate(listings, 1):
                detail_url = listing.get('detail_url')
                if not detail_url:
                    continue
                
                print(f"    [{i}/{len(listings)}] Fetching detail page...")
                
                if i > 1:
                    self._polite_delay(2.0, 4.0)
                
                # Приоритет: Playwright > cloudscraper > Selenium
                # Для детальных страниц не ждем AJAX
                detail_html = None
                if self.page:
                    detail_html = self._fetch_with_playwright(detail_url, wait_for_ajax=False)
                if not detail_html:
                    detail_html = self._fetch_with_cloudscraper(detail_url)
                if not detail_html and self.driver:
                    detail_html = self._fetch_with_selenium(detail_url)
                
                if detail_html:
                    detail_data = self.parser.parse_detail_page(detail_html, detail_url)
                    if detail_data:
                        # Фильтруем по дате (последние N месяцев)
                        if detail_data.get('auction_end_date'):
                            auction_date = datetime.fromtimestamp(detail_data['auction_end_date'])
                            cutoff_date = datetime.now() - timedelta(days=months_back * 30)
                            if auction_date < cutoff_date:
                                print(f"      ⏭ Skipping (too old: {auction_date.date()})")
                                continue
                        
                        detail_data['auction_status'] = 'completed'
                        page_vehicles.append(detail_data)
                        print(f"      ✓ Parsed: {detail_data.get('make')} {detail_data.get('model')} {detail_data.get('year')}")
                    else:
                        print(f"      ⚠ Failed to parse detail page")
                else:
                    print(f"      ✗ Failed to fetch detail page")
            
            if page_vehicles:
                all_vehicles.extend(page_vehicles)
                print(f"  ✓ Page {page}: {len(page_vehicles)} vehicles collected (total: {len(all_vehicles)})")
                
                # Проверяем ограничение по количеству автомобилей
                if max_vehicles and len(all_vehicles) >= max_vehicles:
                    all_vehicles = all_vehicles[:max_vehicles]
                    print(f"  ✓ Reached max vehicles limit ({max_vehicles})")
                    # Отправляем финальный батч если есть
                    if producer and all_vehicles:
                        self._send_batch_to_kafka(producer, all_vehicles)
                        print(f"  ✓ Sent final batch of {len(all_vehicles)} vehicles to Kafka")
                    if producer:
                        producer.close()
                    print(f"\n✓ Scraping completed: {len(all_vehicles)} total vehicles (limited to {max_vehicles})")
                    return all_vehicles
                
                # Отправляем батч в Kafka
                if producer and len(all_vehicles) >= batch_size:
                    self._send_batch_to_kafka(producer, all_vehicles[:batch_size])
                    all_vehicles = all_vehicles[batch_size:]
                    print(f"  ✓ Sent batch of {batch_size} vehicles to Kafka")
            
            # Проверяем пагинацию
            pagination_info = self.parser.find_pagination(BeautifulSoup(html, 'html.parser'))
            
            # Обновляем total_pages если найдено
            if pagination_info.get('total_pages') and not total_pages:
                total_pages = pagination_info['total_pages']
                print(f"  Total pages detected: {total_pages}")
            
            if pagination_info.get('has_next'):
                page += 1
                self._polite_delay(3.0, 6.0)  # Задержка между страницами
            else:
                print(f"  No more pages available")
                break
            
            if total_pages and page > total_pages:
                print(f"  Reached total pages limit ({total_pages})")
                break
        
        # Отправляем оставшиеся данные
        if producer and all_vehicles:
            self._send_batch_to_kafka(producer, all_vehicles)
            print(f"  ✓ Sent final batch of {len(all_vehicles)} vehicles to Kafka")
        
        if producer:
            producer.close()
        
        print(f"\n✓ Scraping completed: {len(all_vehicles)} total vehicles")
        return all_vehicles
    
    def _send_batch_to_kafka(self, producer, vehicles: List[Dict]):
        """Отправляет батч автомобилей в Kafka"""
        try:
            message = {
                'vehicles': vehicles
            }
            future = producer.send('iaai-vehicle-data', value=message)
            future.get(timeout=10)
        except Exception as e:
            print(f"  ⚠ Error sending batch to Kafka: {e}")
    
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
        print(f"Scraping IAAI: {search_url}")
        print(f"Being polite: using delays between requests to mimic human behavior")
        
        if self.rate_limiter:
            key = 'rate_limit:scraper:iaai'
            if self.rate_limiter.wait_if_needed(key):
                print("  ⚠ Rate limit reached, waiting...")
                return []
            self.rate_limiter.record_request(key)
        
        # Для IAAI лучше использовать Selenium, так как результаты могут загружаться через JavaScript
        if self.driver:
            print("  Using Selenium for IAAI (JavaScript rendering required)...")
            html = self._fetch_with_selenium(search_url)
            if not html:
                print("  Selenium failed, trying cloudscraper...")
                html = self._fetch_with_cloudscraper(search_url)
        else:
            html = self._fetch_with_cloudscraper(search_url)
            if not html:
                print("  ✗ Cloudscraper failed and Selenium not available")
        
        if not html:
            print("✗ Failed to fetch search page")
            return []
        
        listings = self.parser.parse_listing_page(html)
        print(f"  Found {len(listings)} listings on search page")
        
        if not listings:
            print("  ⚠ No listings found")
            return []
        
        all_vehicles = []
        for i, listing in enumerate(listings[:limit], 1):
            detail_url = listing.get('detail_url')
            if detail_url:
                print(f"\n  [{i}/{min(len(listings), limit)}] Fetching detail page...")
                
                if i > 1:
                    self._polite_delay(3.0, 7.0)
                
                detail_html = self._fetch_with_cloudscraper(detail_url)
                
                if not detail_html and self.driver:
                    detail_html = self._fetch_with_selenium(detail_url)
                
                if detail_html:
                    detail_data = self.parser.parse_detail_page(detail_html, detail_url)
                    if detail_data:
                        detail_data['auction_status'] = 'active'
                        all_vehicles.append(detail_data)
                        print(f"    ✓ Parsed: {detail_data.get('make')} {detail_data.get('model')} {detail_data.get('year')}")
                        if detail_data.get('vin'):
                            print(f"    VIN: {detail_data.get('vin')}")
                    else:
                        print(f"    ⚠ Failed to parse detail page")
                else:
                    print(f"    ✗ Failed to fetch detail page")
        
        if all_vehicles:
            self._polite_delay(2.0, 4.0)
        
        print(f"\n✓ Scraped {len(all_vehicles)} vehicles (politely)")
        return all_vehicles


