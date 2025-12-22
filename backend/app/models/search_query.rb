class SearchQuery < ApplicationRecord
  belongs_to :user

  has_one :price_estimate, dependent: :destroy
  has_many :similar_vehicles, dependent: :destroy

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, validate: true, suffix: true

  validates :make, :model, :model_year, presence: true
end

