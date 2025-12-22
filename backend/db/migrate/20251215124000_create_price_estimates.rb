class CreatePriceEstimates < ActiveRecord::Migration[8.1]
  def change
    create_table :price_estimates do |t|
      t.references :search_query, null: false, foreign_key: true

      t.decimal :avg_price, precision: 10, scale: 2
      t.decimal :median_price, precision: 10, scale: 2
      t.decimal :min_price, precision: 10, scale: 2
      t.decimal :max_price, precision: 10, scale: 2

      t.string :currency, null: false, default: "USD"
      t.integer :sample_size
      t.float :confidence_score
      t.datetime :computed_at

      t.timestamps
    end
  end
end






