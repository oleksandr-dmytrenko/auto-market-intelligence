module Api
  class PaymentsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:callback]
    before_action :find_or_create_user, only: [:create]
    before_action :find_payment, only: [:show, :result, :callback]

    # POST /api/payments
    def create
      payment_type = params[:payment_type]
      amount = params[:amount]&.to_f

      unless %w[premium single_search].include?(payment_type)
        return render json: { error: 'Invalid payment type' }, status: :bad_request
      end

      unless amount && amount > 0
        return render json: { error: 'Invalid amount' }, status: :bad_request
      end

      # Set default amounts if not provided
      amount ||= payment_type == 'premium' ? 29.99 : 4.99
      currency = params[:currency] || 'USD'

      payment = @user.payments.create!(
        payment_type: payment_type,
        amount: amount,
        currency: currency,
        status: 'pending',
        description: payment_description(payment_type, amount)
      )

      begin
        payment_data = LiqpayService.create_payment(payment)
        
        render json: {
          payment_id: payment.id,
          checkout_url: payment_data[:url],
          data: payment_data[:data],
          signature: payment_data[:signature]
        }, status: :created
      rescue => e
        Rails.logger.error("Error creating LiqPay payment: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        payment.update!(status: 'failed')
        render json: { error: 'Failed to create payment' }, status: :internal_server_error
      end
    end

    # GET /api/payments/:id
    def show
      render json: {
        id: @payment.id,
        payment_type: @payment.payment_type,
        amount: @payment.amount,
        currency: @payment.currency,
        status: @payment.status,
        created_at: @payment.created_at
      }, status: :ok
    end

    # GET /api/payments/:id/result
    # This is where LiqPay redirects the user after payment
    def result
      if @payment.success?
        case @payment.payment_type
        when 'premium'
          message = 'Premium subscription activated successfully!'
        when 'single_search'
          message = 'Search credit added successfully!'
        else
          message = 'Payment successful!'
        end
        render json: { status: 'success', message: message, payment: payment_json(@payment) }
      else
        render json: { status: @payment.status, message: 'Payment not completed', payment: payment_json(@payment) }
      end
    end

    # POST /api/payments/:id/callback
    # This is the server-to-server callback from LiqPay
    def callback
      data = params[:data]
      signature = params[:signature]

      unless LiqpayService.verify_callback(data, signature)
        Rails.logger.error("Invalid LiqPay callback signature for payment #{@payment.id}")
        return render json: { error: 'Invalid signature' }, status: :unauthorized
      end

      callback_data = LiqpayService.parse_callback_data(data)
      unless callback_data
        return render json: { error: 'Invalid callback data' }, status: :bad_request
      end

      @payment.update!(
        liqpay_transaction_id: callback_data['transaction_id'],
        liqpay_response: callback_data,
        status: map_liqpay_status(callback_data['status']),
        paid_at: callback_data['end_date'] ? Time.parse(callback_data['end_date']) : Time.current
      )

      if @payment.success?
        process_successful_payment
      end

      render json: { status: 'ok' }, status: :ok
    end

    # GET /api/payments/history
    def history
      telegram_id = params[:telegram_id] || request.headers['X-Telegram-User-Id']
      
      unless telegram_id
        return render json: { error: 'Telegram ID is required' }, status: :bad_request
      end

      user = User.find_by(telegram_id: telegram_id)
      unless user
        return render json: { payments: [] }, status: :ok
      end

      payments = user.payments.order(created_at: :desc).limit(50)
      
      render json: {
        payments: payments.map { |p| payment_json(p) }
      }, status: :ok
    end

    private

    def find_or_create_user
      telegram_id = params[:telegram_id] || request.headers['X-Telegram-User-Id']
      
      unless telegram_id
        render json: { error: 'Telegram ID is required' }, status: :bad_request
        return
      end

      @user = User.find_or_create_by(telegram_id: telegram_id) do |user|
        user.username = params[:username]
      end
    end

    def find_payment
      @payment = Payment.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Payment not found' }, status: :not_found
    end

    def payment_description(payment_type, amount)
      case payment_type
      when 'premium'
        "Premium subscription - $#{amount}"
      when 'single_search'
        "Single search - $#{amount}"
      else
        "Payment - $#{amount}"
      end
    end

    def map_liqpay_status(liqpay_status)
      case liqpay_status
      when 'success', 'sandbox'
        'success'
      when 'failure', 'error'
        'failed'
      when 'reversed', 'refund'
        'refunded'
      else
        'pending'
      end
    end

    def process_successful_payment
      case @payment.payment_type
      when 'premium'
        expires_at = @payment.paid_at + 1.month
        @payment.user.activate_premium!(expires_at: expires_at)
        @payment.update!(expires_at: expires_at)
      when 'single_search'
        @payment.user.increment!(:search_credits)
      end
    end

    def payment_json(payment)
      {
        id: payment.id,
        payment_type: payment.payment_type,
        amount: payment.amount,
        currency: payment.currency,
        status: payment.status,
        created_at: payment.created_at,
        paid_at: payment.paid_at
      }
    end
  end
end

