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
      state_manager = Services::StateManager.new(@redis)
      state = state_manager.get_state(user_id)
      
      if state[:creating_vehicle_alert]
        handle_vehicle_alert_creation(chat_id, user_id, text, state)
      else
        send_message(chat_id, "Используйте кнопки меню для навигации.")
      end
    end

    def handle_vehicle_alert_creation(chat_id, user_id, text, state)
      state_manager = Services::StateManager.new(@redis)
      step = state[:vehicle_alert_step] || 'make'
      alert_data = state[:vehicle_alert_data] || {}
      
      case step
      when 'make'
        alert_data[:make] = text.strip.capitalize
        state_manager.update_state(user_id, {
          vehicle_alert_step: 'model',
          vehicle_alert_data: alert_data
        })
        send_message(chat_id, "Введите модель автомобиля (например: Camry):")
        
      when 'model'
        alert_data[:model] = text.strip.capitalize
        state_manager.update_state(user_id, {
          vehicle_alert_step: 'year',
          vehicle_alert_data: alert_data
        })
        send_message(chat_id, "Введите год выпуска (например: 2020) или отправьте 'пропустить':")
        
      when 'year'
        if text.downcase.strip == 'пропустить' || text.downcase.strip == 'skip'
          alert_data[:year] = nil
        else
          year = text.to_i
          if year >= 1900 && year <= Time.current.year + 1
            alert_data[:year] = year
          else
            send_message(chat_id, "❌ Неверный год. Введите год от 1900 до #{Time.current.year + 1} или 'пропустить':")
            return
          end
        end
        state_manager.update_state(user_id, {
          vehicle_alert_step: 'damage_type',
          vehicle_alert_data: alert_data
        })
        send_message(chat_id, "Введите уровень повреждений (None, Minor, Moderate, Severe, Total Loss, Salvage) или 'пропустить':")
        
      when 'damage_type'
        if text.downcase.strip == 'пропустить' || text.downcase.strip == 'skip'
          alert_data[:damage_type] = nil
        else
          damage_types = ['None', 'Minor', 'Moderate', 'Severe', 'Total Loss', 'Salvage']
          normalized = text.strip.capitalize
          if damage_types.include?(normalized)
            alert_data[:damage_type] = normalized
          else
            send_message(chat_id, "❌ Неверный тип повреждений. Выберите из: None, Minor, Moderate, Severe, Total Loss, Salvage или 'пропустить':")
            return
          end
        end
        state_manager.update_state(user_id, {
          vehicle_alert_step: 'mileage',
          vehicle_alert_data: alert_data
        })
        send_message(chat_id, "Введите минимальный пробег в милях (или 'пропустить'):")
        
      when 'mileage'
        if text.downcase.strip == 'пропустить' || text.downcase.strip == 'skip'
          alert_data[:mileage_min] = nil
          state_manager.update_state(user_id, {
            vehicle_alert_step: 'mileage_max',
            vehicle_alert_data: alert_data
          })
          send_message(chat_id, "Введите максимальный пробег в милях (или 'пропустить'):")
        else
          mileage = text.gsub(/[^\d]/, '').to_i
          if mileage > 0
            alert_data[:mileage_min] = mileage
            state_manager.update_state(user_id, {
              vehicle_alert_step: 'mileage_max',
              vehicle_alert_data: alert_data
            })
            send_message(chat_id, "Введите максимальный пробег в милях (или 'пропустить'):")
          else
            send_message(chat_id, "❌ Неверный пробег. Введите число или 'пропустить':")
            return
          end
        end
        
      when 'mileage_max'
        if text.downcase.strip == 'пропустить' || text.downcase.strip == 'skip'
          alert_data[:mileage_max] = nil
        else
          mileage = text.gsub(/[^\d]/, '').to_i
          if mileage > 0
            if alert_data[:mileage_min] && mileage < alert_data[:mileage_min]
              send_message(chat_id, "❌ Максимальный пробег должен быть больше минимального. Введите снова или 'пропустить':")
              return
            end
            alert_data[:mileage_max] = mileage
          else
            send_message(chat_id, "❌ Неверный пробег. Введите число или 'пропустить':")
            return
          end
        end
        
        # Create the alert
        create_vehicle_alert_from_data(chat_id, user_id, alert_data)
        
        # Clear state
        state_manager.update_state(user_id, {
          creating_vehicle_alert: false,
          vehicle_alert_step: nil,
          vehicle_alert_data: nil
        })
      end
    end

    def create_vehicle_alert_from_data(chat_id, user_id, alert_data)
      result = @api.create_vehicle_alert(user_id, alert_data)
      
      if result[:success]
        text = "✅ <b>Запрос создан!</b>\n\n"
        text += "🚗 <b>#{alert_data[:make]} #{alert_data[:model]}</b>\n"
        text += "📅 Год: #{alert_data[:year]}\n" if alert_data[:year]
        text += "💥 Повреждения: #{alert_data[:damage_type]}\n" if alert_data[:damage_type]
        if alert_data[:mileage_min] || alert_data[:mileage_max]
          mileage_text = []
          mileage_text << "от #{alert_data[:mileage_min]}" if alert_data[:mileage_min]
          mileage_text << "до #{alert_data[:mileage_max]}" if alert_data[:mileage_max]
          text += "🛣 Пробег: #{mileage_text.join(' - ')} миль\n"
        end
        text += "\nМы уведомим вас, когда появится подходящий автомобиль.\n"
        text += "Срок действия запроса: 1 неделя"
        
        keyboard = Components::Menu.back_to_menu_button
        send_message(chat_id, text, keyboard, parse_mode: 'HTML')
      else
        error_msg = result[:error].is_a?(Array) ? result[:error].join(', ') : result[:error]
        send_message(chat_id, "❌ Ошибка при создании запроса: #{error_msg}")
      end
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

