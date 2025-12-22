require 'telegram/bot'
require 'httparty'
require 'dotenv/load'

class CarPriceBot
  API_URL = ENV.fetch('RAILS_API_URL', 'http://rails_api:3000')

  def initialize
    @token = ENV.fetch('TELEGRAM_BOT_TOKEN')
    @api = API.new(API_URL)
  end

  def run
    Telegram::Bot::Client.run(@token) do |bot|
      bot.listen do |message|
        if message.is_a?(Telegram::Bot::Types::CallbackQuery)
          handle_callback(bot, message)
        else
          handle_message(bot, message)
        end
      end
    end
  end

  private

  def handle_message(bot, message)
    case message.text
    when /^\/start/
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Welcome! Send me car details in this format:\n\n" \
              "Make: Toyota\n" \
              "Model: Camry\n" \
              "Year: 2020\n" \
              "Mileage: 50000\n" \
              "Color: Black\n" \
              "Damage: None"
      )
    when /^Make:|^Model:|^Year:/
      handle_car_query(bot, message)
    else
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Please send car details in the format:\n\n" \
              "Make: [make]\nModel: [model]\nYear: [year]\n" \
              "Mileage: [mileage]\nColor: [color]\nDamage: [damage]"
      )
    end
  end

  def handle_car_query(bot, message)
    begin
      filters = parse_filters(message.text)
      
      if filters[:make].blank? || filters[:model].blank? || filters[:year].blank?
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Error: Make, Model, and Year are required fields."
        )
        return
      end

      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Calculating price from historical data..."
      )

      # Get price from Rails API (searches in Bidfax data)
      response = @api.calculate_price(
        telegram_id: message.from.id,
        username: message.from.username,
        filters: filters
      )

      if response[:success]
        price_text = format_price_response(response)
        
        # Send price to user
        bot.api.send_message(
          chat_id: message.chat.id,
          text: price_text,
          parse_mode: 'HTML'
        )

        # Ask if user wants to search active auctions
        if response[:average_price]
          bot.api.send_message(
            chat_id: message.chat.id,
            text: "Would you like to search for active auctions? Reply 'yes' or 'no'",
            reply_markup: {
              inline_keyboard: [
                [
                  { text: "Yes, search active auctions", callback_data: "search_yes:#{filters.to_json}" },
                  { text: "No", callback_data: "search_no" }
                ]
              ]
            }
          )
        end
      else
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Error: #{response[:error]}"
        )
      end
    rescue Telegram::Bot::Exceptions::ResponseError => e
      puts "Telegram API error: #{e.message}"
    rescue => e
      puts "Error handling car query: #{e.message}"
      puts e.backtrace.join("\n")
      begin
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "An error occurred. Please try again later."
        )
      rescue
        puts "Could not send error message to user"
      end
    end
  end

  def handle_callback(bot, callback)
    case callback.data
    when /^search_yes:(.+)$/
      filters_json = $1
      filters = JSON.parse(filters_json)
      
      bot.api.send_message(
        chat_id: callback.message.chat.id,
        text: "Searching active auctions on IAAI and Copart..."
      )

      # Request active auction search
      response = @api.search_active_auctions(
        telegram_chat_id: callback.message.chat.id,
        telegram_id: callback.from.id,
        filters: filters
      )

      if response[:success]
        bot.api.send_message(
          chat_id: callback.message.chat.id,
          text: "Search started. Results will be sent shortly..."
        )
      else
        bot.api.send_message(
          chat_id: callback.message.chat.id,
          text: "Error starting search: #{response[:error]}"
        )
      end
    when 'search_no'
      bot.api.send_message(
        chat_id: callback.message.chat.id,
        text: "Okay. Let me know if you need anything else!"
      )
    end
  end

  def parse_filters(text)
    filters = {}
    
    text.split("\n").each do |line|
      case line
      when /^Make:\s*(.+)/i
        filters[:make] = $1.strip
      when /^Model:\s*(.+)/i
        filters[:model] = $1.strip
      when /^Year:\s*(\d+)/i
        filters[:year] = $1.strip.to_i
      when /^Mileage:\s*([\d,]+)/i
        filters[:mileage] = $1.strip.gsub(',', '').to_i
      when /^Color:\s*(.+)/i
        filters[:color] = $1.strip
      when /^Damage:\s*(.+)/i
        filters[:damage_type] = $1.strip
      when /^Production Year:\s*(\d+)/i
        filters[:production_year] = $1.strip.to_i
      end
    end
    
    filters
  end

  def format_price_response(response)
    text = "📊 <b>Price Analysis</b>\n\n"
    
    if response[:average_price]
      text += "Average Price: $#{format_number(response[:average_price])}\n"
      text += "Median Price: $#{format_number(response[:median_price])}\n" if response[:median_price]
      confidence = (response[:price_confidence] * 100).round if response[:price_confidence]
      text += "Confidence: #{confidence}%\n" if confidence
      text += "Based on #{response[:sample_size]} historical auctions\n" if response[:sample_size]
    else
      text += "No historical data available for this vehicle.\n"
    end
    
    text
  end

  def format_number(num)
    return 'N/A' unless num
    num.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  class API
    include HTTParty
    base_uri API_URL

    def initialize(base_url)
      self.class.base_uri base_url
    end

    def calculate_price(telegram_id:, username:, filters:)
      response = self.class.post(
        '/api/queries',
        body: {
          telegram_id: telegram_id,
          username: username,
          search_active_auctions: false,
          **filters
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      if response.success?
        { success: true, **response.parsed_response.symbolize_keys }
      else
        { success: false, error: response.parsed_response['errors']&.join(', ') || 'Unknown error' }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def search_active_auctions(telegram_chat_id:, telegram_id:, filters:)
      response = self.class.post(
        '/api/queries',
        body: {
          telegram_id: telegram_id,
          telegram_chat_id: telegram_chat_id,
          search_active_auctions: true,
          **filters
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      if response.success?
        { success: true, **response.parsed_response.symbolize_keys }
      else
        { success: false, error: response.parsed_response['errors']&.join(', ') || 'Unknown error' }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end
end

# Run the bot
if __FILE__ == $0
  bot = CarPriceBot.new
  bot.run
end
