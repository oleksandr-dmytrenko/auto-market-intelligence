require 'rails_helper'

RSpec.describe SimilarityCalculator do
  describe '.calculate_score' do
    let(:filters) { { make: 'Toyota', model: 'Camry', year: 2020, mileage: 50000, color: 'Black', damage_type: 'None' } }
    let(:vehicle) { { make: 'Toyota', model: 'Camry', year: 2020, mileage: 50000, color: 'Black', damage_type: 'None' } }

    it 'calculates perfect match score' do
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to eq(100.0)
    end

    it 'penalizes different make' do
      vehicle[:make] = 'Honda'
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to be < 100.0
    end

    it 'penalizes different model' do
      vehicle[:model] = 'Corolla'
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to be < 100.0
    end

    it 'gives partial credit for close year' do
      vehicle[:year] = 2021
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to be_between(80.0, 100.0)
    end

    it 'penalizes different mileage' do
      vehicle[:mileage] = 100000
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to be < 100.0
    end

    it 'penalizes different color' do
      vehicle[:color] = 'Red'
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to be < 100.0
    end

    it 'penalizes different damage type' do
      vehicle[:damage_type] = 'Minor'
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to be < 100.0
    end

    it 'caps score at 100' do
      score = SimilarityCalculator.calculate_score(filters, vehicle)
      expect(score).to be <= 100.0
    end
  end

  describe '.rank_vehicles_for_filters' do
    let(:filters) { { make: 'Toyota', model: 'Camry', year: 2020 } }
    let(:vehicles) do
      [
        { make: 'Toyota', model: 'Camry', year: 2020 },
        { make: 'Honda', model: 'Accord', year: 2020 },
        { make: 'Toyota', model: 'Corolla', year: 2020 }
      ]
    end

    it 'ranks vehicles by similarity' do
      ranked = SimilarityCalculator.rank_vehicles_for_filters(filters, vehicles, limit: 3)
      expect(ranked.first[0][:make]).to eq('Toyota')
      expect(ranked.first[0][:model]).to eq('Camry')
    end

    it 'limits results' do
      ranked = SimilarityCalculator.rank_vehicles_for_filters(filters, vehicles, limit: 2)
      expect(ranked.size).to eq(2)
    end

    it 'includes rank in results' do
      ranked = SimilarityCalculator.rank_vehicles_for_filters(filters, vehicles, limit: 3)
      expect(ranked.first[2]).to eq(1)
      expect(ranked.last[2]).to eq(3)
    end
  end
end


