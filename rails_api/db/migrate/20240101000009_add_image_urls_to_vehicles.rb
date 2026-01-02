class AddImageUrlsToVehicles < ActiveRecord::Migration[7.1]
  def change
    add_column :vehicles, :image_urls, :jsonb, default: [], null: false
    add_index :vehicles, :image_urls, using: :gin
  end
end




