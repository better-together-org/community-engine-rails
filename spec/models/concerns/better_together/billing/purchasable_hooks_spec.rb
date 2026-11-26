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
    it 'always renews, is a plan line, and is never fulfilled through its own order' do
      expect(create(:better_together_billing_plan,
                    **cash)).to have_attributes(renews?: true, extra?: false, plan_line?: true, fulfilled_by_order?: false)
    end
  end

  describe 'a price' do
    let(:price) { create(:better_together_billing_price, product: create(:better_together_billing_product, platform: host_platform)) }

    it 'is fulfilled through its own order and is an extra only when its product needs something' do
      expect(price).to have_attributes(renews?: false, extra?: false, plan_line?: false, fulfilled_by_order?: true)
      create(:better_together_billing_purchase_requirement, :for_any_plan, dependent: price.product)

      expect(price.reload).to have_attributes(extra?: true)
    end

    it 'is held while a paid order of it stands, and not by someone else or once refunded' do
      order = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: price }])
      pay_manually(order)

      expect(price.held_by?(buyer)).to be(true)
      expect(price.held_by?(create(:better_together_person))).to be(false)
      expect(price.held_by?(nil)).to be(false)

      order.update!(status: 'refunded')
      expect(price.held_by?(buyer)).to be(false)
    end
  end
end
