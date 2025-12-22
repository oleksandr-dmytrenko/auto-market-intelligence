namespace :kafka do
  desc "Start Kafka consumer"
  task consumer: :environment do
    Rails.logger.info "Starting Kafka consumer..."
    KafkaConsumerService.start
  end
end




