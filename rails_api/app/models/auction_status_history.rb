class AuctionStatusHistory < ApplicationRecord
  self.table_name = 'auction_status_history'
  
  belongs_to :vehicle
  
  validates :new_status, presence: true
  validates :changed_at, presence: true
  validates :new_status, inclusion: { 
    in: %w[active upcoming sold not_sold buy_now archived completed] 
  }
  validates :old_status, inclusion: { 
    in: %w[active upcoming sold not_sold buy_now archived completed] 
  }, allow_nil: true
  
  scope :recent, -> { order(changed_at: :desc) }
  scope :by_status, ->(status) { where(new_status: status) }
end


