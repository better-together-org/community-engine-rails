# frozen_string_literal: true

module Pay
  module Local
    # A Pay customer for the ways of paying Community Engine settles itself: cash, a cheque, an
    # e-transfer and store credit. There is no vendor and no webhook, so, like Pay's own
    # FakeProcessor, this only keeps records; unlike it, it is real (not a stub that Pay refuses by
    # default), and it keeps its subscriptions to the dates Community Engine sets (see Subscription).
    #
    # The pending state of such a payment (waiting for the seller to say the money arrived) is not
    # here: Pay has no pending charge. A charge exists only for money that has actually settled (see
    # BetterTogether::Billing::LocalSettlement).
    #
    # Create it with `person.add_payment_processor(:local, platform: platform)`, never through Pay's
    # platform-blind owner methods (see BetterTogether::Billing::PayCustomerOwner).
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: 'Pay::Local::Charge', foreign_key: :customer_id, inverse_of: :customer
      has_many :subscriptions, dependent: :destroy, class_name: 'Pay::Local::Subscription', foreign_key: :customer_id, inverse_of: :customer
      has_many :payment_methods, dependent: :destroy, class_name: 'Pay::Local::PaymentMethod', foreign_key: :customer_id, inverse_of: :customer
      has_one :default_payment_method, -> { where(default: true) }, class_name: 'Pay::Local::PaymentMethod', foreign_key: :customer_id,
                                                                    inverse_of: :customer

      def api_record
        update!(processor_id: Pay::NanoId.generate) unless processor_id?
        self
      end

      def update_api_record(**)
        self
      end

      # Records money that settled. `options` may carry `currency`, `subscription`, `metadata`, and
      # `payment_method_type` (`cash`, `cheque`, `etransfer` or `store_credit`).
      def charge(amount, options = {})
        api_record
        method_type = options[:payment_method_type]
        attributes = options.slice(*Pay::Charge.attribute_names.map(&:to_sym)).merge(processor_id: Pay::NanoId.generate, amount:)
        attributes[:data] = (attributes[:data] || {}).merge(payment_method_type: method_type) if method_type
        charges.create!(attributes)
      end

      # Starts a subscription whose period Community Engine moves (see Subscription#advance!). The
      # period is given, because nothing here renews on its own.
      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        api_record
        attributes = options.merge(processor_id: Pay::NanoId.generate, name:, processor_plan: plan, status: options.fetch(:status, :active),
                                   quantity: options.fetch(:quantity, 1))
        days = attributes.delete(:trial_period_days)
        attributes[:trial_ends_at] = days.to_i.days.from_now if days
        attributes.deep_stringify_keys!.slice!(*subscriptions.attribute_names)
        subscriptions.create!(attributes)
      end

      def sync_subscriptions(**)
        []
      end

      def add_payment_method(_payment_method_id = nil, default: false, payment_method_type: nil)
        api_record
        method = payment_methods.create!(processor_id: Pay::NanoId.generate, default:, payment_method_type: payment_method_type || :local)
        payment_methods.where.not(id: method.id).update_all(default: false) if default # rubocop:disable Rails/SkipsModelValidations
        method
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_local_customer, Pay::Local::Customer
