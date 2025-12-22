class PriceCalculator
  CACHE_TTL = 24.hours

  def self.calculate_average_price(filters)
    cache_key = cache_key_for_filters(filters)
    
    # Try to get from cache
    cached = Rails.cache.read(cache_key)
    return cached if cached
    
    # Search in completed auctions from IAAI and Copart (historical data)
    vehicles = Vehicle.completed_auctions
                      .by_make_model_year(
                        filters[:make],
                        filters[:model],
                        filters[:year]
                      )
    
    # Apply additional filters if provided
    vehicles = vehicles.where(color: filters[:color]) if filters[:color].present?
    vehicles = vehicles.where(damage_type: filters[:damage_type]) if filters[:damage_type].present?
    
    return nil if vehicles.empty?
    
    prices = vehicles.pluck(:price).compact
    
    return nil if prices.empty?
    
    result = {
      average_price: prices.sum / prices.size.to_f,
      median_price: calculate_median(prices),
      confidence: calculate_confidence(prices.size),
      sample_size: prices.size
    }
    
    # Cache the result
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)
    
    result
  end

  def self.cache_key_for_filters(filters)
    key_parts = [
      'price',
      filters[:make]&.downcase,
      filters[:model]&.downcase,
      filters[:year],
      filters[:color]&.downcase,
      filters[:damage_type]&.downcase
    ].compact.join(':')
    "price:#{key_parts}"
  end

  private

  def self.calculate_median(prices)
    sorted = prices.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  def self.calculate_confidence(sample_size)
    # Confidence based on sample size
    # More samples = higher confidence
    case sample_size
    when 0..5
      0.3
    when 6..10
      0.5
    when 11..20
      0.7
    when 21..50
      0.85
    else
      0.95
    end
  end
end

