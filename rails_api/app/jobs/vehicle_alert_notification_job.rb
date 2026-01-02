class VehicleAlertNotificationJob < ApplicationJob
  queue_as :default

  def perform(alert_id, vehicle_id)
    alert = VehicleAlert.find_by(id: alert_id)
    vehicle = Vehicle.find_by(id: vehicle_id)
    
    return unless alert && vehicle && alert.active? && !alert.expired?
    return unless alert.matches_vehicle?(vehicle)
    
    user = alert.user
    
    # Format notification message
    message = format_notification_message(vehicle, alert)
    
    # Send via Telegram bot API
    send_telegram_notification(user.telegram_id, message, vehicle)
    
    # Mark as notified
    alert.mark_vehicle_notified!(vehicle.id)
  rescue => e
    Rails.logger.error("Error sending vehicle alert notification: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end

  private

  def format_notification_message(vehicle, alert)
    text = "🔔 <b>Найдено подходящее авто!</b>\n\n"
    text += "🚗 <b>#{vehicle.make} #{vehicle.model} #{vehicle.year}</b>\n"
    text += "📅 Год: #{vehicle.year}\n" if vehicle.year
    text += "🛣 Пробег: #{format_number(vehicle.mileage)} миль\n" if vehicle.mileage
    text += "💥 Повреждения: #{vehicle.damage_type}\n" if vehicle.damage_type
    text += "📍 Локация: #{vehicle.location}\n" if vehicle.location
    text += "💰 Цена: $#{format_number(vehicle.price)}\n" if vehicle.price
    text += "📊 Статус: #{vehicle.auction_status}\n" if vehicle.auction_status
    text += "\n<a href=\"#{vehicle.auction_url}\">Посмотреть на аукционе</a>" if vehicle.auction_url
    
    text
  end

  def format_number(num)
    return '0' if num.nil?
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def send_telegram_notification(telegram_id, message, vehicle)
    bot_token = ENV['TELEGRAM_BOT_TOKEN']
    return unless bot_token
    
    require 'net/http'
    require 'uri'
    require 'json'
    
    base_url = ENV.fetch('TELEGRAM_BOT_API_URL', 'https://api.telegram.org')
    url = URI("#{base_url}/bot#{bot_token}/sendMessage")
    
    keyboard = build_keyboard(vehicle)
    
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
      Rails.logger.error("Failed to send Telegram notification: #{response.code} - #{response.body}")
    end
  rescue => e
    Rails.logger.error("Error sending Telegram notification: #{e.message}")
  end

  def build_keyboard(vehicle)
    mini_app_url = ENV.fetch('MINI_APP_URL', '')
    vehicle_url = "#{mini_app_url}/vehicle/#{vehicle.source}/#{vehicle.stock_number}" if vehicle.stock_number
    
    inline_keyboard = []
    
    if vehicle_url
      inline_keyboard << [
        {
          text: "👁️ Посмотреть",
          web_app: { url: vehicle_url }
        }
      ]
    end
    
    inline_keyboard << [
      {
        text: "🔕 Управление уведомлениями",
        callback_data: "vehicle_alerts:manage"
      }
    ]
    
    { inline_keyboard: inline_keyboard }
  end
end

