require_relative '../components/menu'
require_relative '../services/state_manager'
require 'telegram/bot/types'

module Handlers
  class MessageHandler
    def initialize(bot, api, redis)
      @bot = bot
      @api = api
      @redis = redis
    end

    def handle(message)
      return unless message.text

      user_id = message.from.id
      chat_id = message.chat.id
      text = message.text.to_s.strip

      case text
      when '/start', '/menu'
        show_main_menu(chat_id, user_id)
      when '/help'
        show_help(chat_id)
      else
        handle_text_message(chat_id, user_id, text)
      end
    end

    private

    def show_main_menu(chat_id, user_id)
      state_manager = Services::StateManager.new(@redis)
      state_manager.clear_state(user_id)
      state_manager.update_state(user_id, { chat_id: chat_id })

      text = "🚗 <b>Добро пожаловать в Auto Market Intelligence!</b>\n\n" \
             "Выберите действие:"
      
      keyboard = Components::Menu.main_menu
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

    def handle_text_message(chat_id, user_id, text)
      send_message(chat_id, "Используйте кнопки меню для навигации.")
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

