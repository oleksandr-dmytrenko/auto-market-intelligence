class VehicleAlertExpiredNotificationJob < ApplicationJob
  queue_as :default

  def perform(alert_id)
    alert = VehicleAlert.find_by(id: alert_id)
    return unless alert
    
    user = alert.user
    
    # Format expiration message
    message = format_expiration_message(alert)
    
    # Send via Telegram bot API
    send_telegram_notification(user.telegram_id, message, alert)
  rescue => e
    Rails.logger.error("Error sending vehicle alert expiration notification: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end

  private

  def format_expiration_message(alert)
    text = "⏰ <b>Срок поиска истек</b>\n\n"
    text += "Ваш запрос на поиск автомобиля истек:\n"
    text += "🚗 <b>#{alert.make} #{alert.model}</b>\n"
    if alert.year_from || alert.year_to
      if alert.year_from && alert.year_to
        text += "📅 Год: #{alert.year_from}-#{alert.year_to}\n"
      elsif alert.year_from
        text += "📅 Год: от #{alert.year_from}\n"
      elsif alert.year_to
        text += "📅 Год: до #{alert.year_to}\n"
      end
    end
    text += "💥 Повреждения: #{alert.damage_type}\n" if alert.damage_type
    text += "🛣 Пробег: #{format_mileage_range(alert)}\n" if alert.mileage_min || alert.mileage_max
    text += "\nХотите создать новый запрос?"
  end

  def format_mileage_range(alert)
    if alert.mileage_min && alert.mileage_max
      "#{format_number(alert.mileage_min)} - #{format_number(alert.mileage_max)} миль"
    elsif alert.mileage_min
      "от #{format_number(alert.mileage_min)} миль"
    elsif alert.mileage_max
      "до #{format_number(alert.mileage_max)} миль"
    end
  end

  def format_number(num)
    return '0' if num.nil?
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def send_telegram_notification(telegram_id, message, alert)
    bot_token = ENV['TELEGRAM_BOT_TOKEN']
    return unless bot_token
    
    require 'net/http'
    require 'uri'
    require 'json'
    
    base_url = ENV.fetch('TELEGRAM_BOT_API_URL', 'https://api.telegram.org')
    url = URI("#{base_url}/bot#{bot_token}/sendMessage")
    
    keyboard = build_keyboard(alert)
    
    payload = {
      chat_id: telegram_id,
      text: message,
      parse_mode: 'HTML',
      reply_markup: keyboard
    }
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(url.path)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("Failed to send Telegram expiration notification: #{response.code} - #{response.body}")
    end
  rescue => e
    Rails.logger.error("Error sending Telegram expiration notification: #{e.message}")
  end

  def build_keyboard(alert)
    inline_keyboard = [
      [
        {
          text: "✅ Создать новый запрос",
          callback_data: "vehicle_alerts:create_new"
        }
      ],
      [
        {
          text: "📋 Мои запросы",
          callback_data: "vehicle_alerts:list"
        }
      ]
    ]
    
    { inline_keyboard: inline_keyboard }
  end
end

