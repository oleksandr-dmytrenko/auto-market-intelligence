module Api
  module V1
    class PriceEstimatesController < BaseController
      def create
        search_query = current_user.search_queries.create!(normalized_search_query_params)

        # TODO: enqueue background job for heavy processing

        render json: {
          id: search_query.id,
          status: search_query.status || "pending"
        }, status: :accepted
      end

      def show
        search_query = current_user.search_queries.find(params[:id])

        render json: {
          id: search_query.id,
          status: search_query.status,
          price_estimate: search_query.price_estimate,
          similar_vehicles: search_query.similar_vehicles.limit(15).includes(:vehicle_listing).map do |sv|
            listing = sv.vehicle_listing
            {
              id: listing.id,
              provider: listing.provider&.name,
              auction_url: listing.auction_url,
              mileage: listing.mileage,
              damage_type: listing.damage_type,
              location: listing.location,
              estimated_price: listing.final_price || listing.current_bid,
              similarity_score: sv.similarity_score
            }
          end
        }
      end

      private

      def normalized_search_query_params
        filters = params.require(:filters).permit(
          :make,
          :model,
          :model_year,
          :production_year,
          :mileage_min,
          :mileage_max,
          :color,
          :damage_type
        )

        filters[:make] = filters[:make].to_s.strip.upcase if filters[:make]
        filters[:model] = filters[:model].to_s.strip.upcase if filters[:model]
        filters[:color] = filters[:color].to_s.strip.downcase if filters[:color]
        filters[:damage_type] = filters[:damage_type].to_s.strip.downcase if filters[:damage_type]
        filters[:status] = "pending"
        filters[:requested_at] = Time.current

        filters
      end
    end
  end
end






