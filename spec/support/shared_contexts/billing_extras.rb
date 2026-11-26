# frozen_string_literal: true

# Helpers for specs about extras: a product bought on its own price, that needs a plan held or in the order (PS-6).
# Needs the 'with orders fixtures' context (or one that includes it).
RSpec.shared_context 'with billing extras' do
  let(:cash_terms) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }

  # A price on a new product, on sale in the host platform. `needs` is a plan, a list of plans, :any_plan, or nil for no rule.
  def create_extra(amount_cents: 700, currency: 'USD', name: 'Extra seat', needs: :any_plan, **product_attrs)
    product = create(:better_together_billing_product, platform: host_platform, name:, **product_attrs)
    price = create(:better_together_billing_price, product:, amount_cents:, currency:)
    Array(needs).each { |need| require_for(product, need) }
    price
  end

  def require_for(product, need)
    traits = need == :any_plan ? [:for_any_plan] : []
    attrs = need == :any_plan ? {} : { prerequisite: need }
    create(:better_together_billing_purchase_requirement, *traits, dependent: product, platform: host_platform, **attrs)
  end

  # The person holds the plan: a live entitlement from a subscription they do not pay for is enough for the rule.
  def hold_plan!(held_plan, person = buyer)
    order = create(:better_together_billing_order, platform: host_platform, buyer: person, status: 'paid')
    host_platform.billing_entitlements.create!(plan: held_plan, beneficiary: person, order:, starts_at: Time.current)
  end
end
