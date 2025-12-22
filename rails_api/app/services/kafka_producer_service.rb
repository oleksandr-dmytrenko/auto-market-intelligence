require 'kafka'

class KafkaProducerService
  BIDFAX_SCRAPING_TOPIC = 'bidfax-scraping-jobs'
  ACTIVE_AUCTION_TOPIC = 'active-auction-jobs'

  def self.publish_bidfax_scraping_job(filters)
    instance.publish_bidfax_job(filters)
  end

  def self.publish_active_auction_search(filters:, telegram_chat_id:, telegram_user_id:)
    instance.publish_active_auction_job(filters, telegram_chat_id, telegram_user_id)
  end

  def self.instance
    @instance ||= new
  end

  def initialize
    @kafka = Kafka.new(
      ENV.fetch('KAFKA_BROKERS', 'kafka:29092').split(','),
      client_id: 'rails-api',
      logger: Rails.logger
    )
  end

  # Фоновый скрапинг Bidfax (для накопления данных)
  def publish_bidfax_job(filters)
    producer = @kafka.producer
    
    producer.produce(
      {
        source: 'bidfax',
        filters: filters,
        timestamp: Time.current.to_i
      }.to_json,
      topic: BIDFAX_SCRAPING_TOPIC,
      key: "#{filters[:make]}-#{filters[:model]}-#{filters[:year]}"
    )
    producer.deliver_messages
  rescue => e
    Rails.logger.error("Error publishing Bidfax job: #{e.message}")
    raise
  end

  # Поиск активных аукционов по запросу пользователя
  def publish_active_auction_job(filters, telegram_chat_id, telegram_user_id)
    producer = @kafka.producer
    
    producer.produce(
      {
        filters: filters,
        telegram_chat_id: telegram_chat_id,
        telegram_user_id: telegram_user_id,
        timestamp: Time.current.to_i
      }.to_json,
      topic: ACTIVE_AUCTION_TOPIC,
      key: telegram_chat_id.to_s
    )
    producer.deliver_messages
  rescue => e
    Rails.logger.error("Error publishing active auction job: #{e.message}")
    raise
  end
end


