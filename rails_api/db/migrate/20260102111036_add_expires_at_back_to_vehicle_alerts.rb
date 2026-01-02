class AddExpiresAtBackToVehicleAlerts < ActiveRecord::Migration[7.1]
  def change
    add_column :vehicle_alerts, :expires_at, :datetime, null: false
    add_index :vehicle_alerts, :expires_at
    
    # Set default for existing records
    execute "UPDATE vehicle_alerts SET expires_at = NOW() + INTERVAL '7 days' WHERE expires_at IS NULL"
  end
end
