require_relative '../components/menu'
require_relative '../services/state_manager'
require 'telegram/bot/types'
require 'json'
require 'uri'

module Handlers
  class MiniAppHandler
    def initialize(bot, api, redis)
      @bot = bot
      @api = api
      @redis = redis
    end

    def handle_web_app_data(message)
      return unless message.web_app_data

      user_id = message.from.id
      chat_id = message.chat.id
      data = JSON.parse(message.web_app_data.data) rescue {}

      case data['type']
      when 'search_complete'
        handle_search_complete(chat_id, user_id, data)
      when 'payment_complete'
        handle_payment_complete(chat_id, user_id, data)
      when 'vehicle_selected'
        handle_vehicle_selected(chat_id, user_id, data)
      else
        handle_unknown_web_app_data(chat_id, data)
      end
    end

    private

    def handle_search_complete(chat_id, user_id, data)
      filters = data['filters'] || {}
      vehicles = data['vehicles'] || []
      
      if vehicles.empty?
        send_message(chat_id, "❌ По вашему запросу ничего не найдено.")
        return
      end

      text = "✅ Найдено лотов: #{vehicles.size}\n\n" \
             "Используйте Mini App для просмотра деталей и оплаты."
      
      keyboard = [
        [
          { text: "👁️ Посмотреть результаты", web_app: { url: build_results_url(user_id, filters) } }
        ],
        Components::Menu.back_to_menu_button.first
      ]

      send_message(chat_id, text, keyboard)
    end

    def handle_payment_complete(chat_id, user_id, data)
      payment_type = data['payment_type']
      amount = data['amount']
      transaction_id = data['transaction_id']

      case payment_type
      when 'premium'
        state_manager = Services::StateManager.new(@redis)
        state_manager.update_state(user_id, { premium_active: true })
        send_message(chat_id, "✅ Премиум подписка активирована!")
      when 'single_search'
        state_manager = Services::StateManager.new(@redis)
        state = state_manager.get_state(user_id)
        credits = (state[:search_credits] || 0) + 1
        state_manager.update_state(user_id, { search_credits: credits })
        send_message(chat_id, "✅ Поиск оплачен! У вас #{credits} доступных поисков.")
      end
    end

    def handle_vehicle_selected(chat_id, user_id, data)
      source = data['source']
      stock_number = data['stock_number']
      
      response = @api.get_vehicle(source, stock_number)
      
      if response[:success]
        vehicle = response[:vehicle]
        text = format_vehicle_details(vehicle)
        
        keyboard = [
          [
            { text: "💰 Оплатить", web_app: { url: build_payment_url(user_id, vehicle) } },
            { text: "🔗 Открыть аукцион", url: vehicle[:auction_url] }
          ],
          Components::Menu.back_to_menu_button.first
        ]
        
        send_message(chat_id, text, keyboard, parse_mode: 'HTML')
      else
        send_message(chat_id, "❌ Не удалось загрузить информацию о лоте.")
      end
    end

    def handle_unknown_web_app_data(chat_id, data)
      puts "⚠️ Unknown web app data type: #{data['type']}"
      send_message(chat_id, "Неизвестный тип данных от Mini App.")
    end

    def format_vehicle_details(vehicle)
      text = "🚗 <b>#{vehicle[:make]} #{vehicle[:model]} #{vehicle[:year]}</b>\n\n"
      text += "📅 Год: #{vehicle[:year]}\n" if vehicle[:year]
      text += "🛣 Пробег: #{format_number(vehicle[:mileage])} миль\n" if vehicle[:mileage]
      text += "🎨 Цвет: #{vehicle[:color]}\n" if vehicle[:color]
      text += "💥 Повреждения: #{vehicle[:damage_type]}\n" if vehicle[:damage_type]
      text += "📍 Локация: #{vehicle[:location]}\n" if vehicle[:location]
      text += "💰 Цена: $#{format_number(vehicle[:price])}\n" if vehicle[:price]
      text += "🏷️ Статус: #{vehicle[:auction_status]}\n" if vehicle[:auction_status]
      text
    end

    def build_results_url(user_id, filters)
      base_url = ENV.fetch('MINI_APP_URL', 'https://your-domain.com/mini-app')
      "#{base_url}/results?user_id=#{user_id}&filters=#{URI.encode_www_form_component(filters.to_json)}"
    end

    def build_payment_url(user_id, vehicle)
      base_url = ENV.fetch('MINI_APP_URL', 'https://your-domain.com/mini-app')
      "#{base_url}/payment?user_id=#{user_id}&vehicle_id=#{vehicle[:id]}"
    end

    def format_number(num)
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
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

