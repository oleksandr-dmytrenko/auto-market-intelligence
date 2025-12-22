require 'rails_helper'

RSpec.describe VehicleNormalizer do
  describe '.normalize' do
    it 'normalizes vehicle data from hash' do
      raw_data = {
        'source' => 'iaai',
        'source_id' => '123456',
        'make' => 'toyota',
        'model' => 'camry',
        'year' => '2020',
        'mileage' => '50,000',
        'color' => 'black',
        'damage_type' => 'none',
        'price' => '$15,000'
      }
      
      normalized = VehicleNormalizer.normalize(raw_data)
      
      expect(normalized[:source]).to eq('iaai')
      expect(normalized[:make]).to eq('Toyota')
      expect(normalized[:model]).to eq('Camry')
      expect(normalized[:year]).to eq(2020)
      expect(normalized[:mileage]).to eq(50000)
      expect(normalized[:color]).to eq('Black')
    end

    it 'handles symbol keys' do
      raw_data = {
        source: 'iaai',
        make: 'Toyota',
        model: 'Camry',
        year: 2020
      }
      
      normalized = VehicleNormalizer.normalize(raw_data)
      expect(normalized[:source]).to eq('iaai')
    end

    it 'normalizes VIN' do
      raw_data = { vin: '1hgbh41jxmn109186' }
      normalized = VehicleNormalizer.normalize(raw_data)
      expect(normalized[:vin]).to eq('1HGBH41JXMN109186')
    end

    it 'extracts partial VIN from full VIN' do
      raw_data = { vin: '1HGBH41JXMN109186' }
      normalized = VehicleNormalizer.normalize(raw_data)
      expect(normalized[:partial_vin]).to eq('1HGBH41JXMN1')
    end

    it 'normalizes image URLs' do
      raw_data = {
        images: ['https://example.com/image1.jpg', 'https://example.com/image2.jpg']
      }
      normalized = VehicleNormalizer.normalize(raw_data)
      expect(normalized[:image_urls]).to eq(['https://example.com/image1.jpg', 'https://example.com/image2.jpg'])
    end

    it 'filters invalid image URLs' do
      raw_data = {
        images: ['https://example.com/image1.jpg', 'invalid-url', 'https://example.com/image2.jpg']
      }
      normalized = VehicleNormalizer.normalize(raw_data)
      expect(normalized[:image_urls].size).to eq(2)
    end

    it 'generates vehicle fingerprint' do
      raw_data = { make: 'Toyota', model: 'Camry', year: 2020 }
      normalized = VehicleNormalizer.normalize(raw_data)
      expect(normalized[:vehicle_fingerprint]).not_to be_nil
    end

    it 'generates mileage bucket' do
      raw_data = { mileage: 50000 }
      normalized = VehicleNormalizer.normalize(raw_data)
      expect(normalized[:mileage_bucket]).to eq('50-75k')
    end
  end
end


