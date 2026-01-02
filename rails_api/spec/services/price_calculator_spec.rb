require 'rails_helper'

RSpec.describe PriceCalculator do
  describe '.calculate_average_price' do
    let(:filters) { { make: 'Toyota', model: 'Camry', year: 2020 } }

    before do
      Rails.cache.clear
      create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, auction_status: 'completed', price: 15000)
      create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, auction_status: 'completed', price: 20000)
      create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, auction_status: 'completed', price: 25000)
    end

    it 'calculates average and median prices' do
      result = PriceCalculator.calculate_average_price(filters)
      
      expect(result[:average_price]).to eq(20000.0)
      expect(result[:median_price]).to eq(20000.0)
      expect(result[:sample_size]).to eq(3)
    end

    it 'calculates confidence based on sample size' do
      result = PriceCalculator.calculate_average_price(filters)
      expect(result[:confidence]).to be_between(0, 1)
    end

    it 'applies color filter' do
      create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, color: 'Red', auction_status: 'completed', price: 30000)
      result = PriceCalculator.calculate_average_price(filters.merge(color: 'Red'))
      expect(result[:sample_size]).to eq(1)
    end

    it 'applies damage_type filter' do
      create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, damage_type: 'Minor', auction_status: 'completed', price: 10000)
      result = PriceCalculator.calculate_average_price(filters.merge(damage_type: 'Minor'))
      expect(result[:sample_size]).to eq(1)
    end

    it 'returns nil when no vehicles found' do
      result = PriceCalculator.calculate_average_price({ make: 'Nonexistent', model: 'Model', year: 2020 })
      expect(result).to be_nil
    end

    it 'caches results' do
      expect(Rails.cache).to receive(:read).and_return(nil)
      expect(Rails.cache).to receive(:write)
      PriceCalculator.calculate_average_price(filters)
    end

    it 'returns cached result when available' do
      cached_result = { average_price: 10000, median_price: 10000, confidence: 0.5, sample_size: 1 }
      allow(Rails.cache).to receive(:read).and_return(cached_result)
      
      result = PriceCalculator.calculate_average_price(filters)
      expect(result).to eq(cached_result)
    end
  end

  describe '.cache_key_for_filters' do
    it 'generates consistent cache key' do
      filters = { make: 'Toyota', model: 'Camry', year: 2020 }
      key1 = PriceCalculator.cache_key_for_filters(filters)
      key2 = PriceCalculator.cache_key_for_filters(filters)
      expect(key1).to eq(key2)
    end

    it 'includes all filter components' do
      filters = { make: 'Toyota', model: 'Camry', year: 2020, color: 'Red', damage_type: 'Minor' }
      key = PriceCalculator.cache_key_for_filters(filters)
      expect(key).to include('toyota')
      expect(key).to include('camry')
      expect(key).to include('2020')
      expect(key).to include('red')
      expect(key).to include('minor')
    end
  end
end



