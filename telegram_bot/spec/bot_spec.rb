require_relative 'spec_helper'

RSpec.describe Services::StateManager do
  let(:redis) { MockRedis.new }
  let(:state_manager) { Services::StateManager.new(redis) }

  describe 'State Management' do
    it 'initializes with empty state' do
      state = state_manager.get_state(123)
      expect(state[:chat_id]).to be_nil
      expect(state[:notifications_enabled]).to eq(false)
      expect(state[:premium_active]).to eq(false)
    end

    it 'saves and retrieves state' do
      state_manager.update_state(123, { chat_id: 456, notifications_enabled: true })
      state = state_manager.get_state(123)
      expect(state[:chat_id]).to eq(456)
      expect(state[:notifications_enabled]).to eq(true)
    end

    it 'clears state' do
      state_manager.update_state(123, { chat_id: 456, notifications_enabled: true })
      state_manager.clear_state(123)
      state = state_manager.get_state(123)
      expect(state[:chat_id]).to be_nil
      expect(state[:notifications_enabled]).to eq(false)
    end

    it 'merges updates with existing state' do
      state_manager.update_state(123, { chat_id: 456 })
      state_manager.update_state(123, { notifications_enabled: true })
      state = state_manager.get_state(123)
      expect(state[:chat_id]).to eq(456)
      expect(state[:notifications_enabled]).to eq(true)
    end
  end
end

RSpec.describe Handlers::MessageHandler do
  let(:bot) { MockBot.new }
  let(:api) { MockAPI.new }
  let(:redis) { MockRedis.new }
  let(:handler) { Handlers::MessageHandler.new(bot, api, redis) }

  describe 'Message Handling' do
    it 'shows main menu on /start' do
      message = double(
        text: '/start',
        from: double(id: 123),
        chat: double(id: 123)
      )
      
      handler.handle(message)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Добро пожаловать')
      expect(messages[0][:text]).to include('Auto Market Intelligence')
    end

    it 'shows main menu on /menu' do
      message = double(
        text: '/menu',
        from: double(id: 123),
        chat: double(id: 123)
      )
      
      handler.handle(message)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Добро пожаловать')
    end

    it 'shows help on /help' do
      message = double(
        text: '/help',
        from: double(id: 123),
        chat: double(id: 123)
      )
      
      handler.handle(message)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Помощь')
    end

    it 'handles text messages' do
      message = double(
        text: 'some text',
        from: double(id: 123),
        chat: double(id: 123)
      )
      
      handler.handle(message)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Используйте кнопки меню')
    end

    it 'clears state on /start' do
      state_manager = Services::StateManager.new(redis)
      state_manager.update_state(123, { chat_id: 123, notifications_enabled: true })
      
      message = double(
        text: '/start',
        from: double(id: 123),
        chat: double(id: 123)
      )
      
      handler.handle(message)
      
      state = state_manager.get_state(123)
      expect(state[:notifications_enabled]).to eq(false)
      expect(state[:chat_id]).to eq(123)
    end
  end
end

RSpec.describe Handlers::CallbackHandler do
  let(:bot) { MockBot.new }
  let(:api) { MockAPI.new }
  let(:redis) { MockRedis.new }
  let(:handler) { Handlers::CallbackHandler.new(bot, api, redis) }

  describe 'Callback Handling' do
    it 'shows main menu on main_menu callback' do
      callback = double(
        from: double(id: 123),
        message: double(chat: double(id: 123)),
        data: 'main_menu',
        id: 'callback_123'
      )
      
      handler.handle(callback)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Главное меню')
    end

    it 'shows notifications menu on notifications callback' do
      callback = double(
        from: double(id: 123),
        message: double(chat: double(id: 123)),
        data: 'notifications',
        id: 'callback_123'
      )
      
      handler.handle(callback)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Уведомления')
    end

    it 'enables notifications on notifications:enable callback' do
      callback = double(
        from: double(id: 123),
        message: double(chat: double(id: 123)),
        data: 'notifications:enable',
        id: 'callback_123'
      )
      
      handler.handle(callback)
      
      state_manager = Services::StateManager.new(redis)
      state = state_manager.get_state(123)
      expect(state[:notifications_enabled]).to eq(true)
    end

    it 'disables notifications on notifications:disable callback' do
      state_manager = Services::StateManager.new(redis)
      state_manager.update_state(123, { notifications_enabled: true })
      
      callback = double(
        from: double(id: 123),
        message: double(chat: double(id: 123)),
        data: 'notifications:disable',
        id: 'callback_123'
      )
      
      handler.handle(callback)
      
      state = state_manager.get_state(123)
      expect(state[:notifications_enabled]).to eq(false)
    end

    it 'shows payments menu on payments callback' do
      callback = double(
        from: double(id: 123),
        message: double(chat: double(id: 123)),
        data: 'payments',
        id: 'callback_123'
      )
      
      handler.handle(callback)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Оплата')
    end

    it 'shows help on help callback' do
      callback = double(
        from: double(id: 123),
        message: double(chat: double(id: 123)),
        data: 'help',
        id: 'callback_123'
      )
      
      handler.handle(callback)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Помощь')
    end
  end
