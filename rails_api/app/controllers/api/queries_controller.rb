module Api
  class QueriesController < ApplicationController
    before_action :find_or_create_user, only: [:create]
    before_action :normalize_filters, only: [:create]
    before_action :validate_filters, only: [:create]

    # GET /api/brands?q=query
    def brands
      query = params[:q].to_s.downcase.strip
      
      brands = Vehicle.distinct.pluck(:make).compact.sort
      
      if query.present?
        brands = brands.select { |b| b.downcase.include?(query) }
      end
      
      render json: { brands: brands.first(50) }, status: :ok
    end

    # GET /api/models?brand=BrandName&q=query
    def models
      brand = params[:brand].to_s.strip
      query = params[:q].to_s.downcase.strip
      
      return render json: { models: [] }, status: :ok if brand.blank?
      
      models = Vehicle.where(make: brand).distinct.pluck(:model).compact.sort
      
      if query.present?
        models = models.select { |m| m.downcase.include?(query) }
      end
      
      render json: { models: models.first(50) }, status: :ok
    end

    # POST /api/queries
    # Calculate price from historical auction data and optionally search active auctions
    def create
      begin
        # Calculate price from historical completed auction data
        price_data = PriceCalculator.calculate_average_price(@normalized_filters)
        
        response_data = {
          average_price: price_data&.dig(:average_price),
          median_price: price_data&.dig(:median_price),
          price_confidence: price_data&.dig(:confidence),
          sample_size: price_data&.dig(:sample_size),
          message: price_data ? 'Price calculated from historical data' : 'No historical data available'
        }

        # If user wants to search active auctions, publish to Kafka
        # Поддерживаем как boolean, так и строку 'true'
        search_active = params[:search_active_auctions]
        if search_active == true || search_active == 'true' || search_active.to_s.downcase == 'true'
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
      # Разрешаем все параметры для использования в контроллере
      permitted_params = params.permit(
        :make, :model, :year, :mileage, :color, :damage_type, :production_year,
        :year_from, :year_to, :mileage_from, :mileage_to,
        :telegram_id, :telegram_chat_id, :search_active_auctions
      ).to_h
      
      # Преобразуем диапазоны в одно значение для нормализатора
      filters_for_normalizer = permitted_params.dup
      
      # Если есть year_from и year_to, используем среднее значение или year_from
      if filters_for_normalizer[:year_from].present? && filters_for_normalizer[:year_to].present?
        year_from = filters_for_normalizer[:year_from].to_i
        year_to = filters_for_normalizer[:year_to].to_i
        filters_for_normalizer[:year] = ((year_from + year_to) / 2.0).round
      elsif filters_for_normalizer[:year_from].present?
        filters_for_normalizer[:year] = filters_for_normalizer[:year_from].to_i
      end
      
      # Если есть mileage_from и mileage_to, используем среднее значение или mileage_from
      if filters_for_normalizer[:mileage_from].present? && filters_for_normalizer[:mileage_to].present?
        mileage_from = filters_for_normalizer[:mileage_from].to_i
        mileage_to = filters_for_normalizer[:mileage_to].to_i
        filters_for_normalizer[:mileage] = ((mileage_from + mileage_to) / 2.0).round
      elsif filters_for_normalizer[:mileage_from].present?
        filters_for_normalizer[:mileage] = filters_for_normalizer[:mileage_from].to_i
      end
      
      @normalized_filters = QueryNormalizer.normalize(filters_for_normalizer)
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
