module Api
  class QueriesController < ApplicationController
    before_action :find_or_create_user
    before_action :normalize_filters, only: [:create]
    before_action :validate_filters, only: [:create]

    # POST /api/queries
    # Calculate price from Bidfax data and optionally search active auctions
    def create
      begin
        # Calculate price from historical Bidfax data
        price_data = PriceCalculator.calculate_average_price(@normalized_filters)
        
        response_data = {
          average_price: price_data&.dig(:average_price),
          median_price: price_data&.dig(:median_price),
          price_confidence: price_data&.dig(:confidence),
          sample_size: price_data&.dig(:sample_size),
          message: price_data ? 'Price calculated from historical data' : 'No historical data available'
        }

        # If user wants to search active auctions, publish to Kafka
        if params[:search_active_auctions] == 'true'
          KafkaProducerService.publish_active_auction_search(
            filters: @normalized_filters,
            telegram_chat_id: params[:telegram_chat_id],
            telegram_user_id: @user.telegram_id
          )
          response_data[:message] += '. Searching active auctions...'
        end

        render json: response_data, status: :ok

      rescue => e
        Rails.logger.error("Error processing query: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        render json: { error: 'An error occurred processing your request' }, status: :internal_server_error
      end
    end

    private

    def find_or_create_user
      telegram_id = params[:telegram_id] || request.headers['X-Telegram-User-Id']
      
      unless telegram_id
        render json: { error: 'Telegram ID is required' }, status: :bad_request
        return
      end

      @user = User.find_or_create_by(telegram_id: telegram_id) do |user|
        user.username = params[:username]
      end
    end

    def normalize_filters
      @normalized_filters = QueryNormalizer.normalize(
        params.permit(:make, :model, :year, :mileage, :color, :damage_type, :production_year).to_h
      )
    end

    def validate_filters
      errors = QueryNormalizer.validate(@normalized_filters)
      
      if errors.any?
        render json: { errors: errors }, status: :unprocessable_entity
        return
      end
    end
  end
end
