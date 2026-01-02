require 'rails_helper'

RSpec.describe VehicleFingerprint do
  describe '.generate' do
    it 'generates consistent fingerprint for same vehicle' do
      vehicle_data = { make: 'Toyota', model: 'Camry', year: 2020, color: 'Black', mileage: 50000, damage_type: 'None' }
      fingerprint1 = VehicleFingerprint.generate(vehicle_data)
      fingerprint2 = VehicleFingerprint.generate(vehicle_data)
      expect(fingerprint1).to eq(fingerprint2)
    end

    it 'generates different fingerprints for different vehicles' do
      vehicle1 = { make: 'Toyota', model: 'Camry', year: 2020 }
      vehicle2 = { make: 'Honda', model: 'Accord', year: 2020 }
      fingerprint1 = VehicleFingerprint.generate(vehicle1)
      fingerprint2 = VehicleFingerprint.generate(vehicle2)
      expect(fingerprint1).not_to eq(fingerprint2)
    end

    it 'handles nil values' do
      vehicle_data = { make: 'Toyota', model: 'Camry', year: 2020, color: nil, mileage: nil }
      fingerprint = VehicleFingerprint.generate(vehicle_data)
      expect(fingerprint).not_to be_nil
    end

    it 'is case insensitive' do
      vehicle1 = { make: 'Toyota', model: 'Camry', year: 2020 }
      vehicle2 = { make: 'toyota', model: 'camry', year: 2020 }
      fingerprint1 = VehicleFingerprint.generate(vehicle1)
      fingerprint2 = VehicleFingerprint.generate(vehicle2)
      expect(fingerprint1).to eq(fingerprint2)
    end
  end

  describe '.mileage_bucket' do
    it 'buckets mileage correctly' do
      expect(VehicleFingerprint.mileage_bucket(5000)).to eq('0-10k')
      expect(VehicleFingerprint.mileage_bucket(15000)).to eq('10-25k')
      expect(VehicleFingerprint.mileage_bucket(30000)).to eq('25-50k')
      expect(VehicleFingerprint.mileage_bucket(60000)).to eq('50-75k')
      expect(VehicleFingerprint.mileage_bucket(80000)).to eq('75-100k')
      expect(VehicleFingerprint.mileage_bucket(120000)).to eq('100-150k')
      expect(VehicleFingerprint.mileage_bucket(200000)).to eq('150k+')
    end

    it 'returns unknown for nil mileage' do
      expect(VehicleFingerprint.mileage_bucket(nil)).to eq('unknown')
    end
  end
end



