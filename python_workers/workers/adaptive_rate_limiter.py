"""
Adaptive Rate Limiter with Cloudflare-aware backoff strategy
"""
import time
import random
import redis
from typing import Optional
from datetime import datetime, timedelta


class AdaptiveRateLimiter:
    """
    Адаптивный rate limiter с динамической задержкой и обходом Cloudflare
    
    Особенности:
    - Динамическая адаптация к ответам сервера
    - Экспоненциальный backoff при ошибках
    - Распределённый rate limiting через Redis
    - Учёт успешных запросов для оптимизации задержек
    """
    
    def __init__(
        self, 
        redis_client: redis.Redis,
        base_delay: float = 2.0,
        max_delay: float = 300.0,
        min_delay: float = 1.0,
        backoff_multiplier: float = 2.0,
        max_requests_per_window: int = 10,
        window_seconds: int = 60,
        success_threshold: int = 10
    ):
        """
        Args:
            redis_client: Redis клиент для распределённого rate limiting
            base_delay: Базовая задержка между запросами (секунды)
            max_delay: Максимальная задержка при ошибках (секунды)
            min_delay: Минимальная задержка (секунды)
            backoff_multiplier: Множитель для экспоненциального backoff
            max_requests_per_window: Максимальное количество запросов в окне
            window_seconds: Размер окна для rate limiting (секунды)
            success_threshold: Количество успешных запросов для уменьшения задержки
        """
        self.redis = redis_client
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.min_delay = min_delay
        self.backoff_multiplier = backoff_multiplier
        self.max_requests_per_window = max_requests_per_window
        self.window_seconds = window_seconds
        self.success_threshold = success_threshold
        
        # Локальные счётчики (для оптимизации)
        self.local_success_count = 0
        self.local_error_count = 0
        self.last_error_type = None
        self.last_request_time = None
        
    def can_make_request(self, key: str) -> bool:
        """
        Проверяет, можно ли сделать запрос (распределённый rate limiting)
        
        Args:
            key: Ключ для rate limiting (например, 'rate_limit:scraper:iaai')
            
        Returns:
            True если можно сделать запрос, False если достигнут лимит
        """
        try:
            current = self.redis.get(key)
            if current is None or int(current) < self.max_requests_per_window:
                return True
            return False
        except Exception as e:
            print(f"Warning: Redis error in can_make_request: {e}")
            # В случае ошибки Redis разрешаем запрос (fail-open)
            return True
    
    def record_request(self, key: str):
        """
        Записывает выполненный запрос
        
        Args:
            key: Ключ для rate limiting
        """
        try:
            pipe = self.redis.pipeline()
            pipe.incr(key)
            pipe.expire(key, self.window_seconds)
            pipe.execute()
        except Exception as e:
            print(f"Warning: Redis error in record_request: {e}")
    
    def record_success(self, key: str):
        """
        Записывает успешный запрос (для оптимизации задержек)
        
        Args:
            key: Ключ для rate limiting
        """
        self.local_success_count += 1
        self.local_error_count = 0
        self.last_error_type = None
        self.record_request(key)
        
        # Сохраняем счётчик успешных запросов в Redis
        success_key = f"{key}:success_count"
        try:
            self.redis.incr(success_key)
            self.redis.expire(success_key, self.window_seconds * 2)
        except:
            pass
    
    def record_error(self, key: str, error_type: str = '429'):
        """
        Записывает ошибку (для увеличения задержек)
        
        Args:
            key: Ключ для rate limiting
            error_type: Тип ошибки ('429', '403', 'timeout', etc.)
        """
        self.local_error_count += 1
        self.local_success_count = 0
        self.last_error_type = error_type
        self.record_request(key)
        
        # Сохраняем счётчик ошибок в Redis
        error_key = f"{key}:error_count"
        try:
            self.redis.incr(error_key)
            self.redis.expire(error_key, self.window_seconds * 2)
        except:
            pass
    
    def get_delay(self, key: str = None) -> float:
        """
        Вычисляет задержку перед следующим запросом
        
        Args:
            key: Опциональный ключ для получения статистики из Redis
            
        Returns:
            Задержка в секундах
        """
        # Проверяем глобальную статистику ошибок из Redis
        if key:
            try:
                error_key = f"{key}:error_count"
                global_error_count = int(self.redis.get(error_key) or 0)
                
                if global_error_count > 5:
                    # Много ошибок - увеличиваем задержку
                    delay = min(
                        self.base_delay * (self.backoff_multiplier ** min(global_error_count // 2, 5)),
                        self.max_delay
                    )
                    return random.uniform(delay * 0.9, delay * 1.1)
            except:
                pass
        
        # Определяем задержку на основе последней ошибки
        if self.last_error_type == '403':
            # Cloudflare блокировка - большая задержка
            delay = min(
                self.base_delay * (self.backoff_multiplier ** 4),
                self.max_delay
            )
            return random.uniform(delay * 0.8, delay * 1.2)
        
        elif self.last_error_type == '429':
            # Rate limit - увеличиваем задержку
            delay = min(
                self.base_delay * (self.backoff_multiplier ** 3),
                self.max_delay
            )
            return random.uniform(delay * 0.9, delay * 1.1)
        
        elif self.last_error_type == 'timeout':
            # Timeout - умеренная задержка
            delay = min(
                self.base_delay * (self.backoff_multiplier ** 2),
                self.max_delay * 0.5
            )
            return random.uniform(delay * 0.9, delay * 1.1)
        
        elif self.local_success_count > self.success_threshold:
            # После серии успешных запросов - уменьшаем задержку
            delay = max(self.base_delay * 0.8, self.min_delay)
            return random.uniform(delay, delay * 1.5)
        
        else:
            # Нормальная задержка с рандомизацией
            return random.uniform(self.base_delay, self.base_delay * 2)
    
    def wait_if_needed(self, key: str, base_delay: Optional[float] = None) -> bool:
        """
        Ждёт если достигнут rate limit
        
        Args:
            key: Ключ для rate limiting
            base_delay: Опциональная базовая задержка (переопределяет self.base_delay)
            
        Returns:
            True если была задержка, False если запрос можно делать сразу
        """
        if not self.can_make_request(key):
            delay = base_delay or self.base_delay * 2
            print(f"  ⚠ Rate limit reached, waiting {delay:.1f} seconds...")
            time.sleep(delay)
            return True
        return False
    
    def wait(self, key: str = None):
        """
        Ждёт вычисленную задержку перед следующим запросом
        
        Args:
            key: Опциональный ключ для получения статистики
        """
        delay = self.get_delay(key)
        if delay > 0:
            time.sleep(delay)
    
    def reset_counters(self):
        """Сбрасывает локальные счётчики"""
        self.local_success_count = 0
        self.local_error_count = 0
        self.last_error_type = None
    
    def get_stats(self, key: str) -> dict:
        """
        Получает статистику rate limiting
        
        Args:
            key: Ключ для rate limiting
            
        Returns:
            Словарь со статистикой
        """
        try:
            current = int(self.redis.get(key) or 0)
            success_count = int(self.redis.get(f"{key}:success_count") or 0)
            error_count = int(self.redis.get(f"{key}:error_count") or 0)
            
            return {
                'current_requests': current,
                'max_requests': self.max_requests_per_window,
                'success_count': success_count,
                'error_count': error_count,
                'local_success_count': self.local_success_count,
                'local_error_count': self.local_error_count,
                'last_error_type': self.last_error_type
            }
        except Exception as e:
            print(f"Warning: Error getting stats: {e}")
            return {
                'current_requests': 0,
                'max_requests': self.max_requests_per_window,
                'success_count': 0,
                'error_count': 0,
                'local_success_count': self.local_success_count,
                'local_error_count': self.local_error_count,
                'last_error_type': self.last_error_type
            }



