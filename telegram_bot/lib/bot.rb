require 'telegram/bot'
require 'dotenv/load'
require 'redis'
require 'json'
require 'uri'

require_relative 'components/menu'
require_relative 'handlers/message_handler'
require_relative 'handlers/callback_handler'
require_relative 'handlers/mini_app_handler'
require_relative 'services/state_manager'
require_relative 'services/notification_service'
require_relative 'services/api_client'

class CarPriceBot
  API_URL = ENV.fetch('RAILS_API_URL', 'http://rails_api:3000')
  REDIS_URL = ENV.fetch('REDIS_URL', 'redis://redis:6379/0')

  def initialize
    @token = ENV.fetch('TELEGRAM_BOT_TOKEN')
    @api = Services::ApiClient.new(API_URL)
    @redis = Redis.new(url: REDIS_URL)
    
    @message_handler = Handlers::MessageHandler.new(nil, @api, @redis)
    @callback_handler = Handlers::CallbackHandler.new(nil, @api, @redis)
    @mini_app_handler = Handlers::MiniAppHandler.new(nil, @api, @redis)
  end

  def run
    puts "🚀 Starting Telegram bot..."
    puts "📍 Rails API: #{API_URL}"
    puts "📍 Redis: #{REDIS_URL}"
    puts "📍 Mini App URL: #{ENV.fetch('MINI_APP_URL', 'Not configured')}"
    
    begin
      Telegram::Bot::Client.run(@token) do |bot|
        puts "✅ Bot connected successfully!"
        
        @message_handler.instance_variable_set(:@bot, bot)
        @callback_handler.instance_variable_set(:@bot, bot)
        @mini_app_handler.instance_variable_set(:@bot, bot)
        
        bot.listen do |update|
          begin
            case update
            when Telegram::Bot::Types::CallbackQuery
              puts "📥 Received CallbackQuery: #{update.data} from user #{update.from.id}"
              @callback_handler.handle(update)
            when Telegram::Bot::Types::Message
              puts "📥 Received Message: #{update.text&.slice(0, 50)} from user #{update.from.id}, chat #{update.chat.id}"
              
              if update.web_app_data
                @mini_app_handler.handle_web_app_data(update)
              else
                @message_handler.handle(update)
              end
            else
              puts "📥 Received unknown update type: #{update.class}"
            end
          rescue => e
            puts "⚠️ Error processing update: #{e.class}: #{e.message}"
            puts e.backtrace.join("\n").slice(0, 500)
          end
        end
      end
    rescue => e
      puts "🔥 Fatal error in bot: #{e.class}: #{e.message}"
      sleep 5
      retry
    end
  end
end

if __FILE__ == $0
  bot = CarPriceBot.new
  bot.run
end
