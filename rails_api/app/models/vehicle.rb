class Vehicle < ApplicationRecord
  has_many :auction_status_histories, class_name: 'AuctionStatusHistory', dependent: :destroy
  
  validates :source, presence: true
  validates :source_id, presence: true
  validates :make, presence: true
  validates :model, presence: true
  validates :year, presence: true, numericality: { greater_than: 1900, less_than_or_equal_to: Time.current.year + 1 }
  validates :price, numericality: { greater_than: 0 }, allow_nil: true
  validates :auction_status, inclusion: { in: %w[active completed sold not_sold buy_now upcoming archived] }, allow_nil: true
  
  validates :vin, format: { with: /\A[A-HJ-NPR-Z0-9]{17}\z/, message: "must be a valid 17-character VIN" }, allow_nil: true
  
  validates :partial_vin, format: { with: /\A[A-HJ-NPR-Z0-9]{11,13}\z/, message: "must be a valid partial VIN (11-13 characters)" }, allow_nil: true
  
  validate :validate_image_urls_format
  
  before_save :update_status_changed_at, if: -> { persisted? && will_save_change_to_auction_status? }
  before_save :ensure_vehicle_fingerprint
  before_save :capture_status_change_for_history
  after_save :record_status_change_safely
  after_commit :check_vehicle_alerts, on: [:create, :update], if: -> { auction_status.in?(%w[active upcoming]) }
  
  has_many_attached :images
  def has_images?
    image_urls.present? && image_urls.is_a?(Array) && image_urls.any?
  end
  
  def image_count
    has_images? ? image_urls.size : 0
  end
  
  def primary_image_url
    has_images? ? image_urls.first : nil
  end
  
  # Methods for local images
  def has_local_images?
    images.attached?
  end
  
  def local_image_count
    images.count
  end
  
  def primary_local_image
    images.first if images.attached?
  end
  
  def get_primary_image
    primary_local_image || primary_image_url
  end
  
  def download_images_async
    if auction_status.in?(%w[sold not_sold buy_now completed])
      VehicleImageDownloaderJob.perform_later(id)
    end
  end
  
  scope :by_partial_vin, ->(partial_vin) { where(partial_vin: partial_vin) }
  scope :by_fingerprint, ->(fingerprint) { where(vehicle_fingerprint: fingerprint) }
  scope :sold, -> { where(auction_status: 'sold').where.not(final_price: nil) }
  scope :recent_sales, -> { order(auction_end_date: :desc).order(created_at: :desc) }
  scope :by_stock_number, ->(stock_number) { where(stock_number: stock_number) }
  
  scope :by_make_model_year, ->(make, model, year) { where(make: make, model: model, year: year) }
  scope :similar_year, ->(year, range: 2) { where(year: (year - range)..(year + range)) }
  scope :completed_auctions, -> { where(auction_status: 'completed').where.not(final_price: nil) }
  scope :active_auctions, -> { where(auction_status: 'active') }
  scope :from_copart, -> { where(source: 'copart') }
  scope :from_iaai, -> { where(source: 'iaai') }
  
  def self.aggregate_by_partial_vin(partial_vin)
    vehicles = by_partial_vin(partial_vin).sold.recent_sales
    
    {
      partial_vin: partial_vin,
      total_sales: vehicles.count,
      average_price: vehicles.average(:final_price)&.to_f,
      price_trend: vehicles.pluck(:auction_end_date, :final_price).reject { |pair| pair[0].nil? || pair[1].nil? },
      latest_sale: vehicles.first,
      lots: vehicles.map { |v| 
        { 
          stock_number: v.stock_number, 
          lot_id: v.source_id, 
          source: v.source,
          make: v.make, 
          model: v.model, 
          year: v.year,
          final_price: v.final_price&.to_f,
          auction_end_date: v.auction_end_date
        } 
      }
    }
  end
  
  def self.aggregate_by_fingerprint(fingerprint)
    vehicles = by_fingerprint(fingerprint).sold.recent_sales
    
    {
      fingerprint: fingerprint,
      total_sales: vehicles.count,
      average_price: vehicles.average(:final_price)&.to_f,
      price_trend: vehicles.pluck(:auction_end_date, :final_price).reject { |pair| pair[0].nil? || pair[1].nil? },
      latest_sale: vehicles.first,
      lots: vehicles.map { |v| 
        { 
          stock_number: v.stock_number, 
          lot_id: v.source_id, 
          source: v.source,
          make: v.make, 
          model: v.model, 
          year: v.year,
          final_price: v.final_price&.to_f,
          auction_end_date: v.auction_end_date
        } 
      }
    }
  end
  
  def self.find_vehicle_history(partial_vin: nil, fingerprint: nil)
    vehicles = Vehicle.all
    
    vehicles = vehicles.by_partial_vin(partial_vin) if partial_vin.present?
    vehicles = vehicles.by_fingerprint(fingerprint) if fingerprint.present?
    
    vehicles.sold.recent_sales
  end
  
  def mark_as_upcoming!
    update!(auction_status: 'upcoming')
  end
  
  def mark_as_active!
    update!(auction_status: 'active')
  end
  
  def mark_as_sold!(final_price_value = nil)
    update!(
      auction_status: 'sold',
      final_price: final_price_value || price
    )
  end
  
  def mark_as_not_sold!
    update!(auction_status: 'not_sold')
  end
  
  def mark_as_buy_now!(final_price_value = nil)
    update!(
      auction_status: 'buy_now',
      final_price: final_price_value || price
    )
  end
  
  def mark_as_archived!
    update!(auction_status: 'archived')
  end
  
  def mark_as_completed!(final_price_value = nil)
    if final_price_value.present? && final_price_value > 0
      mark_as_sold!(final_price_value)
    else
      mark_as_not_sold!
    end
  end
  
  private
  
  def validate_image_urls_format
    return if image_urls.blank?
    
    unless image_urls.is_a?(Array)
      errors.add(:image_urls, "must be an array")
      return
    end
    
    image_urls.each_with_index do |url, index|
      unless url.is_a?(String) && url.match?(/\Ahttps?:\/\/.+\z/)
        errors.add(:image_urls, "contains invalid URL at index #{index}")
      end
    end
  end
  
  def update_status_changed_at
    self.status_changed_at = Time.current
  end
  
  def ensure_vehicle_fingerprint
    return if vehicle_fingerprint.present?
    return unless make.present? && model.present? && year.present?
    
    self.vehicle_fingerprint = VehicleFingerprint.generate(
      make: make,
      model: model,
      year: year,
      color: color,
      mileage: mileage,
      damage_type: damage_type
    )
  end
  
  # Capture status change data before save to use in after_save callback
  def capture_status_change_for_history
    if will_save_change_to_auction_status?
      @_status_change_data = {
        old_status: persisted? ? auction_status_in_database : nil,
        new_status: auction_status,
        old_price: will_save_change_to_price? ? (persisted? ? price_in_database : price) : price,
        new_price: price
      }
    end
  end
  
  # Safely record status change without affecting the main transaction
  def record_status_change_safely
    return unless @_status_change_data
    
    data = @_status_change_data
    @_status_change_data = nil  # Clear to avoid memory leaks
    
    old_status = data[:old_status]
    new_status = data[:new_status]
    old_price = data[:old_price]
    new_price = data[:new_price]
    
    return unless new_status.present?
    return if old_status == new_status  # Skip if status didn't actually change
    
    # Create history record safely without affecting the main transaction
    # Use create (not create!) and handle errors gracefully
    begin
      history = AuctionStatusHistory.new(
        vehicle_id: id,
        old_status: old_status,
        new_status: new_status,
        price_before: old_price,
        price_after: new_price,
        changed_at: status_changed_at || Time.current
      )
      
      unless history.save
        Rails.logger.error("Failed to create AuctionStatusHistory: #{history.errors.full_messages.join(', ')}")
      end
    rescue ActiveRecord::StatementInvalid, PG::InFailedSqlTransaction => e
      # Database-level errors (constraints, failed transactions, etc.) - log but don't fail
      Rails.logger.error("Database error creating AuctionStatusHistory: #{e.message}")
      # Don't re-raise - the history record is not critical
    rescue => e
      # Catch any other exceptions and log them
      # but don't re-raise to avoid affecting the main transaction
      Rails.logger.error("Failed to create AuctionStatusHistory: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      # In test environments, we want to ensure this doesn't break the transaction
      # The history record is not critical for the vehicle save operation
    end
    
    if new_status.in?(%w[sold not_sold buy_now completed]) && old_status != new_status
      download_images_async
    end
  end

  def check_vehicle_alerts
    # Check alerts asynchronously for new/updated active vehicles
    VehicleAlertCheckJob.perform_later(id) if auction_status.in?(%w[active upcoming])
  end
end




