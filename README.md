# Auto Market Intelligence - Telegram Car Price Bot

Система для анализа цен на подержанные автомобили и поиска активных аукционов через Telegram бота.

## Архитектура

- **Telegram Bot** (Ruby) - Пользовательский интерфейс
- **Rails API** - Валидация, расчет цены из БД, Kafka producer/consumer
- **Python Workers** - Скрапинг Bidfax (фоновый) и IAAI/Copart (по запросу)
- **Kafka** - Асинхронная коммуникация между сервисами
- **PostgreSQL** - Хранение данных (только Rails API имеет доступ)
- **Redis** - Кеширование и rate limiting

## Workflow

1. Пользователь отправляет фильтры в Telegram бот
2. Rails API ищет цену в БД (Bidfax исторические данные)
3. Показываем цену пользователю
4. Если пользователь согласен → ищем активные аукционы (IAAI/Copart)
5. Python скрапит данные (с обходом Cloudflare)
6. Результаты отправляются напрямую в Telegram

## Источники данных

### Bidfax (исторические данные)
- Фоновый скрапинг для накопления данных
- Сохраняется в БД для расчета цен
- `auction_status = 'completed'`

### IAAI + Copart (активные аукционы)
- По запросу пользователя
- Результаты отправляются в Telegram
- Опционально сохраняется в БД для кеша

## Kafka Topics

- `bidfax-scraping-jobs` - Фоновые задачи для Bidfax
- `bidfax-vehicle-data` - Результаты Bidfax скрапинга
- `active-auction-jobs` - Запросы на поиск активных аукционов
- `active-auction-data` - Результаты поиска (отправляются в Telegram)

## Обход Cloudflare

Для всех источников используется:
- Selenium + Chrome headless
- undetected-chromedriver
- cloudscraper (fallback)
- Ротация User-Agents

## Установка

1. Скопируйте `.env.example` в `.env` и настройте:
   ```
   TELEGRAM_BOT_TOKEN=your_bot_token_here
   ```

2. Запустите setup:
   ```bash
   ./setup.sh
   ```

   Или вручную:
   ```bash
   docker-compose build
   docker-compose up -d postgres redis zookeeper kafka
   docker-compose exec rails_api rails db:create db:migrate
   docker-compose up
   ```

## Сервисы

- Rails API: http://localhost:3000
- PostgreSQL: localhost:5432
- Redis: localhost:6379
- Kafka: localhost:9092
- Zookeeper: localhost:2181

## Использование

Начните диалог с Telegram ботом и отправьте данные автомобиля:

```
Make: Audi
Model: Q5
Year: 2020
Mileage: 50000
Color: Black
Damage: Minimal
```

## API Endpoints

- `POST /api/queries` - Расчет цены и опциональный поиск активных аукционов

## Схема БД

- `users` - Пользователи Telegram
- `vehicles` - Все автомобили (Bidfax + активные аукционы)
