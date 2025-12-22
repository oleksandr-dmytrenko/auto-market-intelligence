class SimilarityCalculator
  def self.calculate_score(filters, vehicle_data)
    score = 0.0
    
    # Make/Model/Year (60%)
    score += 20.0 if filters[:make] == vehicle_data[:make]
    score += 20.0 if filters[:model] == vehicle_data[:model]
    
    if filters[:year] && vehicle_data[:year]
      if filters[:year] == vehicle_data[:year]
        score += 20.0
      elsif (filters[:year] - vehicle_data[:year]).abs <= 2
        score += 10.0
      end
    end
    
    # Mileage (25%)
    if filters[:mileage] && vehicle_data[:mileage]
      ratio = (filters[:mileage] - vehicle_data[:mileage]).abs.to_f / [filters[:mileage], 1000].max
      score += 25.0 if ratio <= 0.1
      score += 15.0 if ratio > 0.1 && ratio <= 0.25
      score += 5.0 if ratio > 0.25 && ratio <= 0.5
    end
    
    # Damage type (10%)
    score += 10.0 if filters[:damage_type] == vehicle_data[:damage_type]
    
    # Color (5%)
    score += 5.0 if filters[:color] == vehicle_data[:color]
    
    [score, 100.0].min
  end

  def self.rank_vehicles_for_filters(filters, vehicles_data, limit: 15)
    vehicles_data.map do |vehicle_data|
      [vehicle_data, calculate_score(filters, vehicle_data)]
    end.sort_by { |_, score| -score }.first(limit).map.with_index(1) do |(vehicle_data, score), rank|
      [vehicle_data, score, rank]
    end
  end
end


