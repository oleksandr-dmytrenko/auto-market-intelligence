class Payment < ApplicationRecord
  belongs_to :user

  validates :payment_type, presence: true, inclusion: { in: %w[premium single_search] }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending success failed refunded] }
  validates :currency, presence: true

  scope :successful, -> { where(status: 'success') }
  scope :pending, -> { where(status: 'pending') }
  scope :premium, -> { where(payment_type: 'premium') }
  scope :single_search, -> { where(payment_type: 'single_search') }

  def success?
    status == 'success'
  end

  def pending?
    status == 'pending'
  end

  def premium?
    payment_type == 'premium'
  end

  def single_search?
    payment_type == 'single_search'
  end
end

