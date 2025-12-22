# Конфигурация Bidfax Scraper

## Переменные окружения

### Режим работы Chrome

- `CHROME_HEADLESS=true` (по умолчанию) - headless режим
- `CHROME_HEADLESS=false` - видимый режим (лучше для обхода Cloudflare)

### User-Agent

- `CHROME_USER_AGENT` - кастомный User-Agent (опционально)
- По умолчанию используется реалистичный User-Agent

### Прокси

Для использования прокси установите следующие переменные:

- `PROXY_HOST` - адрес прокси сервера (например: `proxy.example.com`)
- `PROXY_PORT` - порт прокси (например: `8080`)
- `PROXY_USERNAME` - имя пользователя (опционально)
- `PROXY_PASSWORD` - пароль (опционально)

## Примеры использования

### 1. Локальный запуск с видимым браузером

```bash
export CHROME_HEADLESS=false
docker compose up python_workers
```

### 2. Использование прокси

```bash
export PROXY_HOST=proxy.example.com
export PROXY_PORT=8080
export PROXY_USERNAME=user
export PROXY_PASSWORD=pass
docker compose up python_workers
```

### 3. Комбинированный запуск

```bash
export CHROME_HEADLESS=false
export PROXY_HOST=proxy.example.com
export PROXY_PORT=8080
docker compose restart python_workers
```

### 4. Через .env файл

Создайте файл `.env` в корне проекта:

```env
CHROME_HEADLESS=false
PROXY_HOST=proxy.example.com
PROXY_PORT=8080
PROXY_USERNAME=user
PROXY_PASSWORD=pass
```

Затем запустите:

```bash
docker compose up python_workers
```

## Улучшения обхода Cloudflare

Скрапер теперь включает:

1. **Улучшенное обнаружение Cloudflare challenge**
   - Проверка заголовка страницы
   - Проверка текста страницы
   - Проверка iframe элементов
   - Проверка DOM элементов

2. **Умное ожидание обхода**
   - Автоматическое ожидание до 90 секунд
   - Периодическая проверка статуса
   - Автоматическое обновление страницы при необходимости
   - Проверка загрузки реального контента

3. **Верификация контента**
   - Проверка что загружен реальный контент, а не challenge
   - Проверка размера HTML
   - Проверка наличия ссылок и элементов

4. **Retry логика**
   - Автоматические повторные попытки
   - Обновление страницы при застревании

## Рекомендации

1. **Для разработки и тестирования**: используйте `CHROME_HEADLESS=false`
2. **Для production**: используйте `CHROME_HEADLESS=true` + прокси
3. **При проблемах с Cloudflare**: попробуйте сменить прокси или увеличить время ожидания




