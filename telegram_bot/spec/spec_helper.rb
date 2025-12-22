require 'rspec'
require 'json'
require 'redis'
require_relative '../lib/bot'

# Mock Redis for testing
class MockRedis
  def initialize
    @data = {}
  end

  def get(key)
    @data[key]
  end

  def setex(key, ttl, value)
    @data[key] = value
  end

  def del(key)
    @data.delete(key) ? 1 : 0
  end

  def clear
    @data.clear
  end
end

# Mock Telegram Bot API
class MockBot
  attr_accessor :api

  def initialize
    @api = MockTelegramAPI.new
    @sent_messages = []
  end

  def sent_messages
    @sent_messages
  end

  class MockTelegramAPI
    def initialize
      @messages = []
      @inline_queries = []
    end

    def send_message(params)
      @messages << params
      { 'ok' => true, 'result' => { 'message_id' => @messages.size } }
    end

    def answer_inline_query(params)
      @inline_queries << params
      { 'ok' => true }
    end

    def answer_callback_query(params)
      { 'ok' => true }
    end

    def get_me
      { 'ok' => true, 'result' => { 'username' => 'test_bot' } }
    end

    def messages
      @messages
    end

    def inline_queries
      @inline_queries
    end
  end
end

# Mock API
class MockAPI
  def initialize(base_url = nil)
    # Ignore base_url for testing
  end

  def get_brands(query = '')
    brands = ['BMW', 'Mercedes', 'Audi', 'Toyota', 'Honda', 'Ford', 'Hyundai', 'Kia']
    return brands if query.empty?
    brands.select { |b| b.downcase.include?(query.downcase) }
  end

  def get_models(brand, query = '')
    models_by_brand = {
      'BMW' => ['320i', 'X5', 'M3', '520i'],
      'Mercedes' => ['C-Class', 'E-Class', 'S-Class'],
      'Toyota' => ['Camry', 'Corolla', 'RAV4'],
      'Hyundai' => ['Elantra', 'Sonata', 'Tucson'],
      'Kia' => ['Forte', 'Optima', 'Sorento']
    }
    models = models_by_brand[brand] || []
    return models if query.empty?
    models.select { |m| m.downcase.include?(query.downcase) }
  end

  def calculate_price(telegram_id:, username:, filters:)
    { success: true, average_price: 25000, median_price: 24000 }
  end

  def get_vehicle(source, stock_number)
    { success: true, vehicle: { id: 1, make: 'BMW', model: '320i', year: 2018, mileage: 50000, color: 'Black', damage_type: 'Minor', location: 'CA', price: 15000, auction_status: 'Active', auction_url: 'https://example.com' } }
  end

  def search_active_auctions(telegram_chat_id:, telegram_id:, filters:)
    { success: true, vehicles: [], average_price: 25000, median_price: 24000 }
  end
end

RSpec.configure do |config|
  config.before(:each) do
    @mock_redis = MockRedis.new
    @mock_bot = MockBot.new
    @mock_api = MockAPI.new
  end
end

