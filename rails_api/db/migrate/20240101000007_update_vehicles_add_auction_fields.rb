class UpdateVehiclesAddAuctionFields < ActiveRecord::Migration[7.1]
  def change
    add_column :vehicles, :auction_status, :string, default: 'completed' # 'active' or 'completed'
    add_column :vehicles, :auction_end_date, :timestamp
    add_column :vehicles, :final_price, :decimal, precision: 10, scale: 2
    add_index :vehicles, :auction_status
    add_index :vehicles, :auction_end_date
  end
end




