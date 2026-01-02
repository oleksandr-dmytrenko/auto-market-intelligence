class CreateVehicleAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :vehicle_alerts, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :make, null: false
      t.string :model, null: false
      t.integer :year
      t.string :damage_type
      t.integer :mileage_min
      t.integer :mileage_max
      t.datetime :expires_at, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :notified_vehicle_ids, default: [], null: false
      t.timestamps
    end

    add_index :vehicle_alerts, :active
    add_index :vehicle_alerts, :expires_at
    add_index :vehicle_alerts, [:make, :model, :year]
    add_index :vehicle_alerts, :notified_vehicle_ids, using: :gin
  end
end

