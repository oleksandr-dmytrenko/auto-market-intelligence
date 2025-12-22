class CreateAuctionStatusHistory < ActiveRecord::Migration[7.1]
  def change
    create_table :auction_status_history, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :vehicle, null: false, foreign_key: true, type: :uuid
      t.string :old_status
      t.string :new_status
      t.decimal :price_before, precision: 10, scale: 2
      t.decimal :price_after, precision: 10, scale: 2
      t.timestamp :changed_at, null: false
      
      t.index [:vehicle_id, :changed_at], name: 'index_auction_status_history_on_vehicle_and_changed_at'
      t.index :new_status, name: 'index_auction_status_history_on_new_status'
    end
  end
end


