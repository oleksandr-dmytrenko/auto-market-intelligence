module Api
  module V1
    class BaseController < ApplicationController
      protect_from_forgery with: :null_session

      rescue_from ActiveRecord::RecordNotFound do
        render json: { error: "Not found" }, status: :not_found
      end

      private

      def current_user
        @current_user ||= User.find_or_create_by!(telegram_user_id: telegram_user_id)
      end

      def telegram_user_id
        params.require(:telegram_user_id)
      end
    end
  end
end






