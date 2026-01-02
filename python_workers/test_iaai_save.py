#!/usr/bin/env python3
"""
Тестовый скрипт для проверки сохранения данных IAAI в БД
Отправляет тестовые данные в Kafka и проверяет сохранение
"""
import os
import sys
import json
import time
from kafka import KafkaProducer

def main():
    print("=" * 60)
    print("Тест сохранения данных IAAI в БД")
    print("=" * 60)
    
    kafka_brokers = os.getenv('KAFKA_BROKERS', 'kafka:29092').split(',')
    
    # Создаем тестовые данные
    test_vehicle = {
        'source': 'iaai',
        'source_id': 'TEST123456',
        'make': 'Toyota',
        'model': 'Camry',
        'year': 2020,
        'mileage': 50000,
        'color': 'White',
        'damage_type': 'Minor',
        'price': 15000.0,
        'location': 'Test Location',
        'auction_url': 'https://www.iaai.com/Vehicle/TEST123456',
        'auction_status': 'completed',
        'vin': 'TESTVIN12345678901',
        'raw_data': {
            'test': True,
            'created_at': time.time()
        }
    }
    
    print(f"\nТестовые данные:")
    print(f"  Source ID: {test_vehicle['source_id']}")
    print(f"  Make: {test_vehicle['make']}")
    print(f"  Model: {test_vehicle['model']}")
    print(f"  Year: {test_vehicle['year']}")
    print(f"  VIN: {test_vehicle['vin']}")
    
    # Отправляем в Kafka
    print(f"\nОтправка в Kafka топик 'iaai-vehicle-data'...")
    try:
        producer = KafkaProducer(
            bootstrap_servers=kafka_brokers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None
        )
        
        message = {
            'vehicles': [test_vehicle]
        }
        
        future = producer.send('iaai-vehicle-data', value=message)
        future.get(timeout=10)
        print("✓ Данные отправлены в Kafka")
        
        producer.close()
        
        # Ждем обработки
        print("\nОжидание обработки Kafka consumer (10 секунд)...")
        time.sleep(10)
        
        print("\n" + "=" * 60)
        print("Проверка сохранения в БД")
        print("=" * 60)
        print("\nВыполните в Rails console:")
        print("  docker compose exec rails_api bundle exec rails console")
        print("\nЗатем:")
        print(f"  Vehicle.find_by(source: 'iaai', source_id: '{test_vehicle['source_id']}')")
        print(f"  Vehicle.where(source: 'iaai').count")
        
        return 0
        
    except Exception as e:
        print(f"\n✗ Ошибка: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == '__main__':
    sys.exit(main())




