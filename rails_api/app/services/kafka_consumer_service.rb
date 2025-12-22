require 'kafka'
require 'telegram/bot'

class KafkaConsumerService
  BIDFAX_DATA_TOPIC = 'bidfax-vehicle-data'
  ACTIVE_AUCTION_DATA_TOPIC = 'active-auction-data'
  IAAI_DATA_TOPIC = 'iaai-vehicle-data'

  def self.start
    new.start
  end

  def initialize
    brokers = ENV.fetch('KAFKA_BROKERS', 'kafka:29092').split(',')
    @kafka = Kafka.new(brokers, client_id: 'rails-api', logger: Rails.logger)
    @telegram_token = ENV.fetch('TELEGRAM_BOT_TOKEN', '')
  end

  def start
    Rails.logger.info "Starting Kafka consumers for topics: #{BIDFAX_DATA_TOPIC}, #{ACTIVE_AUCTION_DATA_TOPIC}, #{IAAI_DATA_TOPIC}"

    consumer = @kafka.consumer(group_id: 'rails-api-consumers')
    consumer.subscribe(BIDFAX_DATA_TOPIC)
    consumer.subscribe(ACTIVE_AUCTION_DATA_TOPIC)
    consumer.subscribe(IAAI_DATA_TOPIC)

    begin
      consumer.each_message do |message|
        process_message(message)
      end
    rescue => e
      Rails.logger.error "Kafka consumer error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    ensure
      consumer.stop
    end
  end

  private

  def process_message(message)
    data = JSON.parse(message.value)
    topic = message.topic

    case topic
    when BIDFAX_DATA_TOPIC
      process_bidfax_data(data)
    when ACTIVE_AUCTION_DATA_TOPIC
      process_active_auction_data(data)
    when IAAI_DATA_TOPIC
      process_iaai_data(data)
    end
  rescue => e
    Rails.logger.error "Error processing message from #{topic}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Обработка данных из Bidfax - сохраняем в БД для статистики
  def process_bidfax_data(data)
    raw_vehicles = data['vehicles'] || []
    Rails.logger.info "Processing #{raw_vehicles.size} Bidfax vehicles"

    normalized = raw_vehicles.map { |v| VehicleNormalizer.normalize(v) }
    
    ActiveRecord::Base.transaction do
      normalized.each do |vehicle_data|
        save_vehicle(vehicle_data.merge(auction_status: 'completed'))
      end
    end

    Rails.logger.info "Saved #{normalized.size} Bidfax vehicles"
  end

  # Обработка данных из IAAI - сохраняем в БД
  def process_iaai_data(data)
    raw_vehicles = data['vehicles'] || []
    Rails.logger.info "Processing #{raw_vehicles.size} IAAI vehicles"

    normalized = raw_vehicles.map { |v| VehicleNormalizer.normalize(v) }
    
    ActiveRecord::Base.transaction do
      normalized.each do |vehicle_data|
        save_vehicle(vehicle_data.merge(auction_status: vehicle_data[:auction_status] || 'completed'))
      end
    end

    Rails.logger.info "Saved #{normalized.size} IAAI vehicles"
  end

  # Обработка активных аукционов - отправляем напрямую в Telegram
  def process_active_auction_data(data)
    telegram_chat_id = data['telegram_chat_id']
    filters = data['filters'] || {}
    raw_vehicles = data['vehicles'] || []

    Rails.logger.info "Processing #{raw_vehicles.size} active auction vehicles for chat #{telegram_chat_id}"

    # Нормализуем данные
    normalized = raw_vehicles.map { |v| VehicleNormalizer.normalize(v) }
    
    # Вычисляем similarity и ранжируем
    query_filters = ActionController::Parameters.new(filters).permit(
      :make, :model, :year, :mileage, :color, :damage_type
    )
    ranked = SimilarityCalculator.rank_vehicles_for_filters(query_filters, normalized, limit: 15)

    # Отправляем в Telegram
    send_to_telegram(telegram_chat_id, ranked, filters)

    # Опционально: сохраняем активные аукционы в БД (для кеша)
    save_active_auctions(normalized) if ranked.any?
  end

  def save_vehicle(vehicle_data)
    vehicle = Vehicle.find_or_initialize_by(
      source: vehicle_data[:source],
      source_id: vehicle_data[:source_id]
    )

    vehicle.assign_attributes(
      make: vehicle_data[:make],
      model: vehicle_data[:model],
      year: vehicle_data[:year],
      mileage: vehicle_data[:mileage],
      color: vehicle_data[:color],
      damage_type: vehicle_data[:damage_type],
      production_year: vehicle_data[:production_year],
      price: vehicle_data[:price] || vehicle_data[:final_price],
      location: vehicle_data[:location],
      auction_url: vehicle_data[:auction_url],
      auction_status: vehicle_data[:auction_status] || 'completed',
      auction_end_date: vehicle_data[:auction_end_date],
      final_price: vehicle_data[:final_price],
      vin: vehicle_data[:vin],
      raw_data: vehicle_data[:raw_data] || {},
      normalized_at: Time.current
    )
    vehicle.save!
  end

  def save_active_auctions(vehicles_data)
    vehicles_data.each do |vehicle_data|
      save_vehicle(vehicle_data.merge(auction_status: 'active'))
    end
  rescue => e
    Rails.logger.error "Error saving active auctions: #{e.message}"
  end

  def send_to_telegram(chat_id, ranked_vehicles, filters)
    return unless @telegram_token.present? && chat_id.present?

    bot = Telegram::Bot::Client.new(@telegram_token)
    
    if ranked_vehicles.empty?
      text = "❌ No active auctions found for #{filters[:make]} #{filters[:model]} #{filters[:year]}"
    else
      text = format_vehicles_for_telegram(ranked_vehicles, filters)
    end

    bot.api.send_message(
      chat_id: chat_id,
      text: text,
      parse_mode: 'HTML',
      disable_web_page_preview: false
    )
  rescue => e
    Rails.logger.error "Error sending to Telegram: #{e.message}"
  end

  def format_vehicles_for_telegram(ranked_vehicles, filters)
    text = "🚗 <b>Active Auctions: #{filters[:make]} #{filters[:model]} #{filters[:year]}</b>\n\n"
    
    ranked_vehicles.each do |vehicle_data, score, rank|
      text += "#{rank}. <b>#{vehicle_data[:make]} #{vehicle_data[:model]} #{vehicle_data[:year]}</b>\n"
      text += "   Mileage: #{format_number(vehicle_data[:mileage])} mi\n" if vehicle_data[:mileage]
      text += "   Color: #{vehicle_data[:color]}\n" if vehicle_data[:color]
      text += "   Damage: #{vehicle_data[:damage_type]}\n" if vehicle_data[:damage_type]
      text += "   Location: #{vehicle_data[:location]}\n" if vehicle_data[:location]
      text += "   Similarity: #{score.round(1)}%\n"
      text += "   Price: $#{format_number(vehicle_data[:price])}\n" if vehicle_data[:price]
      text += "   <a href=\"#{vehicle_data[:auction_url]}\">View Auction</a>\n" if vehicle_data[:auction_url]
      text += "\n"
    end
    
    text
  end

  def format_number(num)
    return 'N/A' unless num
    num.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
