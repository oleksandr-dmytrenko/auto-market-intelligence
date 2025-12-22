class PriceEstimate < ApplicationRecord
  belongs_to :search_query

  validates :currency, presence: true
end






