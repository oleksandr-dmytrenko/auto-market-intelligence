class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :payment_type, null: false # 'premium' or 'single_search'
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: 'USD', null: false
      t.string :status, default: 'pending', null: false # 'pending', 'success', 'failed', 'refunded'
      t.string :liqpay_order_id
      t.string :liqpay_transaction_id
      t.jsonb :liqpay_response
      t.text :description
      t.datetime :paid_at
      t.datetime :expires_at # For premium subscriptions
      
      t.timestamps
      
      t.index :status
      t.index :liqpay_order_id, unique: true
      t.index :liqpay_transaction_id
      t.index [:user_id, :status]
    end
  end
end

