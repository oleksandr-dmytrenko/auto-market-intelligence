class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.bigint :telegram_id, null: false
      t.string :username
      t.timestamps
    end

    add_index :users, :telegram_id, unique: true
  end
end



