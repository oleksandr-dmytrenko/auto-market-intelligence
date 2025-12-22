class CreateVehicles < ActiveRecord::Migration[7.1]
  def change
    create_table :vehicles, id: :uuid do |t|
      t.string :source, null: false
      t.string :source_id, null: false
      t.string :make, null: false
      t.string :model, null: false
      t.integer :year, null: false
      t.integer :mileage
      t.string :color
      t.string :damage_type
      t.integer :production_year
      t.decimal :price, precision: 10, scale: 2
      t.string :location
      t.string :auction_url
      t.jsonb :raw_data
      t.timestamp :normalized_at
      t.timestamps
    end

    add_index :vehicles, :source
    add_index :vehicles, :source_id
    add_index :vehicles, :make
    add_index :vehicles, :model
    add_index :vehicles, :year
    add_index :vehicles, [:source, :source_id], unique: true
  end
end


