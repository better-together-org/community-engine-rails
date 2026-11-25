# frozen_string_literal: true

require 'rails_helper'

# What the order engine asks of a purchasable, instead of testing its class (docs/billing/purchasable_split_plan.md, PS-3).
RSpec.describe BetterTogether::Billing::Purchasable, '#renews?, #extra?, #plan_line?, #fulfilled_by_order? and #held_by?' do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }

  describe 'the defaults, for a plain one-off purchasable' do
    subject(:purchasable) { Class.new { include BetterTogether::Billing::Purchasable }.new }

    it 'does not renew, is not an extra, is no plan line, is not fulfilled by its order and is held by nobody' do
      expect(purchasable).to have_attributes(renews?: false, extra?: false, plan_line?: false, fulfilled_by_order?: false)
      expect(purchasable.held_by?(buyer)).to be(false)
    end
  end

  describe 'a plan' do
    it 'renews when it is recurring and is fulfilled through its order only when one-time' do
      monthly = create(:better_together_billing_plan, **cash)
      once = create(:better_together_billing_plan, :one_time, **cash)

      expect(monthly).to have_attributes(renews?: true, extra?: false, plan_line?: true, fulfilled_by_order?: false)
      expect(once).to have_attributes(renews?: false, extra?: false, plan_line?: true, fulfilled_by_order?: true)
    end

    it 'treats an add-on as an extra that is not fulfilled by its own order' do
      add_on = create(:better_together_billing_plan, :one_time, **cash, add_on: true)

      expect(add_on).to have_attributes(renews?: false, extra?: true, plan_line?: true, fulfilled_by_order?: false)
    end
  end

  describe 'a plan held by a person' do
    let(:once) { create(:better_together_billing_plan, :one_time, **cash, amount_cents: 2000) }

    it 'is held while a bought order stands, and not by someone else or once refunded' do
      order = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: once }])
      pay_manually(order)

      expect(once.held_by?(buyer)).to be(true)
      expect(once.held_by?(create(:better_together_person))).to be(false)
      expect(once.held_by?(nil)).to be(false)

      order.update!(status: 'refunded')
      expect(once.held_by?(buyer)).to be(false)
    end

    it 'is never held when it is an add-on' do
      add_on = create(:better_together_billing_plan, :one_time, **cash, add_on: true)

      expect(add_on.held_by?(buyer)).to be(false)
    end
  end
end
