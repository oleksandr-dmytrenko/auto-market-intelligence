require 'rails_helper'

RSpec.describe Api::VehiclesController, type: :controller do
  describe 'GET #by_partial_vin' do
    let(:partial_vin) { '1HGBH41JXMN1' }
    let!(:vehicle1) { create(:vehicle, partial_vin: partial_vin, auction_status: 'sold', final_price: 15000, auction_end_date: 1.day.ago) }
    let!(:vehicle2) { create(:vehicle, partial_vin: partial_vin, auction_status: 'sold', final_price: 20000, auction_end_date: 2.days.ago) }

    it 'returns aggregated data by partial VIN' do
      get :by_partial_vin, params: { partial_vin: partial_vin }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['partial_vin']).to eq(partial_vin)
      expect(json['statistics']['total_sales']).to eq(2)
      expect(json['statistics']['average_price']).to eq(17500.0)
    end

    it 'returns error for invalid partial VIN' do
      get :by_partial_vin, params: { partial_vin: '123' }
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Invalid partial VIN')
    end

    it 'handles errors gracefully' do
      allow(Vehicle).to receive(:aggregate_by_partial_vin).and_raise(StandardError.new('Error'))
      get :by_partial_vin, params: { partial_vin: partial_vin }
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe 'GET #by_fingerprint' do
    let(:filters) { { make: 'Toyota', model: 'Camry', year: 2020, color: 'Black', mileage: 50000, damage_type: 'None' } }
    let(:fingerprint) { VehicleFingerprint.generate(filters) }
    let!(:vehicle) { create(:vehicle, vehicle_fingerprint: fingerprint, auction_status: 'sold', final_price: 15000, auction_end_date: 1.day.ago) }

    it 'returns aggregated data by fingerprint' do
      get :by_fingerprint, params: filters
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['fingerprint']).not_to be_nil
      expect(json['filters']).to include('make' => 'Toyota', 'model' => 'Camry', 'year' => '2020')
    end

    it 'handles errors gracefully' do
      allow(VehicleFingerprint).to receive(:generate).and_raise(StandardError.new('Error'))
      get :by_fingerprint, params: { make: 'Toyota', model: 'Camry', year: 2020 }
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe 'GET #by_stock' do
    let!(:vehicle) { create(:vehicle, source: 'iaai', stock_number: 'ST123456') }

    it 'finds vehicle by stock number' do
      get :by_stock, params: { source: 'iaai', stock_number: 'ST123456' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['stock_number']).to eq('ST123456')
      expect(json['make']).to eq(vehicle.make)
    end

    it 'finds vehicle by source_id when stock_number not found' do
      vehicle.update(stock_number: nil)
      get :by_stock, params: { source: 'iaai', stock_number: vehicle.source_id }
      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 when vehicle not found' do
      get :by_stock, params: { source: 'iaai', stock_number: 'NONEXISTENT' }
      expect(response).to have_http_status(:not_found)
    end

    it 'handles errors gracefully' do
      allow(Vehicle).to receive(:find_by).and_raise(StandardError.new('Error'))
      get :by_stock, params: { source: 'iaai', stock_number: 'ST123456' }
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe 'GET #by_lot' do
    let!(:vehicle) { create(:vehicle, source: 'iaai', source_id: 'LOT123') }

    it 'finds vehicle by lot_id' do
      get :by_lot, params: { source: 'iaai', lot_id: 'LOT123' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['lot_id']).to eq('LOT123')
    end

    it 'returns 404 when vehicle not found' do
      get :by_lot, params: { source: 'iaai', lot_id: 'NONEXISTENT' }
      expect(response).to have_http_status(:not_found)
    end
  end
end


