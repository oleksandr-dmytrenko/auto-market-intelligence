require_relative 'state_manager'
require 'telegram/bot/types'

module Services
  class NotificationService
    def initialize(bot, redis)
      @bot = bot
      @redis = redis
    end

    def send_notification(chat_id, vehicle_data, filters)
      state_manager = Services::StateManager.new(@redis)
      user_id = get_user_id_from_chat(chat_id)
      state = state_manager.get_state(user_id)

      return unless state[:notifications_enabled]

      text = format_vehicle_notification(vehicle_data, filters)
      
      keyboard = [
        [
          { text: "👁️ Посмотреть", web_app: { url: build_vehicle_url(vehicle_data) } },
          { text: "🔕 Отключить уведомления", callback_data: "notifications:disable" }
        ]
      ]

      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    rescue => e
      puts "❌ Error sending notification: #{e.message}"
    end

    def send_batch_notifications(chat_id, vehicles, filters)
      vehicles.each do |vehicle_data|
        send_notification(chat_id, vehicle_data, filters)
        sleep(0.5) # Небольшая задержка между уведомлениями
      end
    end

    private

    def format_vehicle_notification(vehicle_data, filters)
      text = "🔔 <b>Новый лот найден!</b>\n\n"
      text += "🚗 <b>#{vehicle_data[:make]} #{vehicle_data[:model]} #{vehicle_data[:year]}</b>\n"
      text += "📅 Год: #{vehicle_data[:year]}\n" if vehicle_data[:year]
      text += "🛣 Пробег: #{format_number(vehicle_data[:mileage])} миль\n" if vehicle_data[:mileage]
      text += "🎨 Цвет: #{vehicle_data[:color]}\n" if vehicle_data[:color]
      text += "💥 Повреждения: #{vehicle_data[:damage_type]}\n" if vehicle_data[:damage_type]
      text += "📍 Локация: #{vehicle_data[:location]}\n" if vehicle_data[:location]
      text += "💰 Цена: $#{format_number(vehicle_data[:price])}\n" if vehicle_data[:price]
      text += "\n<a href=\"#{vehicle_data[:auction_url]}\">Посмотреть на аукционе</a>" if vehicle_data[:auction_url]
      text
    end

    def build_vehicle_url(vehicle_data)
      base_url = ENV.fetch('MINI_APP_URL', 'https://your-domain.com/mini-app')
      "#{base_url}/vehicle/#{vehicle_data[:source]}/#{vehicle_data[:stock_number]}"
    end

    def format_number(num)
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def get_user_id_from_chat(chat_id)
      chat_id
    end

    def send_message(chat_id, text, keyboard = [], **options)
      reply_markup = build_keyboard(keyboard) if keyboard.any?
      
      @bot.api.send_message(
        chat_id: chat_id,
        text: text,
        reply_markup: reply_markup,
        **options
      )
    rescue => e
      puts "❌ Error sending message: #{e.message}"
    end

    def build_keyboard(keyboard_rows)
      kb_objects = keyboard_rows.map do |row|
        row.map do |btn_hash|
          Telegram::Bot::Types::InlineKeyboardButton.new(**btn_hash)
        end
      end
      Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb_objects)
    end
  end
end

