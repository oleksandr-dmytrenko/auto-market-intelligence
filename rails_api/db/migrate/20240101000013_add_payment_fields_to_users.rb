class AddPaymentFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :premium_active, :boolean, default: false, null: false
    add_column :users, :premium_expires_at, :datetime
    add_column :users, :search_credits, :integer, default: 0, null: false
    
    add_index :users, :premium_active
    add_index :users, :premium_expires_at
  end
end

