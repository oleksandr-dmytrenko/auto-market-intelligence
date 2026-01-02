class VehicleAlert < ApplicationRecord
  belongs_to :user

  before_validation :set_default_expires_at, on: :create

  validates :make, presence: true
  validates :model, presence: true
  validates :expires_at, presence: true
  validates :year_from, numericality: { greater_than: 1900, less_than_or_equal_to: Time.current.year + 1 }, allow_nil: true
  validates :year_to, numericality: { greater_than: 1900, less_than_or_equal_to: Time.current.year + 1 }, allow_nil: true
  validates :mileage_min, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :mileage_max, numericality: { greater_than: 0 }, allow_nil: true
  validate :mileage_range_valid
  validate :year_range_valid
  validate :expires_at_in_future

  scope :active, -> { where(active: true) }
  scope :not_expired, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def matches_vehicle?(vehicle)
    return false unless vehicle.is_a?(Vehicle)
    
    # Check make and model (required) - case insensitive
    return false if vehicle.make.blank? || make.blank?
    return false unless vehicle.make.to_s.downcase.strip == make.to_s.downcase.strip
    return false if vehicle.model.blank? || model.blank?
    return false unless vehicle.model.to_s.downcase.strip == model.to_s.downcase.strip
    
    # Check year range if specified
    if year_from.present? || year_to.present?
      vehicle_year = vehicle.year
      return false if vehicle_year.nil? # Can't match if vehicle has no year
      
      if year_from.present? && vehicle_year < year_from
        return false
      end
      
      if year_to.present? && vehicle_year > year_to
        return false
      end
    end
    
    # Check damage_type if specified - case insensitive
    if damage_type.present?
      return false if vehicle.damage_type.blank?
      return false unless vehicle.damage_type.to_s.downcase.strip == damage_type.to_s.downcase.strip
    end
    
    # Check mileage range if specified
    if mileage_min.present? || mileage_max.present?
      vehicle_mileage = vehicle.mileage
      return false if vehicle_mileage.nil? # Can't match if vehicle has no mileage
      
      if mileage_min.present? && vehicle_mileage < mileage_min
        return false
      end
      
      if mileage_max.present? && vehicle_mileage > mileage_max
        return false
      end
    end
    
    # Check if already notified for this vehicle
    return false if notified_vehicle_ids.include?(vehicle.id.to_s)
    
    true
  end

  def mark_vehicle_notified!(vehicle_id)
    self.notified_vehicle_ids = (notified_vehicle_ids + [vehicle_id.to_s]).uniq
    save!
  end

  def deactivate!
    update!(active: false)
  end

  private

  def mileage_range_valid
    return unless mileage_min.present? && mileage_max.present?
    
    if mileage_min >= mileage_max
      errors.add(:mileage_max, 'must be greater than mileage_min')
    end
  end

  def year_range_valid
    return unless year_from.present? && year_to.present?
    
    if year_from > year_to
      errors.add(:year_to, 'must be greater than or equal to year_from')
    end
  end

  def expires_at_in_future
    return unless expires_at.present?
    
    if expires_at <= Time.current
      errors.add(:expires_at, 'must be in the future')
    end
  end

  def set_default_expires_at
    self.expires_at ||= 1.week.from_now if expires_at.blank?
  end
end

