class VehicleListing < ApplicationRecord
  belongs_to :provider

  has_many :similar_vehicles, dependent: :destroy

  validates :provider_listing_id, presence: true
end






