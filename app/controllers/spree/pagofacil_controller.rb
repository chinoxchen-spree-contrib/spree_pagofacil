module Spree
  class PagofacilController < Spree::BaseController
    protect_from_forgery except: [:notify]
    layout 'spree/layouts/redirect', only: :success

    def success
      @payment = Spree::Payment.where(number: params[:payment]).last
      return unless @payment.order.completed?

      @current_order = nil
      unless PagofacilNotification.find_by(order_id: @payment.order_id, payment_id: @payment.id)
        flash.notice = Spree.t(:order_processed_successfully)
        flash['order_completed'] = true
      end

      PagofacilNotification.create(order_id: @payment.order_id, payment_id: @payment.id)
      redirect_to completion_route(@payment.order)
    end

    def cancel
      @payment = Spree::Payment.where(number: params[:payment]).last
      redirect_to checkout_state_path(:payment) and return
    end

    def notify
      x_account_id = params['x_account_id']
      x_amount = params['x_amount']
      x_currency = params['x_currency']
      x_gateway_reference = params['x_gateway_reference']
      x_reference = params['x_reference']
      x_result = params['x_result']
      x_test = params['x_test']
      x_timestamp = params['x_timestamp']
      x_message = params['x_message']
      x_signature = params['x_signature']

      payment = Spree::Payment.find_by!(number: x_reference)
      payment_method = payment.payment_method

      create_signature = 'x_account_id'+x_account_id+
                         'x_amount'+x_amount+
                         'x_currency'+x_currency+
                         'x_gateway_reference'+x_gateway_reference+
                         'x_message'+x_message+
                         'x_reference'+x_reference+
                         'x_result'+x_result+
                         'x_test'+x_test+
                         'x_timestamp'+x_timestamp

      signature = OpenSSL::HMAC.hexdigest('sha256', payment_method.preferences[:pagofacil_secret_token], create_signature)


      unless payment.completed? || signature != x_signature
        case x_result
        when 'completed'
          payment.complete!
          order = payment.order
          order.skip_stock_validation = true
          payment.order.next!

        else payment.failure!
        end
      end
      head :ok
    rescue
      head :unprocessable_entity
    end

    def completion_route(order, custom_params = nil) spree.order_path(order, custom_params)
    end
  end
end
