require 'json'

module Services
  class StateManager
    def initialize(redis)
      @redis = redis
    end

    def get_state(user_id)
      key = "bot:state:#{user_id}"
      data = @redis.get(key)
      return empty_state if data.nil?
      
      JSON.parse(data, symbolize_names: true)
    rescue => e
      puts "Error reading state: #{e.message}"
      empty_state
    end

    def save_state(user_id, state)
      key = "bot:state:#{user_id}"
      @redis.setex(key, 86400, state.to_json) # 24 часа TTL
    end

    def clear_state(user_id)
      key = "bot:state:#{user_id}"
      @redis.del(key)
    end

    def update_state(user_id, updates)
      state = get_state(user_id)
      state.merge!(updates)
      save_state(user_id, state)
      state
    end

    private

    def empty_state
      {
        chat_id: nil,
        notifications_enabled: false,
        premium_active: false,
        search_credits: 0,
        last_search_filters: nil
      }
    end
  end
end


