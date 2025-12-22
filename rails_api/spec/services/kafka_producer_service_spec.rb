require 'rails_helper'

RSpec.describe KafkaProducerService do
  let(:mock_kafka) { double('Kafka') }
  let(:mock_producer) { double('Producer') }

  before(:each) do
    # Reset singleton instance before each test
    KafkaProducerService.instance_variable_set(:@instance, nil)
    
    allow(Kafka).to receive(:new).and_return(mock_kafka)
    allow(mock_kafka).to receive(:producer).and_return(mock_producer)
    allow(mock_producer).to receive(:produce)
    allow(mock_producer).to receive(:deliver_messages)
  end

  describe '.publish_active_auction_search' do
    it 'publishes job to Kafka' do
      filters = { make: 'Toyota', model: 'Camry', year: 2020 }
      expect(mock_producer).to receive(:produce)
      expect(mock_producer).to receive(:deliver_messages)
      
      KafkaProducerService.publish_active_auction_search(
        filters: filters,
        telegram_chat_id: 123456789,
        telegram_user_id: 987654321
      )
    end

    it 'handles errors' do
      allow(mock_producer).to receive(:produce).and_raise(StandardError.new('Kafka error'))
      
      expect {
        KafkaProducerService.publish_active_auction_search(
          filters: {},
          telegram_chat_id: 123456789,
          telegram_user_id: 987654321
        )
      }.to raise_error(StandardError)
    end
  end
end

