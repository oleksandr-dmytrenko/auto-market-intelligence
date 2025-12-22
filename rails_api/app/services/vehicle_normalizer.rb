class VehicleNormalizer
  def self.normalize(vehicle_data)
    normalized = {
      source: vehicle_data['source'] || vehicle_data[:source],
      source_id: vehicle_data['source_id'] || vehicle_data[:source_id],
      lot_id: vehicle_data['lot_id'] || vehicle_data[:source_id], # По умолчанию используем source_id
      stock_number: vehicle_data['stock_number'] || vehicle_data[:stock_number],
      make: normalize_make(vehicle_data['make'] || vehicle_data[:make]),
      model: normalize_model(vehicle_data['model'] || vehicle_data[:model]),
      year: normalize_year(vehicle_data['year'] || vehicle_data[:year]),
      mileage: normalize_mileage(vehicle_data['mileage'] || vehicle_data[:mileage]),
      color: normalize_string(vehicle_data['color'] || vehicle_data[:color]),
      damage_type: normalize_damage(vehicle_data['damage_type'] || vehicle_data[:damage_type]),
      production_year: normalize_year(vehicle_data['production_year'] || vehicle_data[:production_year]),
      price: normalize_price(vehicle_data['price'] || vehicle_data[:price]),
      final_price: normalize_price(vehicle_data['final_price'] || vehicle_data[:final_price]),
      location: vehicle_data['location'] || vehicle_data[:location] || '',
      auction_url: vehicle_data['auction_url'] || vehicle_data[:auction_url] || '',
      auction_status: vehicle_data['auction_status'] || vehicle_data[:auction_status] || 'completed',
      auction_end_date: normalize_timestamp(vehicle_data['auction_end_date'] || vehicle_data[:auction_end_date]),
      vin: normalize_vin(vehicle_data['vin'] || vehicle_data[:vin]),
      image_urls: normalize_image_urls(vehicle_data['images'] || vehicle_data[:images] || []),
      raw_data: {
        'vin' => vehicle_data['vin'] || vehicle_data[:vin],
        'images' => vehicle_data['images'] || vehicle_data[:images] || [],
        'title' => vehicle_data['raw_data']&.dig('title') || vehicle_data[:raw_data]&.dig('title'),
        'stock_number' => vehicle_data['stock_number'] || vehicle_data[:stock_number]
      }.merge(vehicle_data['raw_data'] || vehicle_data[:raw_data] || {})
    }
    
    # Извлекаем partial VIN из полного VIN или из raw_data
    vin = normalized[:vin]
    if vin.present? && vin.length >= 11
      normalized[:partial_vin] = vin[0..11] # Первые 12 символов (indices 0-11)
    elsif vehicle_data['partial_vin'] || vehicle_data[:partial_vin]
      normalized[:partial_vin] = normalize_partial_vin(vehicle_data['partial_vin'] || vehicle_data[:partial_vin])
    end
    
    # Генерируем mileage_bucket и vehicle_fingerprint
    normalized[:mileage_bucket] = VehicleFingerprint.mileage_bucket(normalized[:mileage])
    normalized[:vehicle_fingerprint] = VehicleFingerprint.generate(normalized)
    
    normalized
  end

  private

  def self.normalize_make(value)
    return '' if value.blank?
    value.to_s.split(' ').map(&:capitalize).join(' ')
  end

  def self.normalize_model(value)
    return '' if value.blank?
    value.to_s.split(' ').map(&:capitalize).join(' ')
  end

  def self.normalize_year(value)
    return nil if value.blank?
    year = value.to_i
    (1900..2030).include?(year) ? year : nil
  end

  def self.normalize_mileage(value)
    return nil if value.blank?
    value.to_s.gsub(/[^\d]/, '').to_i
  rescue
    nil
  end

  def self.normalize_string(value)
    return nil if value.blank?
    value.to_s.capitalize
  end

  def self.normalize_damage(value)
    return nil if value.blank?
    damage_map = {
      'none' => 'None',
      'no damage' => 'None',
      'minor' => 'Minor',
      'moderate' => 'Moderate',
      'severe' => 'Severe',
      'total loss' => 'Total Loss',
      'salvage' => 'Salvage'
    }
    damage_map[value.to_s.downcase] || value.to_s.capitalize
  end

  def self.normalize_price(value)
    return nil if value.blank?
    value.to_s.gsub(/[^\d.]/, '').to_f
  rescue
    nil
  end

  def self.normalize_timestamp(value)
    return nil if value.blank?
    Time.at(value.to_i) if value.to_i > 0
  rescue
    nil
  end

  def self.normalize_vin(value)
    return nil if value.blank?
    vin = value.to_s.upcase.strip
    # VIN должен быть 17 символов, только буквы и цифры (кроме I, O, Q)
    vin.match?(/\A[A-HJ-NPR-Z0-9]{17}\z/) ? vin : nil
  rescue
    nil
  end

  def self.normalize_image_urls(value)
    return [] if value.blank?
    
    # Если это массив, обрабатываем каждый элемент
    if value.is_a?(Array)
      urls = value.map do |url|
        url.to_s.strip
      end.compact.reject(&:blank?).uniq
      
      # Фильтруем только валидные URL
      urls.select { |url| url.match?(/\Ahttps?:\/\/.+\z/) }
    else
      # Если это строка, пробуем разбить по запятой или пробелу
      urls = value.to_s.split(/[,\s]+/).map(&:strip).compact.reject(&:blank?).uniq
      urls.select { |url| url.match?(/\Ahttps?:\/\/.+\z/) }
    end
  rescue
    []
  end
  
  def self.normalize_partial_vin(value)
    return nil if value.blank?
    partial_vin = value.to_s.upcase.strip.gsub(/[^A-HJ-NPR-Z0-9]/, '')
    # Partial VIN обычно 11-13 символов
    partial_vin.length >= 11 ? partial_vin[0..12] : nil
  rescue
    nil
  end
end


