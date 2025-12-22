require 'rails_helper'

RSpec.describe KafkaConsumerService do
  let(:mock_kafka) { double('Kafka') }
  let(:mock_consumer) { double('Consumer') }
  let(:mock_message) { double('Message', topic: 'test-topic', value: '{}') }

  before do
    allow(Kafka).to receive(:new).and_return(mock_kafka)
    allow(mock_kafka).to receive(:consumer).and_return(mock_consumer)
    allow(mock_consumer).to receive(:subscribe)
    allow(mock_consumer).to receive(:each_message).and_yield(mock_message)
    allow(mock_consumer).to receive(:stop)
  end

  describe '#process_iaai_data' do
    it 'processes IAAI vehicle data' do
      service = KafkaConsumerService.new
      data = { 'vehicles' => [{ 'source' => 'iaai', 'make' => 'Toyota', 'model' => 'Camry', 'year' => 2020 }] }
      
      expect(VehicleNormalizer).to receive(:normalize).and_return({
        source: 'iaai',
        source_id: '123456',
        make: 'Toyota',
        model: 'Camry',
        year: 2020
      })
      
      expect { service.send(:process_iaai_data, data) }.to change { Vehicle.count }.by(1)
    end
  end

  describe '#process_active_auction_data' do
    it 'processes active auction data' do
      service = KafkaConsumerService.new
      data = {
        'telegram_chat_id' => 123456789,
        'filters' => { 'make' => 'Toyota', 'model' => 'Camry', 'year' => 2020 },
        'vehicles' => []
      }
      
      allow(SimilarityCalculator).to receive(:rank_vehicles_for_filters).and_return([])
      allow(service).to receive(:send_to_telegram)
      
      service.send(:process_active_auction_data, data)
      expect(service).to have_received(:send_to_telegram)
    end
  end

  describe '#save_vehicle' do
    it 'saves vehicle with stock_number' do
      service = KafkaConsumerService.new
      vehicle_data = {
        source: 'iaai',
        stock_number: 'ST123456',
        source_id: '123456',
        make: 'Toyota',
        model: 'Camry',
        year: 2020
      }
      
      service.send(:save_vehicle, vehicle_data)
      expect(Vehicle.find_by(stock_number: 'ST123456')).not_to be_nil
    end

    it 'saves vehicle with source_id when stock_number missing' do
      service = KafkaConsumerService.new
      vehicle_data = {
        source: 'iaai',
        source_id: '123456',
        make: 'Toyota',
        model: 'Camry',
        year: 2020
      }
      
      service.send(:save_vehicle, vehicle_data)
      expect(Vehicle.find_by(source: 'iaai', source_id: '123456')).not_to be_nil
    end
  end
end


