#!/usr/bin/env python3
"""
Скрипт для ручного импорта данных с Bidfax
Используйте когда Cloudflare блокирует автоматический скрапинг
"""
import os
import sys
import json
from kafka import KafkaProducer

def main():
    print("=" * 60)
    print("Ручной импорт данных с Bidfax")
    print("=" * 60)
    print("\nЭтот скрипт позволяет импортировать данные, собранные вручную")
    print("с Bidfax.info, когда автоматический скрапинг заблокирован.\n")
    
    # Пример данных (замените на реальные данные с Bidfax)
    print("Введите данные автомобиля с Bidfax:\n")
    
    # Можно изменить эти значения на реальные данные
    vehicles = [
        {
            'source': 'bidfax',
            'source_id': input('Source ID (например, 34001674): ').strip() or '34001674',
            'make': input('Марка (например, Audi): ').strip() or 'Audi',
            'model': input('Модель (например, Q5): ').strip() or 'Q5',
            'year': int(input('Год (например, 2023): ').strip() or '2023'),
            'mileage': int(input('Пробег (например, 50000): ').strip() or '50000'),
            'color': input('Цвет (например, Black): ').strip() or 'Black',
            'damage_type': input('Тип повреждения (например, Minor): ').strip() or 'Minor',
            'price': float(input('Цена (например, 25000): ').strip() or '25000'),
            'final_price': float(input('Финальная цена (например, 25000): ').strip() or '25000'),
            'location': input('Локация (например, Location Name): ').strip() or 'Location Name',
            'auction_url': input('URL аукциона: ').strip() or 'https://bidfax.info/audi/q5/34001674-...html',
            'auction_status': 'completed',
            'vin': input('VIN (17 символов): ').strip() or 'WA1GAAF...',
            'images': [input('URL фото (через запятую): ').strip() or 'https://bidfax.info/image1.jpg'],
            'raw_data': {
                'title': input('Заголовок: ').strip() or 'Audi Q5 Premium...',
                'vin': input('VIN в raw_data: ').strip() or 'WA1GAAF...',
                'images': [input('URL фото в raw_data: ').strip() or 'https://bidfax.info/image1.jpg']
            }
        }
    ]
    
    # Очищаем пустые значения
    for vehicle in vehicles:
        vehicle['images'] = [img for img in vehicle['images'] if img]
        if not vehicle['images']:
            vehicle['images'] = []
    
    print(f"\n✓ Данные подготовлены:")
    print(f"   Марка: {vehicles[0]['make']}")
    print(f"   Модель: {vehicles[0]['model']}")
    print(f"   Год: {vehicles[0]['year']}")
    print(f"   VIN: {vehicles[0]['vin']}")
    print(f"   Source ID: {vehicles[0]['source_id']}")
    
    # Отправляем в Kafka
    print("\nОтправка данных в Kafka...")
    try:
        kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
        producer = KafkaProducer(
            bootstrap_servers=kafka_brokers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None
        )
        
        message = {
            'vehicles': vehicles
        }
        
        future = producer.send('bidfax-vehicle-data', value=message)
        future.get(timeout=10)
        print("✓ Данные отправлены в Kafka топик 'bidfax-vehicle-data'")
        
        producer.close()
        
        print("\n" + "=" * 60)
        print("Импорт завершен успешно!")
        print("=" * 60)
        print(f"\nПроверьте БД через Rails console:")
        print(f"  docker compose exec rails_api bundle exec rails console")
        print(f"\n  Vehicle.find_by(source: 'bidfax', source_id: '{vehicles[0]['source_id']}')")
        
        return 0
        
    except Exception as e:
        print(f"\n✗ Ошибка отправки в Kafka: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == '__main__':
    # Если запущено без интерактивного ввода, используем пример данных
    if not sys.stdin.isatty():
        print("Запущено в неинтерактивном режиме, используем пример данных")
        vehicles = [{
            'source': 'bidfax',
            'source_id': '34001674',
            'make': 'Audi',
            'model': 'Q5',
            'year': 2023,
            'mileage': 50000,
            'color': 'Black',
            'damage_type': 'Minor',
            'price': 25000.0,
            'final_price': 25000.0,
            'location': 'Location Name',
            'auction_url': 'https://bidfax.info/audi/q5/34001674-...html',
            'auction_status': 'completed',
            'vin': 'WA1GAAF1234567890',
            'images': ['https://bidfax.info/image1.jpg'],
            'raw_data': {
                'title': 'Audi Q5 Premium 45 TFSI',
                'vin': 'WA1GAAF1234567890',
                'images': ['https://bidfax.info/image1.jpg']
            }
        }]
        
        kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
        producer = KafkaProducer(
            bootstrap_servers=kafka_brokers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8')
        )
        producer.send('bidfax-vehicle-data', {'vehicles': vehicles})
        producer.close()
        print("✓ Пример данных отправлен в Kafka")
        sys.exit(0)
    
    sys.exit(main())




