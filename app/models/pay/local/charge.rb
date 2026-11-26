# frozen_string_literal: true

module Pay
  module Local
    # Money that settled outside a processor: the seller said it arrived, or store credit was spent.
    class Charge < Pay::Charge
      # Nothing to fetch: there is no processor to ask.
      def self.sync(_processor_id, **)
        nil
      end

      def api_record = self

      # Adds to what has been given back, as Pay's Stripe charge does (a full refund when no amount is given).
      def refund!(amount_to_refund = nil, **)
        update!(amount_refunded: amount_refunded.to_i + (amount_to_refund || (amount - amount_refunded.to_i)))
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_local_charge, Pay::Local::Charge
