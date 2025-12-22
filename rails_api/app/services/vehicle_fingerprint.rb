require 'digest'

class VehicleFingerprint
  def self.generate(vehicle_data)
    components = [
      vehicle_data[:make]&.to_s&.downcase&.strip,
      vehicle_data[:model]&.to_s&.downcase&.strip,
      vehicle_data[:year]&.to_s,
      vehicle_data[:color]&.to_s&.downcase&.strip,
      mileage_bucket(vehicle_data[:mileage]),
      vehicle_data[:damage_type]&.to_s&.downcase&.strip
    ].compact.join('|')
    
    Digest::SHA256.hexdigest(components)
  end
  
  def self.mileage_bucket(mileage)
    return 'unknown' unless mileage
    
    mileage_int = mileage.to_i
    case mileage_int
    when 0..10000 then '0-10k'
    when 10001..25000 then '10-25k'
    when 25001..49999 then '25-50k'
    when 50000..75000 then '50-75k'
    when 75001..100000 then '75-100k'
    when 100001..150000 then '100-150k'
    else '150k+'
    end
  end
end


