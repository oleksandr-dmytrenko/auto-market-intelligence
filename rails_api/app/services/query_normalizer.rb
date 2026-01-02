class QueryNormalizer
  def self.normalize(filters)
    normalized = {}
    
    # Normalize make (capitalize first letter of each word)
    normalized[:make] = filters[:make]&.split(' ')&.map(&:capitalize)&.join(' ') if filters[:make]
    
    # Normalize model (capitalize first letter of each word)
    normalized[:model] = filters[:model]&.split(' ')&.map(&:capitalize)&.join(' ') if filters[:model]
    
    # Normalize year (ensure integer)
    normalized[:year] = filters[:year].to_i if filters[:year]
    
    # Normalize mileage (remove commas, ensure integer)
    normalized[:mileage] = filters[:mileage].to_s.gsub(',', '').to_i if filters[:mileage]
    
    # Normalize color (capitalize)
    normalized[:color] = filters[:color]&.capitalize if filters[:color]
    
    # Normalize damage type (capitalize)
    normalized[:damage_type] = filters[:damage_type]&.capitalize if filters[:damage_type]
    
    # Normalize production year
    normalized[:production_year] = filters[:production_year].to_i if filters[:production_year]
    
    normalized
  end

  def self.validate(filters)
    errors = []
    
    errors << "Make is required" if filters[:make].blank?
    errors << "Model is required" if filters[:model].blank?
    errors << "Year is required" if filters[:year].blank?
    
    if filters[:year].present?
      year = filters[:year].to_i
      errors << "Year must be between 1900 and #{Time.current.year + 1}" unless year.between?(1900, Time.current.year + 1)
    end
    
    if filters[:mileage].present?
      mileage = filters[:mileage].to_s.gsub(',', '').to_i
      errors << "Mileage must be greater than 0" if mileage <= 0
    end
    
    errors
  end
end







