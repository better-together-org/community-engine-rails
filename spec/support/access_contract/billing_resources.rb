# frozen_string_literal: true

require_relative 'resources'

# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Metrics/MethodLength

module AccessContractProbe
  module Resources
    # Billing probes. Every billing record belongs to a platform, so the persona that matters is the actor's
    # standing on that platform. The host platform has billing on; `other_platform` is a second platform whose
    # records the host's stewards must never reach.
    class BillingBase < Base
      def initialize(world)
        world.prepare_billing
        super
      end

      def host = world.host
      def other = world.other_platform

      def evaluate(action, persona, state)
        previous = Current.platform
        Current.platform = serving_platform(state)
        Current.billing_enabled = nil
        super
      ensure
        Current.platform = previous
        Current.billing_enabled = nil
      end

      def owner_for(_state) = nil

      private

      def serving_platform(_state) = host
      def platform_for(state) = state == 'other_platform' ? other : host
    end

    # Records only a platform steward operates: one built for each platform, no buyer.
    class BillingStewardBase < BillingBase
      def record_for(target, state)
        return model_class if target == :class
        return build_record(host) if target == :new

        @records.fetch(state)
      end

      private

      def build_fixtures
        @records = { 'own_platform' => make_record(host), 'other_platform' => make_record(other) }
      end

      def build_record(platform) = model_class.new(platform:)
      def make_record(platform) = build_record(platform)

      def applicable?(persona, _state) = %w[record_owner blocked_user].exclude?(persona)
    end

    class BillingAgreementRequirementProbe < BillingStewardBase
      KEY = 'billing_agreement_requirement'
      POLICY = 'BetterTogether::Billing::AgreementRequirementPolicy'
      MODEL = 'BetterTogether::Billing::AgreementRequirement'
      ACTIONS = {
        'index' => %i[index? class],
        'create' => %i[create? new],
        'destroy' => %i[destroy? subject],
        'show' => %i[show? subject],
        'update' => %i[update? subject],
        'edit' => %i[edit? subject],
        'activate_agreement' => %i[activate_agreement? subject],
        'scope' => :scope
      }.freeze

      def make_record(platform) = create(:better_together_billing_agreement_requirement, platform:)
    end

    class BillingProcessorSettingProbe < BillingStewardBase
      KEY = 'billing_processor_setting'
      POLICY = 'BetterTogether::Billing::ProcessorSettingPolicy'
      MODEL = 'BetterTogether::Billing::ProcessorSetting'
      ACTIONS = {
        'index' => %i[index? class],
        'edit' => %i[edit? subject],
        'update' => %i[update? subject],
        'show' => %i[show? subject],
        'destroy' => %i[destroy? subject],
        'scope' => :scope
      }.freeze

      def make_record(platform)
        platform.billing_processor_settings.find_or_create_by!(processor: 'cash') { |setting| setting.enabled = false }
      end
    end

    class BillingTaxRegistrationProbe < BillingStewardBase
      KEY = 'billing_tax_registration'
      POLICY = 'BetterTogether::Billing::TaxRegistrationPolicy'
      MODEL = 'BetterTogether::Billing::TaxRegistration'
      ACTIONS = {
        'index' => %i[index? class],
        'new' => %i[new? new],
        'create' => %i[create? new],
        'edit' => %i[edit? subject],
        'update' => %i[update? subject],
        'show' => %i[show? subject],
        'destroy' => %i[destroy? subject],
        'scope' => :scope
      }.freeze

      def make_record(platform) = create(:better_together_billing_tax_registration, platform:)
    end

    class BillingPromotionProbe < BillingStewardBase
      KEY = 'billing_promotion'
      POLICY = 'BetterTogether::Billing::PromotionPolicy'
      MODEL = 'BetterTogether::Billing::Promotion'
      ACTIONS = {
        'index' => %i[index? class],
        'new' => %i[new? new],
        'create' => %i[create? new],
        'activate' => %i[activate? subject],
        'deactivate' => %i[deactivate? subject],
        'show' => %i[show? subject],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject]
      }.freeze
    end

    class BillingGrantProbe < BillingStewardBase
      KEY = 'billing_grant'
      POLICY = 'BetterTogether::Billing::GrantPolicy'
      MODEL = 'BetterTogether::Billing::Grant'
      ACTIONS = {
        'create' => %i[create? new],
        'destroy' => %i[destroy? subject],
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'update' => %i[update? subject]
      }.freeze

      def build_record(platform)
        model_class.new(platform:, product: create(:better_together_billing_product, platform:))
      end
    end

    # The seller's queue of payments made outside the platform. The buyer's part is the order policy's claim.
    class BillingOfflinePaymentProbe < BillingStewardBase
      KEY = 'billing_offline_payment'
      POLICY = 'BetterTogether::Billing::OfflinePaymentPolicy'
      MODEL = 'BetterTogether::Billing::OfflinePayment'
      ACTIONS = {
        'index' => %i[index? class],
        'receive' => %i[receive? subject],
        'reject' => %i[reject? subject],
        'clear' => %i[clear? subject],
        'bounce' => %i[bounce? subject],
        'show' => %i[show? subject],
        'create' => %i[create? new],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject]
      }.freeze

      def build_record(platform)
        order = model_class.reflect_on_association(:order).klass.new(platform:, seller: nil)
        model_class.new(platform:, order:)
      end
    end

    class BillingPersonLookupProbe < BillingStewardBase
      KEY = 'billing_person_lookup'
      POLICY = 'BetterTogether::Billing::PersonLookupPolicy'
      MODEL = 'BetterTogether::Person'
      ACTIONS = {
        'index' => %i[index? class]
      }.freeze

      def build_fixtures = @records = {}
    end

    class BillingEventProbe < BillingStewardBase
      KEY = 'billing_event'
      POLICY = 'BetterTogether::Billing::EventPolicy'
      MODEL = 'BetterTogether::Billing::Event'
      ACTIONS = {
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'replay' => %i[replay? subject],
        'create' => %i[create? new],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject],
        'scope' => :scope
      }.freeze

      def make_record(platform) = create(:better_together_billing_event, platform:)
    end

    class BillingCreditAccountProbe < BillingStewardBase
      KEY = 'billing_credit_account'
      POLICY = 'BetterTogether::Billing::CreditAccountPolicy'
      MODEL = 'BetterTogether::Billing::CreditAccount'
      ACTIONS = {
        'own' => %i[own? class],
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'grant' => %i[grant? class],
        'create' => %i[create? new],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject]
      }.freeze

      def build_record(platform) = model_class.new(platform:, currency: 'CAD')
    end

    class BillingEntitlementProbe < BillingStewardBase
      KEY = 'billing_entitlement'
      POLICY = 'BetterTogether::Billing::EntitlementPolicy'
      MODEL = 'BetterTogether::Billing::Entitlement'
      ACTIONS = {
        'own' => %i[own? class],
        'allowances' => %i[allowances? class],
        'set_enforcement' => %i[set_enforcement? class],
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'create' => %i[create? new],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject]
      }.freeze
    end

    class BillingReportProbe < BillingStewardBase
      KEY = 'billing_report'
      POLICY = 'BetterTogether::Metrics::BillingReportPolicy'
      MODEL = 'BetterTogether::Metrics::BillingReport'
      ACTIONS = {
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'create' => %i[create? new],
        'destroy' => %i[destroy? subject],
        'download' => %i[download? subject]
      }.freeze

      def build_record(platform) = model_class.new(platform_id: platform.id)
    end

    # Catalog items: plans and products, each in the catalog states a buyer meets, plus another platform's item.
    class BillingCatalogBase < BillingBase
      STATES = %w[public hidden draft members_only other_platform].freeze

      def record_for(target, state)
        return model_class if target == :class
        return build_new if target == :new

        @records.fetch(state)
      end

      private

      def build_fixtures
        @records = STATES.to_h { |state| [state, make_item(state)] }
      end

      def applicable?(persona, _state) = %w[record_owner blocked_user].exclude?(persona)

      def attributes_for(state)
        { platform: platform_for(state), listed: state != 'hidden', active: state != 'draft',
          restricted_to_members: state == 'members_only' }
      end

      def build_new = model_class.new(platform: host)
    end

    class BillingPlanProbe < BillingCatalogBase
      KEY = 'billing_plan'
      POLICY = 'BetterTogether::Billing::PlanPolicy'
      MODEL = 'BetterTogether::Billing::Plan'
      ACTIONS = {
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'new' => %i[new? new],
        'create' => %i[create? new],
        'edit' => %i[edit? subject],
        'update' => %i[update? subject],
        'sync' => %i[sync? subject],
        'snapshot' => %i[snapshot? subject],
        'lookup' => %i[lookup? class],
        'destroy' => %i[destroy? subject],
        'catalog' => %i[catalog? class],
        'catalog_show' => %i[catalog_show? subject],
        'offer' => %i[offer? subject],
        'purchase' => %i[purchase? subject],
        'scope' => :scope
      }.freeze

      private

      def make_item(state) = create(:better_together_billing_plan, **attributes_for(state))
    end

    class BillingProductProbe < BillingCatalogBase
      KEY = 'billing_product'
      POLICY = 'BetterTogether::Billing::ProductPolicy'
      MODEL = 'BetterTogether::Billing::Product'
      ACTIONS = {
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'new' => %i[new? new],
        'create' => %i[create? new],
        'edit' => %i[edit? subject],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject],
        'catalog' => %i[catalog? class],
        'catalog_show' => %i[catalog_show? subject],
        'purchase' => %i[purchase? subject]
      }.freeze

      private

      def make_item(state)
        product = create(:better_together_billing_product, **attributes_for(state))
        create(:better_together_billing_price, product:)
        product
      end
    end

    # A price on a product of each platform, and an archived one.
    class BillingPriceProbe < BillingBase
      KEY = 'billing_price'
      POLICY = 'BetterTogether::Billing::PricePolicy'
      MODEL = 'BetterTogether::Billing::Price'
      ACTIONS = {
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'new' => %i[new? new],
        'create' => %i[create? new],
        'archive' => %i[archive? subject],
        'edit' => %i[edit? subject],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject],
        'purchase' => %i[purchase? subject],
        'buy_alone' => %i[buy_alone? subject]
      }.freeze

      def record_for(target, state)
        return model_class if target == :class
        return model_class.new(platform: host, product: @prices['public'].product) if target == :new

        @prices.fetch(state)
      end

      private

      def build_fixtures
        @prices = %w[public archived other_platform].to_h do |state|
          product = create(:better_together_billing_product, platform: platform_for(state), listed: true)
          price = create(:better_together_billing_price, product:)
          price.archive! if state == 'archived'
          [state, price]
        end
      end

      def applicable?(persona, _state) = %w[record_owner blocked_user].exclude?(persona)
    end

    # Records a buyer owns. "own" is the buyer, "someone_elses" is a record bought by another person.
    class BillingBuyerBase < BillingBase
      def record_for(target, state)
        return model_class if target == :class
        return build_new if target == :new

        @records.fetch(state)
      end

      def owner_for(_state) = @buyer

      private

      def build_fixtures
        @buyer = world.new_user
        @other_buyer = world.new_user
        @records = { 'own' => make_record(@buyer.person), 'someone_elses' => make_record(@other_buyer.person) }
      end

      def applicable?(persona, state)
        return false if persona == 'blocked_user'
        return persona == 'record_owner' if state == 'own'
        return persona != 'record_owner' if state == 'someone_elses'

        persona != 'record_owner'
      end

      def paid_order(buyer)
        order = create(:better_together_billing_order, :awaiting_payment, buyer:, platform: host, total_cents: 4500)
        create(:better_together_billing_payment, order:, status: 'succeeded', processor: 'cash')
        order.reload
      end
    end

    class BillingOrderProbe < BillingBuyerBase
      KEY = 'billing_order'
      POLICY = 'BetterTogether::Billing::OrderPolicy'
      MODEL = 'BetterTogether::Billing::Order'
      ACTIONS = {
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'checkout' => %i[checkout? class],
        'new' => %i[new? new],
        'create' => %i[create? new],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject],
        'claim' => %i[claim? subject],
        'add_payment' => %i[add_payment? subject],
        'pay' => %i[pay? subject],
        'checkout_return' => %i[checkout_return? subject],
        'sales' => %i[sales? class],
        'sale' => %i[sale? subject],
        'refund' => %i[refund? subject],
        'return_payments' => %i[return_payments? subject],
        'cancel' => %i[cancel? subject],
        'walk_up' => %i[walk_up? class],
        'scope' => :scope
      }.freeze

      private

      def build_new = model_class.new(platform: host)
      def make_record(person) = create(:better_together_billing_order, :awaiting_payment, buyer: person, platform: host, total_cents: 4500)
    end

    class BillingRefundRequestProbe < BillingBuyerBase
      KEY = 'billing_refund_request'
      POLICY = 'BetterTogether::Billing::RefundRequestPolicy'
      MODEL = 'BetterTogether::Billing::RefundRequest'
      ACTIONS = {
        'new' => %i[new? subject],
        'create' => %i[create? subject],
        'cancel' => %i[cancel? subject],
        'index' => %i[index? class],
        'show' => %i[show? subject],
        'decide' => %i[decide? subject],
        'scope' => :scope
      }.freeze

      private

      def make_record(person)
        order = paid_order(person)
        request = model_class.new(platform_id: host.id, order:, requester: person, currency: order.currency, reason: 'duplicate', status: 'pending')
        request.save!(validate: false)
        request
      end
    end

    class BillingSubscriptionTermProbe < BillingBuyerBase
      KEY = 'billing_subscription_term'
      POLICY = 'BetterTogether::Billing::SubscriptionTermPolicy'
      MODEL = 'BetterTogether::Billing::SubscriptionTerm'
      ACTIONS = {
        'own' => %i[own? class],
        'show' => %i[show? subject],
        'cancel' => %i[cancel? subject],
        'resume' => %i[resume? subject],
        'accept_agreements' => %i[accept_agreements? subject],
        'change_plan' => %i[change_plan? subject],
        'change_method' => %i[change_method? subject],
        'index' => %i[index? class],
        'subscriber' => %i[subscriber? subject],
        'waive' => %i[waive? subject],
        'extend_grace' => %i[extend_grace? subject],
        'steward_cancel' => %i[steward_cancel? subject],
        'steward_resume' => %i[steward_resume? subject],
        'move_to_current_price' => %i[move_to_current_price? subject],
        'create' => %i[create? new],
        'update' => %i[update? subject],
        'destroy' => %i[destroy? subject]
      }.freeze

      private

      def build_new = model_class.new(platform: host)

      # The policy reads only the payer and the platform, so the term is built, not saved.
      def make_record(person)
        customer = Pay::Customer.new(owner: person)
        model_class.new(platform: host, pay_subscription: Pay::Subscription.new(customer:))
      end
    end

    # What a platform's stewards may do depends on whether the platform is the host or a hosted one.
    class BillingHostedProbe < BillingBase
      KEY = 'billing_hosted'
      POLICY = 'BetterTogether::Billing::HostedBillingPolicy'
      MODEL = 'BetterTogether::Billing::HostedAccount'
      ACTIONS = {
        'show' => %i[show? class], 'accept' => %i[accept? class], 'plan' => %i[plan? class],
        'index' => %i[index? class], 'suspend' => %i[suspend? class], 'resume' => %i[resume? class]
      }.freeze

      def record_for(_target, _state) = model_class

      private

      def serving_platform(state) = state == 'hosted_platform' ? world.hosted_platform : host
      def build_fixtures = nil
      def applicable?(persona, _state) = %w[record_owner blocked_user].exclude?(persona)
    end

    BILLING_PROBES = [
      BillingAgreementRequirementProbe, BillingProcessorSettingProbe, BillingTaxRegistrationProbe, BillingPromotionProbe,
      BillingGrantProbe, BillingOfflinePaymentProbe, BillingPersonLookupProbe, BillingEventProbe, BillingCreditAccountProbe, BillingEntitlementProbe,
      BillingReportProbe, BillingPlanProbe, BillingProductProbe, BillingPriceProbe, BillingOrderProbe, BillingRefundRequestProbe,
      BillingSubscriptionTermProbe, BillingHostedProbe
    ].freeze
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength, Metrics/MethodLength
