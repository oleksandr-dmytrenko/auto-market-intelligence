# Получение реальных данных с Bidfax

## Текущая ситуация

VIN `1HGBH41JXMN109186` был **тестовым mock-данными**, созданными для проверки сохранения в БД, так как Cloudflare блокировал реальный скрапинг.

## Проблема с Cloudflare

Bidfax.info защищен Cloudflare, который:
- Блокирует headless браузеры
- Требует JavaScript challenge
- Может показывать 403 Forbidden

## Варианты получения реальных данных

### Вариант 1: Использование прокси (рекомендуется)

```bash
# Установите переменные окружения
export PROXY_HOST=your-residential-proxy.com
export PROXY_PORT=8080
export PROXY_USERNAME=user  # если требуется
export PROXY_PASSWORD=pass   # если требуется

# Запустите тест
docker compose exec python_workers python /app/test_real_bidfax.py
```

**Важно**: Используйте residential прокси, а не datacenter прокси.

### Вариант 2: Локальный запуск с видимым браузером

Для локальной разработки (не в Docker):

```bash
# Установите переменные окружения
export CHROME_HEADLESS=false

# Запустите скрипт локально (не в Docker)
python python_workers/test_real_bidfax.py
```

### Вариант 3: Использование реального URL

Если у вас есть конкретный URL автомобиля с Bidfax, можно создать скрипт для парсинга конкретной страницы:

```python
# Пример: парсинг конкретного URL
from workers.bidfax_parser import BidfaxParser
from workers.auction_fetcher import AuctionFetcher

url = "https://bidfax.info/audi/q5/34001674-audi-q5-..."
# Парсим конкретную страницу
```

### Вариант 4: Ручной ввод данных

Если скрапинг не работает, можно вручную добавить реальные данные через Rails console:

```bash
docker compose exec rails_api bundle exec rails console
```

```ruby
# Пример реальной записи (замените на реальные данные с Bidfax)
vehicle = Vehicle.create!(
  source: 'bidfax',
  source_id: '34001674',  # реальный ID с Bidfax
  make: 'Audi',
  model: 'Q5',
  year: 2023,
  mileage: 50000,
  color: 'Black',
  damage_type: 'Minor',
  price: 25000.0,
  final_price: 25000.0,
  vin: 'WA1GAAF...',  # реальный VIN
  location: 'Location Name',
  auction_url: 'https://bidfax.info/audi/q5/34001674-...html',
  auction_status: 'completed',
  raw_data: {
    'title': 'Audi Q5 Premium...',
    'vin': 'WA1GAAF...',
    'images': ['https://bidfax.info/image1.jpg']
  }
)
```

## Тестирование реального скрапинга

Запустите улучшенный тест:

```bash
docker compose exec python_workers python /app/test_real_bidfax.py
```

Этот скрипт:
- ✅ Пытается получить реальные данные (не mock)
- ✅ Ждет обхода Cloudflare до 90 секунд
- ✅ Показывает детали полученной записи
- ✅ Отправляет данные в Kafka для сохранения в БД
- ✅ Предупреждает если VIN не найден

## Проверка результатов

После успешного скрапинга проверьте БД:

```bash
docker compose exec rails_api bundle exec rails console
```

```ruby
# Найти последнюю запись
v = Vehicle.last

# Проверить VIN
v.vin

# Проверить URL
v.auction_url

# Проверить что это реальные данные (не test_)
v.source_id.start_with?('test_')  # должно быть false
```

## Рекомендации

1. **Для production**: Используйте качественные residential прокси
2. **Для разработки**: Попробуйте локальный запуск с видимым браузером
3. **Для тестирования**: Используйте ручной ввод данных через Rails console
4. **Мониторинг**: Проверяйте логи Kafka consumer для отслеживания обработки

## Альтернативные подходы

Если Cloudflare продолжает блокировать:

1. **Использование API** (если доступно)
2. **Интеграция с сервисами обхода Cloudflare** (2captcha и т.д.)
3. **Парсинг через другие источники** (если доступны)
4. **Ручной сбор данных** с последующей загрузкой в БД




