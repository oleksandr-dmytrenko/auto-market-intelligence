require 'rails_helper'

RSpec.describe QueryNormalizer do
  describe '.normalize' do
    it 'normalizes make' do
      result = QueryNormalizer.normalize({ make: 'toyota' })
      expect(result[:make]).to eq('Toyota')
    end

    it 'normalizes model' do
      result = QueryNormalizer.normalize({ model: 'camry se' })
      expect(result[:model]).to eq('Camry Se')
    end

    it 'normalizes year to integer' do
      result = QueryNormalizer.normalize({ year: '2020' })
      expect(result[:year]).to eq(2020)
    end

    it 'normalizes mileage by removing commas' do
      result = QueryNormalizer.normalize({ mileage: '50,000' })
      expect(result[:mileage]).to eq(50000)
    end

    it 'normalizes color' do
      result = QueryNormalizer.normalize({ color: 'red' })
      expect(result[:color]).to eq('Red')
    end

    it 'normalizes damage_type' do
      result = QueryNormalizer.normalize({ damage_type: 'minor' })
      expect(result[:damage_type]).to eq('Minor')
    end

    it 'handles nil values' do
      result = QueryNormalizer.normalize({ make: nil, model: nil })
      expect(result[:make]).to be_nil
      expect(result[:model]).to be_nil
    end
  end

  describe '.validate' do
    it 'validates required fields' do
      errors = QueryNormalizer.validate({})
      expect(errors).to include('Make is required')
      expect(errors).to include('Model is required')
      expect(errors).to include('Year is required')
    end

    it 'validates year range' do
      errors = QueryNormalizer.validate({ make: 'Toyota', model: 'Camry', year: 1800 })
      expect(errors).to include(match(/Year must be between/))
    end

    it 'validates mileage' do
      errors = QueryNormalizer.validate({ make: 'Toyota', model: 'Camry', year: 2020, mileage: 0 })
      expect(errors).to include('Mileage must be greater than 0')
    end

    it 'returns empty array for valid filters' do
      errors = QueryNormalizer.validate({ make: 'Toyota', model: 'Camry', year: 2020 })
      expect(errors).to be_empty
    end

    it 'accepts future year' do
      future_year = Time.current.year + 1
      errors = QueryNormalizer.validate({ make: 'Toyota', model: 'Camry', year: future_year })
      expect(errors).not_to include(match(/Year must be between/))
    end
  end
end



