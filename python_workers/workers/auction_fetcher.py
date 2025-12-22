import time
import os
from typing import List, Dict, Optional
from .rate_limiter import RateLimiter
import random

try:
    import undetected_chromedriver as uc
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    UNDETECTED_CHROME_AVAILABLE = True
except ImportError:
    UNDETECTED_CHROME_AVAILABLE = False
    print("Warning: undetected-chromedriver not available. Install with: pip install undetected-chromedriver")

try:
    from selenium_stealth import stealth
    SELENIUM_STEALTH_AVAILABLE = True
except ImportError:
    SELENIUM_STEALTH_AVAILABLE = False
    print("Warning: selenium-stealth not available. Install with: pip install selenium-stealth")

try:
    from fake_useragent import UserAgent
    FAKE_USERAGENT_AVAILABLE = True
except ImportError:
    FAKE_USERAGENT_AVAILABLE = False
    print("Warning: fake-useragent not available. Install with: pip install fake-useragent")

class AuctionFetcher:
    """Fetches auction listings with Cloudflare bypass"""
    
    def __init__(self, rate_limiter: RateLimiter):
        self.rate_limiter = rate_limiter
        self.driver = None
        self._init_driver()
    
    def _init_driver(self):
        """Initialize undetected Chrome driver with Cloudflare bypass"""
        if not UNDETECTED_CHROME_AVAILABLE:
            print("Warning: undetected-chromedriver not available, using mock data")
            return
        
        try:
            # Use undetected-chromedriver for Cloudflare bypass
            options = uc.ChromeOptions()
            
            # Настройка headless режима (по умолчанию headless, можно отключить через переменную окружения)
            headless_mode = os.getenv('CHROME_HEADLESS', 'true').lower() == 'true'
            if headless_mode:
                options.add_argument('--headless=new')
                print("Chrome running in headless mode")
            else:
                print("Chrome running in visible mode (better for Cloudflare bypass)")
            
            # Базовые опции для стабильности
            options.add_argument('--no-sandbox')
            options.add_argument('--disable-dev-shm-usage')
            options.add_argument('--disable-blink-features=AutomationControlled')
            
            # Дополнительные опции для обхода Cloudflare
            options.add_argument('--disable-web-security')
            options.add_argument('--disable-features=IsolateOrigins,site-per-process')
            options.add_argument('--window-size=1920,1080')
            options.add_argument('--start-maximized')
            
            # User-Agent для более реалистичного браузера (с ротацией)
            if FAKE_USERAGENT_AVAILABLE:
                try:
                    ua = UserAgent()
                    user_agent = ua.random
                    print(f"Using random User-Agent: {user_agent[:50]}...")
                except:
                    user_agents = [
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
                        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    ]
                    user_agent = os.getenv('CHROME_USER_AGENT', random.choice(user_agents))
            else:
                user_agents = [
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
                    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                ]
                user_agent = os.getenv('CHROME_USER_AGENT', random.choice(user_agents))
            options.add_argument(f'--user-agent={user_agent}')
            
            # Дополнительные опции для лучшего обхода
            options.add_argument('--disable-blink-features=AutomationControlled')
            options.add_argument('--disable-infobars')
            options.add_argument('--disable-extensions')
            options.add_argument('--disable-plugins-discovery')
            options.add_argument('--disable-default-apps')
            options.add_argument('--disable-sync')
            options.add_argument('--metrics-recording-only')
            options.add_argument('--mute-audio')
            options.add_argument('--no-first-run')
            options.add_argument('--safebrowsing-disable-auto-update')
            options.add_argument('--disable-background-networking')
            options.add_argument('--disable-background-timer-throttling')
            options.add_argument('--disable-renderer-backgrounding')
            options.add_argument('--disable-backgrounding-occluded-windows')
            
            # Настройка прокси (если указан)
            proxy = self._get_proxy_config()
            if proxy:
                print(f"Using proxy: {proxy['host']}:{proxy['port']}")
                options.add_argument(f'--proxy-server={proxy["host"]}:{proxy["port"]}')
                
                # Если есть авторизация прокси
                if proxy.get('username') and proxy.get('password'):
                    # Для undetected-chromedriver авторизация прокси может потребовать расширения
                    # Пока используем базовую настройку
                    pass
            
            # Инициализация драйвера
            # undetected-chromedriver автоматически обходит детекцию, поэтому не нужно добавлять excludeSwitches
            self.driver = uc.Chrome(options=options, version_main=None)
            
            # Применяем selenium-stealth для дополнительного обхода Incapsula
            if SELENIUM_STEALTH_AVAILABLE:
                try:
                    stealth(
                        self.driver,
                        languages=["en-US", "en"],
                        vendor="Google Inc.",
                        platform="Win32",
                        webgl_vendor="Intel Inc.",
                        renderer="Intel Iris OpenGL Engine",
                        fix_hairline=True,
                    )
                    print("Applied selenium-stealth for Incapsula bypass")
                except Exception as e:
                    print(f"Warning: Could not apply selenium-stealth: {e}")
            
            # Выполняем расширенные скрипты для обхода детекции Incapsula
            advanced_stealth_script = '''
                // Скрываем webdriver (критично для Incapsula)
                Object.defineProperty(navigator, 'webdriver', {
                    get: () => undefined
                });
                
                // Эмулируем плагины (Incapsula проверяет)
                Object.defineProperty(navigator, 'plugins', {
                    get: () => {
                        const plugins = [];
                        for (let i = 0; i < 5; i++) {
                            plugins.push({
                                0: { type: 'application/x-google-chrome-pdf', suffixes: 'pdf', description: 'Portable Document Format' },
                                description: 'Portable Document Format',
                                filename: 'internal-pdf-viewer',
                                length: 1,
                                name: 'Chrome PDF Plugin'
                            });
                        }
                        return plugins;
                    }
                });
                
                // Эмулируем языки
                Object.defineProperty(navigator, 'languages', {
                    get: () => ['en-US', 'en']
                });
                
                // Эмулируем chrome объект (Incapsula проверяет)
                window.chrome = {
                    runtime: {},
                    loadTimes: function() {},
                    csi: function() {},
                    app: {
                        isInstalled: false,
                        InstallState: {
                            DISABLED: "disabled",
                            INSTALLED: "installed",
                            NOT_INSTALLED: "not_installed"
                        },
                        RunningState: {
                            CANNOT_RUN: "cannot_run",
                            READY_TO_RUN: "ready_to_run",
                            RUNNING: "running"
                        }
                    }
                };
                
                // Эмулируем permissions
                const originalQuery = window.navigator.permissions.query;
                window.navigator.permissions.query = (parameters) => (
                    parameters.name === 'notifications' ?
                        Promise.resolve({ state: Notification.permission }) :
                        originalQuery(parameters)
                );
                
                // Эмулируем платформу
                Object.defineProperty(navigator, 'platform', {
                    get: () => 'Win32'
                });
                
                // Эмулируем hardwareConcurrency
                Object.defineProperty(navigator, 'hardwareConcurrency', {
                    get: () => 8
                });
                
                // Эмулируем deviceMemory
                Object.defineProperty(navigator, 'deviceMemory', {
                    get: () => 8
                });
                
                // Эмулируем connection (Incapsula может проверять)
                Object.defineProperty(navigator, 'connection', {
                    get: () => ({
                        effectiveType: '4g',
                        rtt: 50,
                        downlink: 10,
                        saveData: false
                    })
                });
                
                // Скрываем автоматизацию в window
                Object.defineProperty(window, 'navigator', {
                    value: new Proxy(navigator, {
                        has: (target, key) => (key === 'webdriver' ? false : key in target),
                        get: (target, key) => (key === 'webdriver' ? undefined : target[key])
                    })
                });
                
                // Эмулируем WebGL (Incapsula проверяет)
                const getParameter = WebGLRenderingContext.prototype.getParameter;
                WebGLRenderingContext.prototype.getParameter = function(parameter) {
                    if (parameter === 37445) {
                        return 'Intel Inc.';
                    }
                    if (parameter === 37446) {
                        return 'Intel Iris OpenGL Engine';
                    }
                    return getParameter.call(this, parameter);
                };
            '''
            self.driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
                'source': advanced_stealth_script
            })
            
            # Дополнительные CDP команды для обхода Incapsula
            try:
                # Эмулируем реальный браузер
                self.driver.execute_cdp_cmd('Network.setUserAgentOverride', {
                    "userAgent": user_agent,
                    "acceptLanguage": "en-US,en;q=0.9",
                    "platform": "Win32"
                })
                
                # Отключаем автоматизацию флаги
                self.driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {
                    'source': '''
                        Object.defineProperty(navigator, 'webdriver', {get: () => false});
                    '''
                })
            except Exception as e:
                print(f"Warning: Could not apply CDP commands: {e}")
            
            print("Chrome driver initialized successfully")
        except Exception as e:
            print(f"Warning: Could not initialize Chrome driver: {e}")
            print("Falling back to mock data")
            self.driver = None
    
    def _get_proxy_config(self) -> Optional[Dict]:
        """Получает конфигурацию прокси из переменных окружения"""
        proxy_host = os.getenv('PROXY_HOST')
        proxy_port = os.getenv('PROXY_PORT')
        
        if not proxy_host or not proxy_port:
            return None
        
        return {
            'host': proxy_host,
            'port': proxy_port,
            'username': os.getenv('PROXY_USERNAME'),
            'password': os.getenv('PROXY_PASSWORD')
        }
    
    
    def fetch_copart_listings(self, filters: Dict, limit: int = 30) -> List[Dict]:
        """
        Fetch active listings from Copart
        Note: Requires Cloudflare bypass
        """
        key = 'rate_limit:scraper:copart'
        
        if self.rate_limiter.wait_if_needed(key):
            return []
        
        self.rate_limiter.record_request(key)
        
        # TODO: Implement actual Copart scraping with Cloudflare bypass
        # For now, return mock data
        time.sleep(random.uniform(1, 2))
        return self._mock_listings('copart', filters, limit, active=True)
    
    def fetch_iaai_listings(self, filters: Dict, limit: int = 30) -> List[Dict]:
        """
        Fetch active listings from IAAI
        Uses cloudscraper (primary) and Selenium (fallback) with polite delays
        """
        from .iaai_scraper import IAAIScraper
        
        key = 'rate_limit:scraper:iaai'
        
        if self.rate_limiter.wait_if_needed(key):
            return []
        
        self.rate_limiter.record_request(key)
        
        make = filters.get('make', '')
        model = filters.get('model', '')
        year = filters.get('year')
        
        from_year = year - 2 if year else None
        to_year = year + 2 if year else None
        
        scraper = IAAIScraper(self.driver, self.rate_limiter)
        
        return scraper.scrape_listings(make, model, from_year, to_year, limit)
    
    def scan_all_iaai_listings(self, months_back: int = 12, max_pages: int = None, max_vehicles: int = None) -> List[Dict]:
        """
        Сканирует все записи IAAI за последний год с пагинацией
        Сохраняет данные в базу через Kafka
        
        Args:
            months_back: Количество месяцев назад (по умолчанию 12 - год)
            max_pages: Максимальное количество страниц (None = без ограничений)
            max_vehicles: Максимальное количество автомобилей (None = без ограничений)
            
        Returns:
            Список всех найденных автомобилей
        """
        from .iaai_scraper import IAAIScraper
        
        key = 'rate_limit:scraper:iaai'
        
        if self.rate_limiter.wait_if_needed(key):
            return []
        
        scraper = IAAIScraper(self.driver, self.rate_limiter)
        
        return scraper.scrape_all_listings(months_back=months_back, max_pages=max_pages, max_vehicles=max_vehicles)
    
    
    def _mock_listings(self, platform: str, filters: Dict, limit: int, active: bool = False) -> List[Dict]:
        """Generate mock active auction listings"""
        listings = []
        base_year = filters.get('year', 2020)
        base_mileage = filters.get('mileage', 50000)
        
        for i in range(limit):
            listings.append({
                'source': platform,
                'source_id': f'{platform}_{i}_{int(time.time())}',
                'make': filters.get('make', 'Toyota'),
                'model': filters.get('model', 'Camry'),
                'year': base_year + random.randint(-2, 2),
                'mileage': str(base_mileage + random.randint(-10000, 10000)),
                'color': filters.get('color', 'black'),
                'damage_type': filters.get('damage_type', 'none'),
                'price': random.randint(10000, 30000),  # Current bid/estimate
                'location': f'Location {i+1}',
                'auction_url': f'https://{platform}.com/listing/{i}',
                'auction_end_date': time.time() + random.randint(1, 30) * 86400 if active else None  # Future date for active
            })
        
        return listings
    
    def __del__(self):
        """Cleanup driver"""
        if self.driver:
            try:
                self.driver.quit()
            except:
                pass
