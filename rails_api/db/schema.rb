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

ActiveRecord::Schema[7.1].define(version: 2024_01_01_000008) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

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
    t.index ["auction_end_date"], name: "index_vehicles_on_auction_end_date"
    t.index ["auction_status"], name: "index_vehicles_on_auction_status"
    t.index ["make"], name: "index_vehicles_on_make"
    t.index ["model"], name: "index_vehicles_on_model"
    t.index ["source", "source_id"], name: "index_vehicles_on_source_and_source_id", unique: true
    t.index ["source"], name: "index_vehicles_on_source"
    t.index ["source_id"], name: "index_vehicles_on_source_id"
    t.index ["vin"], name: "index_vehicles_on_vin"
    t.index ["year"], name: "index_vehicles_on_year"
  end

end
