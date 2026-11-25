# frozen_string_literal: true

require 'rails_helper'

# Whether a person may buy a dependent purchasable: the rules stored for it, or for its product when it is a price.
RSpec.describe BetterTogether::Billing::PurchaseRequirements::Evaluate do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'
  include_context 'with billing extras'

  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:plan) { create(:better_together_billing_plan, :unlinked, **cash, amount_cents: 2000) }
  let(:other_plan) { create(:better_together_billing_plan, :unlinked, **cash, amount_cents: 1500) }
  let(:dependent) { create_extra(amount_cents: 700, needs: nil) }

  def evaluate(person: buyer, in_order: [], target: dependent) = described_class.call(dependent: target, person:, in_order:)

  def hold(held) = hold_plan!(held)

  def rule(**attrs) = create(:better_together_billing_purchase_requirement, dependent: dependent.product, **attrs)

  it 'is open to everyone when nothing is required' do
    expect(evaluate).to be_met
  end

  describe 'a stored rule on one specific prerequisite' do
    before { rule(prerequisite: plan) }

    it 'is unmet for someone who holds nothing and is not buying it' do
      result = evaluate

      expect(result).not_to be_met
      expect(result.unmet.map(&:prerequisite)).to eq([plan])
    end

    it 'is met by holding the prerequisite' do
      hold(plan)

      expect(evaluate).to be_met
    end

    it 'is met by having the prerequisite in the same order' do
      expect(evaluate(in_order: [plan])).to be_met
    end

    it 'is not met by a different plan, or by a visitor' do
      hold(other_plan)

      expect(evaluate).not_to be_met
      expect(evaluate(person: nil)).not_to be_met
    end
  end

  describe 'how a rule is met' do
    it 'with holding only, an order line is not enough' do
      rule(prerequisite: plan, met_by: 'holding')

      expect(evaluate(in_order: [plan])).not_to be_met
    end

    it 'with in order only, holding is not enough' do
      rule(prerequisite: plan, met_by: 'in_order')
      hold(plan)

      expect(evaluate).not_to be_met
      expect(evaluate(in_order: [plan])).to be_met
    end
  end

  describe 'several rules' do
    it 'needs any one of them met' do
      rule(prerequisite: plan)
      rule(prerequisite: other_plan)
      hold(other_plan)

      expect(evaluate).to be_met
    end

    it 'also needs every required rule met' do
      rule(prerequisite: plan)
      rule(prerequisite: other_plan, required: true)
      hold(plan)

      expect(evaluate).not_to be_met
      hold(other_plan)
      expect(evaluate).to be_met
    end
  end

  describe 'the kind plan' do
    before { rule(prerequisite: nil, prerequisite_kind: 'plan') }

    it 'is met by holding any primary plan, or by one in the order' do
      expect(evaluate).not_to be_met
      expect(evaluate(in_order: [plan])).to be_met
      hold(plan)
      expect(evaluate).to be_met
    end

    it 'is not met by another extra in the order' do
      expect(evaluate(in_order: [create_extra(needs: nil)])).not_to be_met
    end
  end

  describe 'a rule stored on the product' do
    it 'applies to every price of it' do
      rule(prerequisite: plan)
      newer = create(:better_together_billing_price, product: dependent.product, amount_cents: 900, currency: 'USD')

      expect(evaluate(target: newer)).not_to be_met
      expect(evaluate(target: newer, in_order: [plan])).to be_met
    end
  end

  describe '#reason' do
    it 'is nil when the rules are met and names what is missing when not' do
      rule(prerequisite: plan)
      rule(prerequisite: other_plan)
      unmet = evaluate

      expect(unmet.reason).to include(plan.name, other_plan.name)
      expect(evaluate(in_order: [plan]).reason).to be_nil
    end

    it 'names the kind in words' do
      rule(prerequisite: nil, prerequisite_kind: 'plan')

      expect(evaluate.reason).to include(I18n.t('better_together.billing.purchase_requirements.kinds.plan'))
    end
  end
end
