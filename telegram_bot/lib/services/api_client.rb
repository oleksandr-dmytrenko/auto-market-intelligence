require 'httparty'

module Services
  class ApiClient
    include HTTParty

    def initialize(base_url)
      self.class.base_uri base_url
    end

    def get_brands(query = '')
      get_data('/api/brands', { q: query }, 'brands')
    end

    def get_models(brand, query = '')
      get_data('/api/models', { brand: brand, q: query }, 'models')
    end

    def search_active_auctions(telegram_chat_id:, telegram_id:, filters:)
      options = {
        body: {
          telegram_id: telegram_id,
          telegram_chat_id: telegram_chat_id,
          search_active_auctions: true,
          **filters
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
        timeout: 20
      }
      
      response = self.class.post('/api/queries', options)
      
      if response.success?
        parsed = response.parsed_response || {}
        { success: true, **parsed.transform_keys(&:to_sym) }
      else
        { success: false, error: "HTTP #{response.code}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def get_vehicle(source, stock_number)
      response = self.class.get("/api/vehicles/by-stock/#{source}/#{stock_number}", timeout: 10)
      
      if response.success?
        parsed = response.parsed_response || {}
        { success: true, vehicle: parsed.transform_keys(&:to_sym) }
      else
        { success: false, error: "HTTP #{response.code}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def get_vehicle_alerts(telegram_id)
      response = self.class.get('/api/vehicle_alerts', 
        query: { telegram_id: telegram_id.to_s },
        timeout: 10
      )
      
      if response.success?
        parsed = response.parsed_response || {}
        { success: true, alerts: parsed['alerts'] || [] }
      else
        { success: false, error: "HTTP #{response.code}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def create_vehicle_alert(telegram_id, alert_params)
      options = {
        body: { 
          alert: alert_params,
          telegram_id: telegram_id.to_s
        }.to_json,
        headers: { 
          'Content-Type' => 'application/json'
        },
        timeout: 20
      }
      
      response = self.class.post('/api/vehicle_alerts', options)
      
      if response.success?
        parsed = response.parsed_response || {}
        { success: true, alert: parsed['alert'] }
      else
        parsed = response.parsed_response || {}
        { success: false, error: parsed['errors'] || "HTTP #{response.code}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def delete_vehicle_alert(telegram_id, alert_id)
      response = self.class.delete("/api/vehicle_alerts/#{alert_id}",
        query: { telegram_id: telegram_id.to_s },
        timeout: 10
      )
      
      { success: response.success? }
    rescue => e
      { success: false, error: e.message }
    end

    private

    def get_data(endpoint, query_params, key)
      response = self.class.get(endpoint, query: query_params, timeout: 5)
      return [] unless response.success?
      
      parsed = response.parsed_response || {}
      parsed[key] || parsed[key.to_sym] || []
    rescue
      []
    end
  end
end



