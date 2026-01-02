require 'telegram/bot/types'

module Components
  class Menu
    def self.main_menu
      [
        [
          { text: "🔍 Подобрать авто", web_app: { url: web_app_url } },
          { text: "🔔 Уведомления", callback_data: "notifications" }
        ],
        [
          { text: "💳 Оплата", callback_data: "payments" },
          { text: "ℹ️ Помощь", callback_data: "help" }
        ]
      ]
    end

    def self.notifications_menu
      [
        [
          { text: "✅ Включить уведомления", callback_data: "notifications:enable" },
          { text: "❌ Выключить уведомления", callback_data: "notifications:disable" }
        ],
        [
          { text: "⚙️ Настройки", callback_data: "notifications:settings" },
          { text: "⬅️ Назад", callback_data: "main_menu" }
        ]
      ]
    end

    def self.payments_menu
      [
        [
          { text: "💎 Премиум подписка", callback_data: "payments:premium" },
          { text: "🔍 Разовый поиск", callback_data: "payments:single_search" }
        ],
        [
          { text: "📊 История платежей", callback_data: "payments:history" },
          { text: "⬅️ Назад", callback_data: "main_menu" }
        ]
      ]
    end

    def self.back_to_menu_button
      [[{ text: "🏠 Главное меню", callback_data: "main_menu" }]]
    end

    private

    def self.web_app_url
      ENV.fetch('MINI_APP_URL', 'https://your-domain.com/mini-app')
    end
  end
end



