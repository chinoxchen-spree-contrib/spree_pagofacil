module Spree
  class PaymentMethod::Pagofacil < PaymentMethod

    preference :pagofacil_url, :string
    preference :pagofacil_username, :string
    preference :pagofacil_account_id, :string
    preference :pagofacil_password, :string
    preference :pagofacil_secret_token, :string

    def payment_profiles_supported?
      false
    end

    def cancel(*)
    end

    def source_required?
      false
    end

    def credit(*)
      self
    end

    def success?
      true
    end

    def authorization
      self
    end
  end
end
