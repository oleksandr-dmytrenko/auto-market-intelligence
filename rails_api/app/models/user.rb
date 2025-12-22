class User < ApplicationRecord
  validates :telegram_id, presence: true, uniqueness: true
end


