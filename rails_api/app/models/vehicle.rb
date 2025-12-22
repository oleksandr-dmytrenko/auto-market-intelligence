class Vehicle < ApplicationRecord
  validates :source, presence: true
  validates :source_id, presence: true
  validates :make, presence: true
  validates :model, presence: true
  validates :year, presence: true, numericality: { greater_than: 1900, less_than_or_equal_to: Time.current.year + 1 }
  validates :price, numericality: { greater_than: 0 }, allow_nil: true
  validates :auction_status, inclusion: { in: %w[active completed] }, allow_nil: true
  
  # VIN validation (17 characters, alphanumeric, excluding I, O, Q)
  validates :vin, format: { with: /\A[A-HJ-NPR-Z0-9]{17}\z/, message: "must be a valid 17-character VIN" }, allow_nil: true

  scope :by_make_model_year, ->(make, model, year) { where(make: make, model: model, year: year) }
  scope :similar_year, ->(year, range: 2) { where(year: (year - range)..(year + range)) }
  scope :completed_auctions, -> { where(auction_status: 'completed').where.not(price: nil) }
  scope :active_auctions, -> { where(auction_status: 'active') }
  scope :from_bidfax, -> { where(source: 'bidfax') }
  scope :from_copart, -> { where(source: 'copart') }
  scope :from_iaai, -> { where(source: 'iaai') }
end


