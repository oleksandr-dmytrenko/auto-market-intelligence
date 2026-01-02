# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_01_02_111036) do
  # These are extensions that must be enabled in order to support this database
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

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "payment_type", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "USD", null: false
    t.string "status", default: "pending", null: false
    t.string "liqpay_order_id"
    t.string "liqpay_transaction_id"
    t.jsonb "liqpay_response"
    t.text "description"
    t.datetime "paid_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["liqpay_order_id"], name: "index_payments_on_liqpay_order_id", unique: true
    t.index ["liqpay_transaction_id"], name: "index_payments_on_liqpay_transaction_id"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "telegram_id", null: false
    t.string "username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "premium_active", default: false, null: false
    t.datetime "premium_expires_at"
    t.integer "search_credits", default: 0, null: false
    t.index ["premium_active"], name: "index_users_on_premium_active"
    t.index ["premium_expires_at"], name: "index_users_on_premium_expires_at"
    t.index ["telegram_id"], name: "index_users_on_telegram_id", unique: true
  end

  create_table "vehicle_alerts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.string "damage_type"
    t.integer "mileage_min"
    t.integer "mileage_max"
    t.boolean "active", default: true, null: false
    t.jsonb "notified_vehicle_ids", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "year_from"
    t.integer "year_to"
    t.datetime "expires_at", default: -> { "(now() + 'P7D'::interval)" }, null: false
    t.index ["active"], name: "index_vehicle_alerts_on_active"
    t.index ["expires_at"], name: "index_vehicle_alerts_on_expires_at"
    t.index ["make", "model", "year_from", "year_to"], name: "idx_on_make_model_year_from_year_to_aff6dae3f0"
    t.index ["notified_vehicle_ids"], name: "index_vehicle_alerts_on_notified_vehicle_ids", using: :gin
    t.index ["user_id"], name: "index_vehicle_alerts_on_user_id"
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
  add_foreign_key "payments", "users"
  add_foreign_key "vehicle_alerts", "users"
end
