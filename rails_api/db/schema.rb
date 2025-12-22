ActiveRecord::Schema[7.1].define(version: 2024_01_01_000011) do
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "auction_status_history", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "vehicle_id", null: false
    t.string "old_status"
    t.string "new_status"
    t.decimal "price_before", precision: 10, scale: 2
    t.decimal "price_after", precision: 10, scale: 2
    t.datetime "changed_at", precision: nil, null: false
    t.index ["new_status"], name: "index_auction_status_history_on_new_status"
    t.index ["vehicle_id", "changed_at"], name: "index_auction_status_history_on_vehicle_and_changed_at"
    t.index ["vehicle_id"], name: "index_auction_status_history_on_vehicle_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "telegram_id", null: false
    t.string "username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["telegram_id"], name: "index_users_on_telegram_id", unique: true
  end

  create_table "vehicles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "source", null: false
    t.string "source_id", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.integer "year", null: false
    t.integer "mileage"
    t.string "color"
    t.string "damage_type"
    t.integer "production_year"
    t.decimal "price", precision: 10, scale: 2
    t.string "location"
    t.string "auction_url"
    t.jsonb "raw_data"
    t.datetime "normalized_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "auction_status", default: "completed"
    t.datetime "auction_end_date", precision: nil
    t.decimal "final_price", precision: 10, scale: 2
    t.string "vin"
    t.jsonb "image_urls", default: [], null: false
    t.string "lot_id"
    t.string "stock_number"
    t.string "partial_vin", limit: 13
    t.string "vehicle_fingerprint", limit: 64
    t.string "mileage_bucket", limit: 10
    t.datetime "status_changed_at", precision: nil
    t.index ["auction_end_date"], name: "index_vehicles_on_auction_end_date"
    t.index ["auction_status"], name: "index_vehicles_on_auction_status"
    t.index ["image_urls"], name: "index_vehicles_on_image_urls", using: :gin
    t.index ["make", "model", "year"], name: "index_vehicles_on_make_model_year"
    t.index ["make"], name: "index_vehicles_on_make"
    t.index ["model"], name: "index_vehicles_on_model"
    t.index ["partial_vin"], name: "index_vehicles_on_partial_vin"
    t.index ["source", "source_id"], name: "index_vehicles_on_source_and_source_id", unique: true
    t.index ["source", "stock_number"], name: "index_vehicles_on_source_and_stock_number", unique: true, where: "(stock_number IS NOT NULL)"
    t.index ["source"], name: "index_vehicles_on_source"
    t.index ["source_id"], name: "index_vehicles_on_source_id"
    t.index ["stock_number"], name: "index_vehicles_on_stock_number"
    t.index ["vehicle_fingerprint"], name: "index_vehicles_on_vehicle_fingerprint"
    t.index ["vin"], name: "index_vehicles_on_vin"
    t.index ["year"], name: "index_vehicles_on_year"
  end

  add_foreign_key "auction_status_history", "vehicles"
end
