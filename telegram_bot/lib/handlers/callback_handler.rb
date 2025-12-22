require_relative '../components/menu'
require_relative '../services/state_manager'
require 'telegram/bot/types'
require 'digest'

module Handlers
  class CallbackHandler
    def initialize(bot, api, redis)
      @bot = bot
      @api = api
      @redis = redis
    end

    def handle(callback)
      user_id = callback.from.id
      chat_id = callback.message.chat.id
      data = callback.data

      unless data.start_with?('payments:') && data.include?('process')
        @bot.api.answer_callback_query(callback_query_id: callback.id)
      end

      case data
      when 'main_menu'
        show_main_menu(chat_id, user_id)
      when 'notifications'
        show_notifications_menu(chat_id)
      when /^notifications:(.+)$/
        handle_notification_action(chat_id, user_id, $1, callback.id)
      when 'payments'
        show_payments_menu(chat_id)
      when /^payments:(.+)$/
        handle_payment_action(chat_id, user_id, $1, callback.id)
      when 'help'
        show_help(chat_id)
      else
        handle_unknown_callback(chat_id, data)
      end
    end

    private

    def show_main_menu(chat_id, user_id)
      state_manager = Services::StateManager.new(@redis)
      state_manager.clear_state(user_id)
      state_manager.update_state(user_id, { chat_id: chat_id })

      text = "🚗 <b>Главное меню</b>\n\nВыберите действие:"
      keyboard = Components::Menu.main_menu
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def show_notifications_menu(chat_id)
      state_manager = Services::StateManager.new(@redis)
      user_id = get_user_id_from_chat(chat_id)
      state = state_manager.get_state(user_id)
      
      enabled = state[:notifications_enabled] || false
      status_text = enabled ? "✅ Включены" : "❌ Выключены"
      
      text = "🔔 <b>Уведомления</b>\n\n" \
             "Текущий статус: #{status_text}\n\n" \
             "Вы будете получать уведомления о новых лотах, соответствующих вашим поисковым запросам."
      
      keyboard = Components::Menu.notifications_menu
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def handle_notification_action(chat_id, user_id, action, callback_id)
      state_manager = Services::StateManager.new(@redis)
      
      case action
      when 'enable'
        state_manager.update_state(user_id, { notifications_enabled: true })
        @bot.api.answer_callback_query(
          callback_query_id: callback_id,
          text: "✅ Уведомления включены"
        )
        show_notifications_menu(chat_id)
      when 'disable'
        state_manager.update_state(user_id, { notifications_enabled: false })
        @bot.api.answer_callback_query(
          callback_query_id: callback_id,
          text: "❌ Уведомления выключены"
        )
        show_notifications_menu(chat_id)
      when 'settings'
        show_notification_settings(chat_id, user_id)
      end
    end

    def show_notification_settings(chat_id, user_id)
      text = "⚙️ <b>Настройки уведомлений</b>\n\n" \
             "Здесь можно настроить частоту и типы уведомлений.\n\n" \
             "Функция в разработке..."
      
      keyboard = Components::Menu.back_to_menu_button
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def show_payments_menu(chat_id)
      text = "💳 <b>Оплата</b>\n\n" \
             "Выберите тип услуги:\n\n" \
             "💎 <b>Премиум подписка</b> - неограниченные поиски\n" \
             "🔍 <b>Разовый поиск</b> - одноразовый поиск по параметрам"
      
      keyboard = Components::Menu.payments_menu
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def handle_payment_action(chat_id, user_id, action, callback_id)
      case action
      when 'premium'
        initiate_premium_payment(chat_id, user_id, callback_id)
      when 'single_search'
        initiate_single_search_payment(chat_id, user_id, callback_id)
      when 'history'
        show_payment_history(chat_id, user_id)
      when 'process_premium'
        process_premium_payment(chat_id, user_id, callback_id)
      when 'process_single'
        process_single_search_payment(chat_id, user_id, callback_id)
      end
    end

    def initiate_premium_payment(chat_id, user_id, callback_id)
      web_app_url = build_mini_app_url('premium', user_id)
      
      keyboard = [
        [
          { text: "💎 Оплатить премиум", web_app: { url: web_app_url } }
        ],
        Components::Menu.back_to_menu_button.first
      ]
      
      text = "💎 <b>Премиум подписка</b>\n\n" \
             "Неограниченные поиски и приоритетная поддержка.\n\n" \
             "Нажмите кнопку ниже для оплаты:"
      
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def initiate_single_search_payment(chat_id, user_id, callback_id)
      web_app_url = build_mini_app_url('single_search', user_id)
      
      keyboard = [
        [
          { text: "🔍 Оплатить поиск", web_app: { url: web_app_url } }
        ],
        Components::Menu.back_to_menu_button.first
      ]
      
      text = "🔍 <b>Разовый поиск</b>\n\n" \
             "Одноразовый поиск по вашим параметрам.\n\n" \
             "Нажмите кнопку ниже для оплаты:"
      
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def process_premium_payment(chat_id, user_id, callback_id)
      @bot.api.answer_callback_query(
        callback_query_id: callback_id,
        text: "Обработка платежа..."
      )
      
      send_message(chat_id, "✅ Премиум подписка активирована!")
    end

    def process_single_search_payment(chat_id, user_id, callback_id)
      @bot.api.answer_callback_query(
        callback_query_id: callback_id,
        text: "Обработка платежа..."
      )
      
      send_message(chat_id, "✅ Поиск оплачен! Используйте кнопку 'Подобрать авто' для начала поиска.")
    end

    def show_payment_history(chat_id, user_id)
      text = "📊 <b>История платежей</b>\n\n" \
             "Функция в разработке..."
      
      keyboard = Components::Menu.back_to_menu_button
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def show_help(chat_id)
      text = "ℹ️ <b>Помощь</b>\n\n" \
             "🔍 <b>Подобрать авто</b> - найдите автомобиль по параметрам\n" \
             "🔔 <b>Уведомления</b> - управление уведомлениями о новых лотах\n" \
             "💳 <b>Оплата</b> - покупка подписок и разовых поисков\n\n" \
             "Используйте кнопки меню для навигации."
      
      keyboard = Components::Menu.back_to_menu_button
      send_message(chat_id, text, keyboard, parse_mode: 'HTML')
    end

    def handle_unknown_callback(chat_id, data)
      puts "⚠️ Unknown callback data: #{data}"
      send_message(chat_id, "Неизвестная команда. Используйте меню.")
    end

    def build_mini_app_url(type, user_id)
      base_url = ENV.fetch('MINI_APP_URL', 'https://your-domain.com/mini-app')
      "#{base_url}?type=#{type}&user_id=#{user_id}&auth=#{generate_auth_token(user_id)}"
    end

    def generate_auth_token(user_id)
      require 'digest'
      Digest::SHA256.hexdigest("#{user_id}#{ENV.fetch('TELEGRAM_BOT_TOKEN', '')}")
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

