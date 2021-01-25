module SpreePagofacil::Spree
  module CheckoutControllerDecorator
    def self.prepended(base)
      base.before_action :pay_with_pagofacil, only: :update
    end

    private

    def pay_with_pagofacil
      return unless params[:state] == 'payment'
      return if params[:order].blank? || params[:order][:payments_attributes].blank?

      pm_id = params[:order][:payments_attributes].first[:payment_method_id]
      payment_method = Spree::PaymentMethod.find(pm_id)

      if payment_method && payment_method.kind_of?(Spree::PaymentMethod::Pagofacil)
        payment_number = pagofacil_create_payment(payment_method)
        pagofacil_error && return unless payment_number.present?

        # token = Rails.cache.fetch('pagofacil_auth_token', expires_in: 10.hours) do
        #   begin
        #     url = URI(payment_method.preferences[:pagofacil_url] + "/users/login")

        #     http = Net::HTTP.new(url.host, url.port)
        #     http.use_ssl = true
        #     http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        #     request = Net::HTTP::Post.new(url)
        #     request["Accept"] = 'application/json'
        #     request["Content-Type"] = 'application/json'
        #     request.set_form_data(username: payment_method.preferences[:pagofacil_username], password: payment_method.preferences[:pagofacil_password])

        #     response = http.request(request)

        #     raise 'status <> 200' if response.code != '200'
        #     raise 'blank access token' if response['data']['access_token_jwt'].blank?
        #     response['data']['access_token_jwt']
        #   rescue
        #     raise 'cannot get access token'
        #   end
        # end



          url = URI(payment_method.preferences[:pagofacil_url] + "/trxs")

          http = Net::HTTP.new(url.host, url.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE

          request = Net::HTTP::Post.new(url)
          request["Accept"] = 'application/json'
          request["Content-Type"] = 'application/json'
          x_session_id = SecureRandom.uuid
          data = {
            "x_account_id": payment_method.preferences[:pagofacil_account_id],
            "x_amount": @order.total.to_i,
            "x_currency": 'CLP',
            "x_customer_email": @order.email,
            "x_reference": payment_number,
            "x_session_id": x_session_id,
            "x_shop_country": 'CL',
            "x_url_callback": pagofacil_notify_url,
            "x_url_cancel": pagofacil_cancel_url(payment_number),
            "x_url_complete": pagofacil_successg_url(payment_number)
          }

          signature = OpenSSL::HMAC.hexdigest('sha256', payment_method.preferences[:pagofacil_secret_token], data.sort.join)

          # response = HTTParty.post(payment_method.preferences[:pagofacil_url] + "/trxs",
          #               {
          #                 headers:
          #                 {
          #                   "Accept" => "application/json",
          #                   "Content-Type" => "application/json",
          #                   "Content-Length" => "1000"
          #                 },
          #                 body: {
          #                   "x_account_id": payment_method.preferences[:pagofacil_account_id],
          #                   "x_amount": @order.total.to_i,
          #                   "x_currency": 'CLP',
          #                   "x_reference": payment_number,
          #                   "x_customer_email": @order.email,
          #                   "x_url_complete": pagofacil_success_url(payment_number),
          #                   "x_url_cancel": pagofacil_cancel_url(payment_number),
          #                   "x_url_callback": pagofacil_notify_url,
          #                   "x_shop_country": 'CL',
          #                   "x_session_id": SecureRandom.uuid,
          #                   "x_signature": signature
          #                 }.to_json
          #               })

          request.body = {
                            "x_account_id": payment_method.preferences[:pagofacil_account_id],
                            "x_amount": @order.total.to_i,
                            "x_currency": 'CLP',
                            "x_reference": payment_number,
                            "x_customer_email": @order.email,
                            "x_url_complete": pagofacil_successg_url(payment_number),
                            "x_url_cancel": pagofacil_cancel_url(payment_number),
                            "x_url_callback": pagofacil_notify_url,
                            "x_shop_country": 'CL',
                            "x_session_id": x_session_id,
                            "x_signature": signature
                          }.to_json


          response = http.request(request)
          raise "#{response.read_body.to_s}" if response.code != '200'

          redirect_to JSON.parse(response.body)['data']['payUrl'][0]['url']
      end

    rescue StandardError => e
      pagofacil_error(e)
    end

    def pagofacil_create_payment(payment_method)
      payment = @order.payments.build(payment_method_id: payment_method.id, amount: @order.total, state: 'checkout')

      unless payment.save
        flash[:error] = payment.errors.full_messages.join("\n")
        redirect_to checkout_state_path(@order.state) && return
      end

      unless payment.pend!
        flash[:error] = payment.errors.full_messages.join("\n")
        redirect_to checkout_state_path(@order.state) && return
      end

      payment.number
    end

    def pagofacil_error(e = nil)
      @order.errors[:base] << "pagofacil error #{e.try(:message)}"
      render :edit
    end
  end
end

::Spree::CheckoutController.prepend SpreePagofacil::Spree::CheckoutControllerDecorator