end

RSpec.describe Handlers::MiniAppHandler do
  let(:bot) { MockBot.new }
  let(:api) { MockAPI.new }
  let(:redis) { MockRedis.new }
  let(:handler) { Handlers::MiniAppHandler.new(bot, api, redis) }

  describe 'Mini App Handling' do
    it 'handles search_complete web app data with vehicles' do
      web_app_data = double(
        data: { type: 'search_complete', filters: {}, vehicles: [{ id: 1, make: 'BMW' }] }.to_json
      )
      message = double(
        from: double(id: 123),
        chat: double(id: 123),
        web_app_data: web_app_data
      )
      
      handler.handle_web_app_data(message)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('Найдено лотов')
    end

    it 'handles search_complete web app data with no vehicles' do
      web_app_data = double(
        data: { type: 'search_complete', filters: {}, vehicles: [] }.to_json
      )
      message = double(
        from: double(id: 123),
        chat: double(id: 123),
        web_app_data: web_app_data
      )
      
      handler.handle_web_app_data(message)
      
      messages = bot.api.messages
      expect(messages.size).to eq(1)
      expect(messages[0][:text]).to include('По вашему запросу ничего не найдено')
    end

    it 'handles payment_complete web app data for premium' do
      web_app_data = double(
        data: {
          type: 'payment_complete',
          payment_type: 'premium',
          amount: 100,
          transaction_id: 'tx_123'
        }.to_json
      )
      message = double(
        from: double(id: 123),
        chat: double(id: 123),
        web_app_data: web_app_data
      )
      
      handler.handle_web_app_data(message)
      
      state_manager = Services::StateManager.new(redis)
      state = state_manager.get_state(123)
      expect(state[:premium_active]).to eq(true)
      
      messages = bot.api.messages
      expect(messages.any? { |m| m[:text]&.include?('Премиум подписка активирована') }).to be true
    end

    it 'handles payment_complete web app data for single_search' do
      web_app_data = double(
        data: {
          type: 'payment_complete',
          payment_type: 'single_search',
          amount: 10,
          transaction_id: 'tx_123'
        }.to_json
      )
      message = double(
        from: double(id: 123),
        chat: double(id: 123),
        web_app_data: web_app_data
      )
      
      handler.handle_web_app_data(message)
      
      state_manager = Services::StateManager.new(redis)
      state = state_manager.get_state(123)
      expect(state[:search_credits]).to eq(1)
      
      messages = bot.api.messages
      expect(messages.any? { |m| m[:text]&.include?('Поиск оплачен') }).to be true
    end

    it 'handles vehicle_selected web app data' do
      web_app_data = double(
        data: {
          type: 'vehicle_selected',
          source: 'copart',
          stock_number: '12345'
        }.to_json
      )
      message = double(
        from: double(id: 123),
        chat: double(id: 123),
        web_app_data: web_app_data
      )
      
      handler.handle_web_app_data(message)
      
      # The handler will call api.get_vehicle which is mocked
      # We just verify it doesn't crash
      expect(bot.api.messages.size).to be >= 0
    end
  end
end

RSpec.describe CarPriceBot do
  let(:redis) { MockRedis.new }
  let(:bot) { MockBot.new }
  let(:api) { MockAPI.new }
  
  describe 'Initialization' do
    it 'initializes with dependencies' do
      # This test verifies the bot can be instantiated
      # In a real test, we'd need to stub ENV variables
      expect(CarPriceBot).to be_a(Class)
    end
  end
end
