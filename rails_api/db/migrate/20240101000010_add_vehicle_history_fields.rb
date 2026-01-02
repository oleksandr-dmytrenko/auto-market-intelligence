class AddVehicleHistoryFields < ActiveRecord::Migration[7.1]
  def change
    # Добавляем поля для Vehicle History Engine
    add_column :vehicles, :lot_id, :string
    add_column :vehicles, :stock_number, :string
    add_column :vehicles, :partial_vin, :string, limit: 13
    add_column :vehicles, :vehicle_fingerprint, :string, limit: 64
    add_column :vehicles, :mileage_bucket, :string, limit: 10
    add_column :vehicles, :status_changed_at, :timestamp
    
    # Индексы для эффективного поиска
    add_index :vehicles, :stock_number, name: 'index_vehicles_on_stock_number'
    add_index :vehicles, :partial_vin, name: 'index_vehicles_on_partial_vin'
    add_index :vehicles, :vehicle_fingerprint, name: 'index_vehicles_on_vehicle_fingerprint'
    add_index :vehicles, [:make, :model, :year], name: 'index_vehicles_on_make_model_year'
    
    # Уникальный индекс для stock_number (вместе с source)
    add_index :vehicles, [:source, :stock_number], unique: true, name: 'index_vehicles_on_source_and_stock_number', where: 'stock_number IS NOT NULL'
  end
end



