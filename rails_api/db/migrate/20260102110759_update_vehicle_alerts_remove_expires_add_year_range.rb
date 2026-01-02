class UpdateVehicleAlertsRemoveExpiresAddYearRange < ActiveRecord::Migration[7.1]
  def change
    # Remove expires_at column
    remove_column :vehicle_alerts, :expires_at, :datetime
    
    # Remove year column and add year_from and year_to
    remove_column :vehicle_alerts, :year, :integer
    add_column :vehicle_alerts, :year_from, :integer
    add_column :vehicle_alerts, :year_to, :integer
    
    # Remove index on expires_at
    remove_index :vehicle_alerts, :expires_at if index_exists?(:vehicle_alerts, :expires_at)
    
    # Update index to use year_from and year_to
    remove_index :vehicle_alerts, [:make, :model, :year] if index_exists?(:vehicle_alerts, [:make, :model, :year])
    add_index :vehicle_alerts, [:make, :model, :year_from, :year_to]
  end
end
