class User < ApplicationRecord
  has_many :search_queries, dependent: :destroy

  validates :telegram_user_id, presence: true, uniqueness: true
end
