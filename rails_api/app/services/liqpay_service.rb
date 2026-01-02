require 'liqpay'
require 'base64'
require 'json'

class LiqpayService
  class << self
    def create_payment(payment)
      liqpay = Liqpay.new(
        public_key: public_key,
        private_key: private_key
      )

      order_id = payment.id.to_s
      amount = payment.amount.to_f
      description = payment_description(payment)
      result_url = result_url(payment.id)
      server_url = server_url(payment.id)

      params = {
        version: '3',
        action: 'pay',
        amount: amount,
        currency: payment.currency,
        description: description,
        order_id: order_id,
        result_url: result_url,
        server_url: server_url
      }

      payment.update!(liqpay_order_id: order_id)

      # Generate checkout URL using LiqPay gem
      # The gem handles data encoding and signature generation internally
      checkout_url = liqpay.checkout_url(params)
      
      # Also provide data and signature for direct form submission if needed
      data_string = params.to_json
      data = Base64.strict_encode64(data_string)
      signature = liqpay.str_to_sign(data_string)

      {
        data: data,
        signature: signature,
        url: checkout_url
      }
    end

    def verify_callback(data, signature)
      liqpay = Liqpay.new(
        public_key: public_key,
        private_key: private_key
      )
      # LiqPay sends data as base64-encoded string, signature is calculated from the base64 string
      expected_signature = liqpay.str_to_sign(data)
      expected_signature == signature
    end

    def parse_callback_data(data)
      JSON.parse(Base64.decode64(data))
    rescue JSON::ParserError, ArgumentError => e
      Rails.logger.error("Error parsing LiqPay callback data: #{e.message}")
      nil
    end

    private

    def public_key
      ENV.fetch('LIQPAY_PUBLIC_KEY')
    end

    def private_key
      ENV.fetch('LIQPAY_PRIVATE_KEY')
    end

    def payment_description(payment)
      case payment.payment_type
      when 'premium'
        "Premium subscription - #{payment.amount} #{payment.currency}"
      when 'single_search'
        "Single search - #{payment.amount} #{payment.currency}"
      else
        "Payment - #{payment.amount} #{payment.currency}"
      end
    end

    def result_url(payment_id)
      mini_app_url = ENV.fetch('MINI_APP_URL', 'http://localhost:3000/mini-app')
      "#{mini_app_url}?payment_id=#{payment_id}"
    end

    def server_url(payment_id)
      base_url = ENV.fetch('RAILS_API_URL', 'http://localhost:3000')
      "#{base_url}/api/payments/#{payment_id}/callback"
    end
  end
end

