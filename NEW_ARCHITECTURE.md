# Новая Архитектура - Auto Market Intelligence

## Обзор

Система для анализа цен на подержанные автомобили и поиска активных аукционов через Telegram бота.

**Принципы**: KISS, DRY, YAGNI

## Источники данных

### 1. Bidfax (исторические данные)
- **Назначение**: Накопление данных о завершенных аукционах для расчета цен
- **Режим**: Фоновый скрапинг (планомерный парсинг)
- **Хранение**: Все данные в БД (`vehicles` с `auction_status='completed'`)
- **Использование**: Расчет средней/медианной цены

### 2. IAAI + Copart (активные аукционы)
- **Назначение**: Поиск действующих лотов для пользователя
- **Режим**: По запросу пользователя
- **Хранение**: Опционально (можно не сохранять, только отправлять в Telegram)
- **Использование**: Показ пользователю актуальных аукционов

## Workflow

```
1. Пользователь: "Audi Q5 2020, минимальные повреждения, на ходу"
   ↓
2. Rails API: Поиск в БД (Bidfax данные) → расчет цены $12000
   ↓
3. Telegram Bot: "Ожидаемая цена: $12000. Искать действующие аукционы?"
   ↓
4. Если ДА:
   Rails → Kafka (active-auction-jobs)
   ↓
   Python → IAAI + Copart (обход Cloudflare)
   ↓
   Kafka (active-auction-data)
   ↓
   Rails Consumer → Telegram Bot API (напрямую)
```

## Компоненты системы

### 1. Telegram Bot
- Принимает запросы пользователей
- Показывает цену из БД
- Запрашивает поиск активных аукционов
- Получает результаты напрямую от Kafka consumer

### 2. Rails API
- Расчет цены из БД (Bidfax данные)
- Публикация задач в Kafka
- Kafka consumer для обработки результатов
- Прямая отправка в Telegram

### 3. Python Workers
- **Фоновый скрапер**: Постоянный парсинг Bidfax
- **On-demand скрапер**: Поиск активных аукционов (IAAI/Copart)
- Обход Cloudflare (Selenium + undetected-chromedriver)

### 4. PostgreSQL
- `users` - пользователи
- `vehicles` - все автомобили (Bidfax + активные аукционы)

### 5. Kafka Topics
- `bidfax-scraping-jobs` - фоновые задачи для Bidfax
- `bidfax-vehicle-data` - результаты Bidfax скрапинга
- `active-auction-jobs` - запросы пользователей на поиск
- `active-auction-data` - результаты поиска активных аукционов

## Схема БД

### `users`
- `id` (UUID)
- `telegram_id` (bigint, unique)
- `username` (string)

### `vehicles`
- `id` (UUID)
- `source` (string: 'bidfax', 'copart', 'iaai')
- `source_id` (string, unique per source)
- `make`, `model`, `year` (indexed)
- `mileage`, `color`, `damage_type`
- `price` (decimal) - цена
- `final_price` (decimal) - финальная цена (для завершенных)
- `auction_status` (string: 'active', 'completed')
- `auction_end_date` (timestamp)
- `location`, `auction_url`
- `raw_data` (JSONB)
- `normalized_at`, `created_at`, `updated_at`

## Обход Cloudflare

Для всех источников (Bidfax, IAAI, Copart):
- Selenium + Chrome headless
- undetected-chromedriver для обхода детекции
- cloudscraper как fallback
- Ротация User-Agents
- Задержки между запросами

## Преимущества новой архитектуры

1. **Простота**: Убрали лишние таблицы (price_queries, similarity_matches, auction_listings)
2. **Эффективность**: Цена вычисляется из БД (быстро), активные аукционы по запросу
3. **Гибкость**: Легко добавить новые источники данных
4. **Масштабируемость**: Kafka consumer groups для распределения нагрузки




