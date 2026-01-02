require 'rails_helper'

RSpec.describe Api::QueriesController, type: :controller do
  describe 'GET #brands' do
    before do
      create(:vehicle, make: 'Toyota')
      create(:vehicle, make: 'Honda')
      create(:vehicle, make: 'BMW')
    end

    it 'returns all brands' do
      get :brands
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['brands']).to be_an(Array)
      expect(json['brands']).to include('BMW', 'Honda', 'Toyota')
    end

    it 'filters brands by query' do
      get :brands, params: { q: 'Toy' }
      json = JSON.parse(response.body)
      expect(json['brands']).to include('Toyota')
      expect(json['brands']).not_to include('Honda', 'BMW')
    end

    it 'limits results to 50' do
      60.times { |i| create(:vehicle, make: "Brand#{i}") }
      get :brands
      json = JSON.parse(response.body)
      expect(json['brands'].size).to be <= 50
    end
  end

  describe 'GET #models' do
    before do
      create(:vehicle, make: 'Toyota', model: 'Camry')
      create(:vehicle, make: 'Toyota', model: 'Corolla')
      create(:vehicle, make: 'Honda', model: 'Accord')
    end

    it 'returns models for a brand' do
      get :models, params: { brand: 'Toyota' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['models']).to include('Camry', 'Corolla')
      expect(json['models']).not_to include('Accord')
    end

    it 'filters models by query' do
      get :models, params: { brand: 'Toyota', q: 'Cam' }
      json = JSON.parse(response.body)
      expect(json['models']).to include('Camry')
      expect(json['models']).not_to include('Corolla')
    end

    it 'returns empty array when brand is blank' do
      get :models, params: { brand: '' }
      json = JSON.parse(response.body)
      expect(json['models']).to eq([])
    end
  end

  describe 'POST #create' do
    let(:user) { create(:user) }
    let(:valid_params) do
      {
        telegram_id: user.telegram_id,
        make: 'Toyota',
        model: 'Camry',
        year: 2020,
        search_active_auctions: false
      }
    end

    before do
      create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, auction_status: 'completed', price: 15000)
      create(:vehicle, make: 'Toyota', model: 'Camry', year: 2020, auction_status: 'completed', price: 20000)
    end

    it 'calculates average price from historical data' do
      allow(PriceCalculator).to receive(:calculate_average_price).and_return({
        average_price: 17500.0,
        median_price: 17500.0,
        confidence: 0.7,
        sample_size: 2
      })

      post :create, params: valid_params
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['average_price']).to eq(17500.0)
      expect(json['sample_size']).to eq(2)
    end

    it 'creates user if not exists' do
      post :create, params: valid_params.merge(telegram_id: 999999999)
      expect(User.find_by(telegram_id: 999999999)).not_to be_nil
    end

    it 'normalizes filters' do
      allow(QueryNormalizer).to receive(:normalize).and_call_original
      post :create, params: valid_params.merge(make: 'toyota', model: 'camry')
      expect(QueryNormalizer).to have_received(:normalize)
    end

    it 'validates filters' do
      post :create, params: { telegram_id: user.telegram_id, make: '', model: '', year: '' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to be_an(Array)
    end

    it 'publishes to Kafka when search_active_auctions is true' do
      allow(KafkaProducerService).to receive(:publish_active_auction_search)
      post :create, params: valid_params.merge(search_active_auctions: true)
      expect(KafkaProducerService).to have_received(:publish_active_auction_search)
    end

    it 'handles errors gracefully' do
      allow(PriceCalculator).to receive(:calculate_average_price).and_raise(StandardError.new('Error'))
      post :create, params: valid_params
      expect(response).to have_http_status(:internal_server_error)
    end

    it 'requires telegram_id' do
      post :create, params: valid_params.except(:telegram_id)
      expect(response).to have_http_status(:bad_request)
    end
  end
end



