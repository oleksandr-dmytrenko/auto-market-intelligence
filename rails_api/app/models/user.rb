class User < ApplicationRecord
  has_many :payments, dependent: :destroy

  validates :telegram_id, presence: true, uniqueness: true

  def premium?
    premium_active && (premium_expires_at.nil? || premium_expires_at > Time.current)
  end

  def has_search_credits?
    search_credits > 0
  end

  def use_search_credit!
    return false unless has_search_credits?
    decrement!(:search_credits)
    true
  end

  def activate_premium!(expires_at: nil)
    update!(
      premium_active: true,
      premium_expires_at: expires_at || 1.month.from_now
    )
  end

  def deactivate_premium!
    update!(premium_active: false, premium_expires_at: nil)
  end
end


