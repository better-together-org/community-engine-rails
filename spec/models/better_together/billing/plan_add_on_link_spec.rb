# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PlanAddOn do
  include_context 'with entitlement fixtures'

  let(:attrs) { { platform: host_platform, processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:plan) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs) }
  let(:add_on) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, add_on: true) }

  it 'links an add-on to a primary plan it extends' do
    expect(described_class.new(plan:, add_on:)).to be_valid
  end

  it 'refuses a link whose add-on is not an add-on' do
    expect(described_class.new(plan:, add_on: plan)).not_to be_valid
  end

  it 'refuses a link to a plan that is itself an add-on' do
    expect(described_class.new(plan: add_on, add_on:)).not_to be_valid
  end

  it 'refuses the same pair twice' do
    described_class.create!(plan:, add_on:)

    expect(described_class.new(plan:, add_on:)).not_to be_valid
  end

  it 'finds the add-ons for a plan: named ones and those naming none' do
    named = add_on
    everywhere = create(:better_together_billing_plan, :unlinked, :one_time, **attrs, add_on: true)
    elsewhere = create(:better_together_billing_plan, :unlinked, :one_time, **attrs, add_on: true)
    other = create(:better_together_billing_plan, :unlinked, :one_time, **attrs)
    described_class.create!(plan:, add_on: named)
    described_class.create!(plan: other, add_on: elsewhere)

    expect(BetterTogether::Billing::Plan.add_ons_for(plan)).to contain_exactly(named, everywhere)
  end

  it 'drops its links when a plan stops being an add-on' do
    described_class.create!(plan:, add_on:)
    add_on.update!(add_on: false)

    expect(add_on.target_links.reload).to be_empty
  end
end
