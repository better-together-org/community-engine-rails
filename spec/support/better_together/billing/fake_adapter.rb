# frozen_string_literal: true

module BetterTogether
  module Billing
    # In-memory processor used by core specs so billing never needs a vendor gem.
    #
    # It keeps a small catalogue (`products`, `prices`) that specs can seed. Price ids
    # containing "missing" are unknown, "boom" simulates an unreachable processor and
    # "inactive" an archived price; any other id is a USD 45.00 monthly price.
    class FakeAdapter < ProcessorAdapter # rubocop:disable Metrics/ClassLength
      attr_reader :calls, :capabilities, :products, :prices

      # `settlement:` and `countries:` let specs stand in for a manual (offline) method.
      def initialize(capabilities: %i[checkout], processor: :fake, rules: nil, settlement: :remote, countries: nil) # rubocop:disable Metrics/ParameterLists
        super()
        @capabilities = capabilities
        @processor = processor
        @rules = rules || default_rules
        @settlement = settlement
        @countries = countries
        @calls = []
        @products = {}
        @prices = {}
      end

      def settlement_kind = @settlement
      def supported_countries = @countries
      def recurring_mode = @settlement == :manual ? :manual : super
      def instruction_fields = supports?(:offline_settlement) ? [InstructionField.new(name: :note, type: :text)] : []

      def processor_name = @processor
      def webhook_event_types = ["#{@processor}.invoice.paid"]
      def lookup_kinds = %i[products prices currencies intervals]
      def field_rules(_resource = :plan) = @rules

      # A vendor event may name the platform it is for ('platform_id'), the processor
      # account it came from ('account'), and when it happened ('created').
      def normalize_webhook(vendor_event)
        {
          event_id: vendor_event['id'], event_type: vendor_event['type'], payload: vendor_event.to_h,
          platform_id: vendor_event['platform_id'], account_ref: vendor_event['account'],
          occurred_at: (Time.zone.at(vendor_event['created']) if vendor_event['created'])
        }.compact
      end

      # The event payload's 'outcome' picks the result; 'boom' raises.
      def process_event(event:, context:)
        @calls << [:process_event, event.id, context]
        outcome = event.payload['outcome'].to_s
        raise 'fake processor failure' if outcome == 'boom'

        EventResult.new(status: outcome.presence || 'processed', retry_reason: ('prerequisite_missing' if outcome == 'retry'),
                        outcome_kind: event.payload['outcome_kind'].presence)
      end

      def sanitize_payload(payload) = payload.to_h.slice('id', 'type')

      # Creates the product and price when the plan has none, otherwise reports what is
      # there. Never touches the plan.
      def sync_plan(context:, plan:, idempotency_key:) # rubocop:disable Metrics/AbcSize
        @calls << [:sync_plan, context, plan.id, idempotency_key]
        raise LookupError, 'processor unavailable' if plan.name.to_s.include?('boom')

        product_id = plan.processor_product_id.presence || "prod_#{idempotency_key.hash.abs}"
        price_id = plan.processor_price_id.presence || "price_#{idempotency_key.hash.abs}"
        price = PriceInfo.new(price_id:, product_id:, amount_cents: plan.amount_cents, currency: plan.currency,
                              interval: plan.billing_interval, active: plan.active)
        @prices[price_id] = price
        PlanSyncResult.new(product_id:, price:)
      end

      def fetch_price(context:, processor_price_id:)
        @calls << [:fetch_price, context, processor_price_id]
        raise LookupError, 'processor unavailable' if processor_price_id.to_s.include?('boom')
        return if processor_price_id.to_s.include?('missing')

        @prices.fetch(processor_price_id) do
          PriceInfo.new(price_id: processor_price_id, product_id: "prod_for_#{processor_price_id}", amount_cents: 4500,
                        currency: 'USD', interval: 'month', active: processor_price_id.to_s.exclude?('inactive'))
        end
      end

      def fetch_product(context:, processor_product_id:)
        @calls << [:fetch_product, context, processor_product_id]
        @products.fetch(processor_product_id) { ProductInfo.new(product_id: processor_product_id, name: 'Fake product') }
      end

      # Options for the processor-backed selects.
      def lookup(context:, kind:, search: nil, scope: {}, limit: 25)
        @calls << [:lookup, context, kind.to_sym, search, scope]
        raise LookupError, 'processor unavailable' if search.to_s.include?('boom')

        rows = rows_for(kind.to_sym, scope)
        rows = rows.select { |option| option.text.downcase.include?(search.to_s.downcase) } if search.present?
        rows.first(limit)
      end

      def create_checkout_session(context:, **args)
        @calls << [:create_checkout_session, context, args]
        { url: "https://fake.test/checkout/#{args[:idempotency_key]}" }
      end

      def sync_checkout_session(context:, **args)
        @calls << [:sync_checkout_session, context, args]
        { status: 'paid' }
      end

      def refund(context:, **args)
        @calls << [:refund, context, args]
        { reference: "re_#{args[:idempotency_key]}" }
      end

      def transfer(context:, **args)
        @calls << [:transfer, context, args]
        { reference: "tr_#{args[:idempotency_key]}" }
      end

      def instructions_for(context:, setting:, order:)
        @calls << [:instructions_for, context, order]
        { 'note' => setting.to_h['note'] }
      end

      private

      # Price and identity fields are fixed at creation; descriptive fields can be updated.
      def default_rules
        { name: :updatable, description: :updatable, active: :updatable,
          amount_cents: :create_only, currency: :create_only, billing_interval: :create_only,
          processor_product_id: :create_only, processor_price_id: :create_only }
      end

      def rows_for(kind, scope)
        case kind
        when :products then products_rows
        when :prices then price_rows(scope)
        when :currencies then %w[USD CAD EUR GBP JPY ISK].map { |code| LookupOption.new(value: code, text: code) }
        when :intervals then Plan::BILLING_INTERVALS.map { |value| LookupOption.new(value:, text: value) }
        else []
        end
      end

      def products_rows
        base = [LookupOption.new(value: 'prod_pro', text: 'Pro (prod_pro)'),
                LookupOption.new(value: 'prod_basic', text: 'Basic (prod_basic)')]
        base + @products.values.map { |product| LookupOption.new(value: product.product_id, text: "#{product.name} (#{product.product_id})") }
      end

      def price_rows(scope)
        product = scope.to_h.with_indifferent_access[:product]
        [LookupOption.new(value: 'price_pro_month', text: 'USD 45.00 / month, Pro'),
         LookupOption.new(value: 'price_pro_year', text: 'USD 450.00 / year, Pro')].select do |option|
          product.blank? || option.text.include?(product.to_s.delete_prefix('prod_').capitalize)
        end
      end
    end
  end
end
