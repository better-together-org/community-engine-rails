# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PurchaseRequirement do
  let!(:host_platform) { configure_host_platform }
  let(:cash) { { processor: nil, processor_price_id: nil, processor_product_id: nil, accepted_payment_methods: %w[cash] } }
  let(:plan) { create(:better_together_billing_plan, **cash) }
  let(:extra) { create(:better_together_billing_product, platform: host_platform) }

  def error_keys(record)
    record.valid?
    record.errors.details.values.flatten.pluck(:error)
  end

  it 'is valid with one specific prerequisite' do
    expect(build(:better_together_billing_purchase_requirement, dependent: extra, prerequisite: plan)).to be_valid
  end

  it 'is valid with a kind instead of a purchasable' do
    expect(build(:better_together_billing_purchase_requirement, :for_any_plan, dependent: extra)).to be_valid
  end

  it 'needs exactly one of a purchasable and a kind' do
    both = build(:better_together_billing_purchase_requirement, dependent: extra, prerequisite: plan, prerequisite_kind: 'plan')
    neither = build(:better_together_billing_purchase_requirement, dependent: extra, prerequisite: nil)

    expect([both, neither].map { |rule| error_keys(rule) }).to all(include(:one_prerequisite))
  end

  it 'refuses an unknown kind, how it is met and what happens at the end' do
    rule = build(:better_together_billing_purchase_requirement, :for_any_plan, dependent: extra, prerequisite_kind: 'nonsense',
                                                                               met_by: 'sometimes', on_prerequisite_end: 'explode')

    expect(rule).not_to be_valid
    expect(rule.errors.attribute_names).to include(:prerequisite_kind, :met_by, :on_prerequisite_end)
  end

  it 'refuses a dependent or prerequisite that is not a registered purchasable' do
    rule = build(:better_together_billing_purchase_requirement, dependent: extra, prerequisite: plan)
    rule.dependent_type = 'BetterTogether::Person'
    rule.prerequisite_type = 'BetterTogether::Person'

    expect(error_keys(rule)).to include(:not_purchasable)
  end

  it 'refuses a rule that needs itself' do
    expect(error_keys(build(:better_together_billing_purchase_requirement, dependent: plan, prerequisite: plan))).to include(:cannot_need_itself)
  end

  it 'refuses a rule that closes a loop' do
    other = create(:better_together_billing_plan, **cash)
    create(:better_together_billing_purchase_requirement, dependent: plan, prerequisite: other)

    expect(error_keys(build(:better_together_billing_purchase_requirement, dependent: other, prerequisite: plan))).to include(:cycle)
  end

  it 'refuses the same prerequisite, or the same kind, twice for one dependent' do
    create(:better_together_billing_purchase_requirement, dependent: extra, prerequisite: plan)
    create(:better_together_billing_purchase_requirement, :for_any_plan, dependent: extra)

    expect(build(:better_together_billing_purchase_requirement, dependent: extra, prerequisite: plan)).not_to be_valid
    expect(build(:better_together_billing_purchase_requirement, :for_any_plan, dependent: extra)).not_to be_valid
  end

  it 'answers how it is met and what happens to the dependent' do
    rule = build(:better_together_billing_purchase_requirement, met_by: 'holding', on_prerequisite_end: 'revoke')

    expect(rule).to have_attributes(holding?: true, in_order?: false, revokes?: true, kind?: false)
  end
end
