# frozen_string_literal: true

module Pay
  module Local
    # How a local customer pays (cash, a cheque, an e-transfer, store credit). Only a label: there is no
    # card or account on record.
    class PaymentMethod < Pay::PaymentMethod
      def make_default!
        return if default?

        customer.payment_methods.update_all(default: false) # rubocop:disable Rails/SkipsModelValidations
        update!(default: true)
      end

      def detach
        destroy!
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_local_payment_method, Pay::Local::PaymentMethod
