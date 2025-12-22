class AddVinToVehicles < ActiveRecord::Migration[7.1]
  def change
    add_column :vehicles, :vin, :string
    add_index :vehicles, :vin
  end
end






