class CreateVehicleListings < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicle_listings do |t|
      t.references :provider, null: false, foreign_key: true

      t.string :provider_listing_id, null: false
      t.string :vin

      t.string :make
      t.string :model
      t.integer :model_year
      t.integer :production_year

      t.integer :mileage
      t.string :color
      t.string :damage_type
      t.string :location

      t.decimal :current_bid, precision: 10, scale: 2
      t.decimal :final_price, precision: 10, scale: 2
      t.string :currency

      t.string :sale_status
      t.string :auction_url

      t.jsonb :raw_data

      t.datetime :listed_at

      t.timestamps
    end

    add_index :vehicle_listings, [:provider_id, :provider_listing_id], unique: true, name: "index_vehicle_listings_on_provider_and_listing_id"
    add_index :vehicle_listings, [:make, :model, :model_year, :production_year], name: "index_vehicle_listings_on_make_model_years"
  end
end






