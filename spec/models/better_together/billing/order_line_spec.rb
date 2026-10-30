# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OrderLine do
  include_context 'with orders fixtures'

  let(:order) { create(:better_together_billing_order) }

  def line(**attrs)
    build(:better_together_billing_order_line, order:, purchasable: plan, **attrs)
  end

  it 'is valid with what was bought, how many and at what price' do
    expect(line).to be_valid
  end

  it 'totals its quantity at its unit price' do
    expect(line(quantity: 3, unit_amount_cents: 1500).total_cents).to eq(4500)
  end

  it 'needs a positive whole quantity and a price that is not negative' do
    expect(line(quantity: 0)).not_to be_valid
    expect(line(quantity: 1.5)).not_to be_valid
    expect(line(unit_amount_cents: -1)).not_to be_valid
    expect(line(unit_amount_cents: 0)).to be_valid
  end

  it 'accepts only a purchasable type that opted in, never resolving the name' do
    bad = line
    bad.assign_attributes(purchasable_type: 'Kernel', purchasable_id: SecureRandom.uuid)

    expect(bad).not_to be_valid
    expect(bad.errors.details[:purchasable_type]).to include(a_hash_including(error: :inclusion))
  end

  it 'takes its order\'s platform, never the request\'s' do
    Current.platform = create(:better_together_platform)
    built = order.lines.build(purchasable: plan, description: 'A', quantity: 1, unit_amount_cents: 1, currency: 'USD')

    expect(built).to be_valid
    expect(built.platform_id).to eq(order.platform_id)
  ensure
    Current.platform = nil
  end

  it 'must be on its order\'s platform and in its currency' do
    other = create(:better_together_platform)

    expect(line(platform_id: other.id)).not_to be_valid
    expect(line(currency: 'CAD')).not_to be_valid
  end

  it 'keeps the price it was ordered at when the plan changes later' do
    saved = line(unit_amount_cents: 4500, description: 'Hosted').tap(&:save!)

    plan.update_columns(amount_cents: 9900, name: 'Renamed') # rubocop:disable Rails/SkipsModelValidations

    expect(saved.reload).to have_attributes(unit_amount_cents: 4500, description: 'Hosted')
  end

  it 'cannot point at an order of another platform, at the database level' do
    other = create(:better_together_platform)

    expect { line(platform_id: other.id).save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end
end
