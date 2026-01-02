require 'redis'
require 'json'

module Api
  class VehicleAlertsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :find_or_create_user
    before_action :set_alert, only: [:show, :update, :destroy]

    def index
      alerts = current_user.vehicle_alerts.order(created_at: :desc)
      
      render json: {
        alerts: alerts.map { |alert| format_alert(alert) }
      }
    end

    def show
      render json: { alert: format_alert(@alert) }
    end

    def create
      alert = current_user.vehicle_alerts.build(alert_params)
      
      if alert.save
        # Automatically enable notifications when user creates first alert
        enable_notifications_for_user(current_user.telegram_id)
        
        render json: { alert: format_alert(alert) }, status: :created
      else
        render json: { errors: alert.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @alert.update(alert_params)
        render json: { alert: format_alert(@alert) }
      else
        render json: { errors: @alert.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @alert.destroy
      head :no_content
    end

    private

    def set_alert
      @alert = current_user.vehicle_alerts.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Alert not found' }, status: :not_found
    end

    def alert_params
      params.require(:alert).permit(:make, :model, :year_from, :year_to, :damage_type, :mileage_min, :mileage_max, :expires_at, :active)
    end

    def format_alert(alert)
      {
        id: alert.id,
        make: alert.make,
        model: alert.model,
        year_from: alert.year_from,
        year_to: alert.year_to,
        damage_type: alert.damage_type,
        mileage_min: alert.mileage_min,
        mileage_max: alert.mileage_max,
        expires_at: alert.expires_at,
        active: alert.active,
        created_at: alert.created_at,
        updated_at: alert.updated_at
      }
    end

    def find_or_create_user
      telegram_id = params[:telegram_id] || request.headers['X-Telegram-Id'] || request.headers['X-Telegram-User-Id']
      
      unless telegram_id
        render json: { error: 'Telegram ID is required' }, status: :bad_request
        return
      end
      
      @user = User.find_or_create_by(telegram_id: telegram_id) do |user|
        user.username = params[:username]
      end
    end

    def current_user
      @user
    end

    def enable_notifications_for_user(telegram_id)
      # Enable notifications in Redis state (same as telegram bot does)
      redis_url = ENV.fetch('REDIS_URL', 'redis://redis:6379/0')
      redis = Redis.new(url: redis_url)
      
      state_key = "bot:state:#{telegram_id}"
      state_data = redis.get(state_key)
      
      if state_data
        state = JSON.parse(state_data, symbolize_names: true)
        state[:notifications_enabled] = true
        redis.setex(state_key, 86400, state.to_json) # 24 hours TTL
      else
        # Create new state with notifications enabled
        state = {
          notifications_enabled: true,
          premium_active: false,
          search_credits: 0
        }
        redis.setex(state_key, 86400, state.to_json)
      end
    rescue => e
      Rails.logger.error("Error enabling notifications for user #{telegram_id}: #{e.message}")
      # Don't fail the request if Redis is unavailable
    end
  end
end

