# frozen_string_literal: true

require 'rails_helper'

# One order holding a recurring plan and a one-time product (MVP 1 story 2.5): the plan drives the subscription, the
# product is paid and granted once, renewals charge the plan only, and returning the product leaves the subscription alone.
RSpec.describe 'Billing mixed one-time and recurring order' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:monthly) do
    create(:better_together_billing_plan, **cash, billing_interval: 'month', amount_cents: 2000, currency: 'USD', grace_days: 7,
                                                  renewal_lead_days: 14)
  end
  let(:pass) { create(:better_together_billing_product, platform: host_platform, processor: nil, name: 'Welcome pass') }
  let(:pass_price) { create(:better_together_billing_price, product: pass, platform: host_platform, amount_cents: 1000, currency: 'USD') }
  let(:order) do
    add_grant('feature_access', { 'feature_key' => 'device_permissions', 'access_level' => 'beta' }, plan: monthly)
    add_grant('membership_role', { 'joinable' => 'platform', 'role' => supporter_role.identifier }, plan: pass)
    place_order(purpose: 'subscription', payment_method: 'cash',
                line_items: [{ purchasable: monthly.current_price }, { purchasable: pass_price }])
  end

  describe 'placing' do
    it 'holds both lines and totals them' do
      expect(order.line_items.map(&:purchasable)).to contain_exactly(monthly.current_price, pass_price)
      expect(order.total_cents).to eq(3000)
    end

    it 'sets the subscription price from the plan line alone' do
      expect(BetterTogether::Billing::Subscriptions::Start.plan_line(order).unit_amount_cents).to eq(2000)
    end
  end

  describe 'a processor checkout' do
    it 'is a subscription, with the one-time line sent inline' do
      linked = place_order(payment_method: 'fake', line_items: [{ purchasable: plan.current_price }, { purchasable: pass_price }])
      result = BetterTogether::Billing::Checkout::Lines.call(order: linked, processor: 'fake')

      one_time = result.lines.find { |line| !line.recurring? }
      expect(result.mode).to eq(:subscription)
      expect(one_time.price_data).to have_attributes(amount_cents: 1000, interval: 'one_time')
    end
  end

  describe 'paying it' do
    before do
      order
      pay_manually(order)
      follow_up
    end

    it 'starts the subscription at the plan price' do
      term = order.reload.subject

      expect(term).to have_attributes(plan: monthly, unit_amount_cents: 2000)
    end

    it 'gives what the product includes once, and what the plan includes' do
      expect(host_platform.billing_entitlements.where(product_id: [monthly.id,
                                                                   pass.id]).pluck(:product_id).uniq).to contain_exactly(monthly.id, pass.id)
    end

    it 'does not give the product twice when the follow-up runs again' do
      expect do
        BetterTogether::Billing::SyncOrderEntitlementJob.perform_now(order)
        follow_up
      end.not_to(change { host_platform.billing_entitlements.where(product_id: pass.id).count })
    end

    it 'charges only the plan on the next invoice' do
      term = order.reload.subject
      generate_renewal(term, at: Time.current + 20.days)

      expect(term.periods.last.order.line_items.map(&:purchasable)).to eq([monthly.current_price])
    end

    it 'leaves the subscription running when the product is returned' do
      term = order.reload.subject
      BetterTogether::Billing::Refunds::Record.call(payment: order.payments.sole, amount_cents: 1000, idempotency_key: 'mixed-refund')
      follow_up

      expect(term.reload.pay_subscription).to have_attributes(status: 'active', ends_at: nil)
    end
  end
end
