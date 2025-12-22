module Api
  class VehiclesController < ApplicationController
    # GET /api/vehicles/by-partial-vin/:partial_vin
    def by_partial_vin
      partial_vin = params[:partial_vin].to_s.upcase.strip
      
      if partial_vin.blank? || partial_vin.length < 11
        render json: { error: 'Invalid partial VIN (must be at least 11 characters)' }, status: :bad_request
        return
      end
      
      result = Vehicle.aggregate_by_partial_vin(partial_vin)
      
      latest_sale = result&.dig(:latest_sale)
      latest_sale_data = begin
        if latest_sale && latest_sale.respond_to?(:stock_number)
          {
            stock_number: latest_sale.stock_number,
            lot_id: latest_sale.source_id,
            source: latest_sale.source,
            final_price: latest_sale.final_price&.to_f,
            auction_end_date: latest_sale.auction_end_date&.iso8601
          }
        else
          nil
        end
      rescue => e
        Rails.logger.error("Error processing latest_sale: #{e.message}")
        nil
      end
      
      render json: {
        partial_vin: result&.dig(:partial_vin) || partial_vin,
        lots: result&.dig(:lots) || [],
        statistics: {
          total_sales: result&.dig(:total_sales) || 0,
          average_price: result&.dig(:average_price)&.to_f,
          price_trend: result&.dig(:price_trend) || [],
          latest_sale: latest_sale_data
        }
      }, status: :ok
    rescue => e
      Rails.logger.error("Error in by_partial_vin: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'An error occurred' }, status: :internal_server_error
    end
    
    # GET /api/vehicles/by-fingerprint?make=...&model=...&year=...&color=...&mileage=...&damage_type=...
    def by_fingerprint
      filters = params.permit(:make, :model, :year, :color, :mileage, :damage_type).to_h.symbolize_keys
      
      # Генерируем fingerprint из параметров
      fingerprint = VehicleFingerprint.generate(filters)
      
      result = Vehicle.aggregate_by_fingerprint(fingerprint)
      
      latest_sale = result&.dig(:latest_sale)
      latest_sale_data = begin
        if latest_sale && latest_sale.respond_to?(:stock_number)
          {
            stock_number: latest_sale.stock_number,
            lot_id: latest_sale.source_id,
            source: latest_sale.source,
            final_price: latest_sale.final_price&.to_f,
            auction_end_date: latest_sale.auction_end_date&.iso8601
          }
        else
          nil
        end
      rescue => e
        Rails.logger.error("Error processing latest_sale: #{e.message}")
        nil
      end
      
      render json: {
        fingerprint: result&.dig(:fingerprint) || fingerprint,
        filters: filters,
        lots: result&.dig(:lots) || [],
        statistics: {
          total_sales: result&.dig(:total_sales) || 0,
          average_price: result&.dig(:average_price)&.to_f,
          price_trend: result&.dig(:price_trend) || [],
          latest_sale: latest_sale_data
        }
      }, status: :ok
    rescue => e
      Rails.logger.error("Error in by_fingerprint: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'An error occurred' }, status: :internal_server_error
    end
    
    # GET /api/vehicles/by-stock/:source/:stock_number
    def by_stock
      source = params[:source].to_s.downcase
      stock_number = params[:stock_number].to_s.strip
      
      vehicle = Vehicle.find_by(source: source, stock_number: stock_number) ||
                Vehicle.find_by(source: source, source_id: stock_number)
      
      unless vehicle
        render json: { error: 'Vehicle not found' }, status: :not_found
        return
      end
      
      render json: {
        id: vehicle.id,
        source: vehicle.source,
        stock_number: vehicle.stock_number,
        lot_id: vehicle.source_id,
        make: vehicle.make,
        model: vehicle.model,
        year: vehicle.year,
        mileage: vehicle.mileage,
        color: vehicle.color,
        damage_type: vehicle.damage_type,
        price: vehicle.price&.to_f,
        final_price: vehicle.final_price&.to_f,
        auction_status: vehicle.auction_status,
        auction_end_date: vehicle.auction_end_date,
        partial_vin: vehicle.partial_vin,
        vehicle_fingerprint: vehicle.vehicle_fingerprint,
        image_urls: vehicle.image_urls,
        auction_url: vehicle.auction_url,
        location: vehicle.location,
        created_at: vehicle.created_at,
        updated_at: vehicle.updated_at
      }, status: :ok
    rescue => e
      Rails.logger.error("Error in by_stock: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'An error occurred' }, status: :internal_server_error
    end
    
    # GET /api/vehicles/by-lot/:source/:lot_id (legacy)
    def by_lot
      source = params[:source].to_s.downcase
      lot_id = params[:lot_id].to_s.strip
      
      vehicle = Vehicle.find_by(source: source, source_id: lot_id) ||
                Vehicle.find_by(source: source, lot_id: lot_id)
      
      unless vehicle
        render json: { error: 'Vehicle not found' }, status: :not_found
        return
      end
      
      render json: {
        id: vehicle.id,
        source: vehicle.source,
        stock_number: vehicle.stock_number,
        lot_id: vehicle.source_id,
        make: vehicle.make,
        model: vehicle.model,
        year: vehicle.year,
        mileage: vehicle.mileage,
        color: vehicle.color,
        damage_type: vehicle.damage_type,
        price: vehicle.price&.to_f,
        final_price: vehicle.final_price&.to_f,
        auction_status: vehicle.auction_status,
        auction_end_date: vehicle.auction_end_date,
        partial_vin: vehicle.partial_vin,
        vehicle_fingerprint: vehicle.vehicle_fingerprint,
        image_urls: vehicle.image_urls,
        auction_url: vehicle.auction_url,
        location: vehicle.location,
        created_at: vehicle.created_at,
        updated_at: vehicle.updated_at
      }, status: :ok
    rescue => e
      Rails.logger.error("Error in by_lot: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: 'An error occurred' }, status: :internal_server_error
    end
  end
end


