# frozen_string_literal: true

module BetterTogether
  module Billing
    # Makes a model (a Person) a Pay customer owner, safely across platforms.
    #
    # Pay's own owner API is platform-blind. `set_payment_processor` clears the `default` flag
    # on ALL of an owner's customers (every platform's) and picks up another platform's row;
    # `add_payment_processor` finds an owner's customer without regard to platform; and both
    # raise in a background job, where `Current.platform` is nil. So the macro is included
    # (the association, destroy and sync behaviour are wanted) and its processor methods are
    # replaced by ones that REQUIRE a platform and never touch another platform's customers.
    #
    #   person.add_payment_processor(:local, platform: platform)
    #   person.payment_processor_for(platform)   # the default customer on that platform
    #
    # `payment_processor` (unscoped) is refused: with customers on several platforms it
    # would be nondeterministic. Pay's own code never calls it on an owner.
    module PayCustomerOwner
      extend ActiveSupport::Concern

      class PlatformRequired < ArgumentError; end
      class UnscopedProcessor < NoMethodError; end

      # The processors a customer can be created for. Names are checked against this list
      # before any constant is resolved. `fake_processor` is Pay's stub, only for tests.
      PROCESSORS = %w[local stripe braintree paddle_billing paddle_classic lemon_squeezy].freeze

      included do
        include Billable

        pay_customer
        # Prepended AFTER the macro: the macro includes Pay's own (platform-blind) methods, and
        # a plain include here would sit below them in the ancestor chain.
        prepend PlatformAware

        # Pay's checkout helpers look an owner up from a `client_reference_id` that carries
        # the owner's class and id, and would then create a customer with no platform. CE
        # carries its own order id instead, so keep that lookup inert.
        Pay::Stripe.model_names.delete(name) if Pay::Stripe.respond_to?(:model_names)
      end

      # The platform-aware replacements for Pay's owner methods.
      module PlatformAware
        # A person is billed on every platform they buy from.
        def billing_bound_platform_id = nil

        # Customer name and email as Pay reads them.
        def pay_customer_name = name

        # Email changes reach the processor through the extension, not through Pay's sync job
        # (a person's email lives on their user, so there is no column change to observe).
        def pay_should_sync_customer? = false

        def payment_processor
          raise UnscopedProcessor, 'a person can be a customer of several platforms: use payment_processor_for(platform)'
        end

        # The default customer for this owner on one platform, or nil.
        def payment_processor_for(platform)
          raise PlatformRequired, 'a platform is required' if platform.blank?

          pay_customers.for_platform(platform).active.find_by(default: true)
        end

        # Finds or creates this owner's customer for the processor on the platform, and makes it
        # the platform's default. Other platforms' customers are not touched.
        def set_payment_processor(processor_name, platform: nil, allow_fake: false, stripe_account: nil, **attributes)
          customer = nil
          with_lock do
            pay_customers.for_platform(platform_for!(platform)).update_all(default: false) # rubocop:disable Rails/SkipsModelValidations
            customer = find_or_build_customer(processor_name, platform, allow_fake:, stripe_account:)
            customer.update!(attributes.merge(default: true))
          end
          customer
        end

        # Same, without changing which customer is the default.
        def add_payment_processor(processor_name, platform: nil, allow_fake: false, stripe_account: nil, **attributes)
          customer = find_or_build_customer(processor_name, platform, allow_fake:, stripe_account:)
          customer.update!(attributes)
          customer
        end

        private

        def platform_for!(platform)
          raise PlatformRequired, 'a platform is required' if platform.blank?

          platform
        end

        def find_or_build_customer(processor_name, platform, allow_fake:, stripe_account:)
          klass = customer_class(processor_name, allow_fake:)
          pay_customers.for_platform(platform_for!(platform)).active
                       .where(Pay::Customer.inheritance_column => klass.name, processor: processor_name.to_s, stripe_account:)
                       .first_or_initialize
        end

        def customer_class(processor_name, allow_fake:)
          name = processor_name.to_s
          allowed = allow_fake ? PROCESSORS + %w[fake_processor] : PROCESSORS
          raise Pay::Error, "Processor `#{name}` is not allowed" unless allowed.include?(name)

          klass = "Pay::#{name.classify}::Customer".constantize
          raise ArgumentError, 'not a valid payment processor' if klass.ancestors.exclude?(Pay::Customer)

          klass
        end
      end
    end
  end
end
