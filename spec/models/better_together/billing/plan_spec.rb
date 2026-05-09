# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Plan do
  subject(:plan) { build('better_together/billing/plan') }

  it 'is valid with the factory defaults' do
    expect(plan).to be_valid
  end

  it 'requires a supported billing interval' do
    plan.billing_interval = 'week'

    expect(plan).not_to be_valid
    expect(plan.errors[:billing_interval]).to be_present
  end

  it 'reports recurring plans correctly' do
    expect(plan.recurring?).to be(true)

    plan.billing_interval = 'one_time'

    expect(plan.recurring?).to be(false)
  end

  it 'treats recurring plans as launch-ready for hosted billing' do
    expect(plan.launch_ready_for_hosted_billing?).to be(true)

    plan.billing_interval = 'one_time'

    expect(plan.launch_ready_for_hosted_billing?).to be(false)
  end

  it 'prefers participant-facing metadata for summaries and benefits' do
    expect(plan.participant_summary).to eq('Supports hosted participation and stewardship for this Better Together space.')
    expect(plan.participant_benefits).to eq(['Hosted access', 'Ongoing stewardship support'])
    expect(plan.beneficiary_label).to eq('Hosted access')
    expect(plan.hosted_access_level).to eq('Standard')
    expect(plan.support_tier).to eq('Community')
  end

  it 'falls back to description and owner types when participant metadata is missing' do
    plan.metadata = {}
    plan.description = 'Supports a community-hosted space.'

    expect(plan.participant_summary).to eq('Supports a community-hosted space.')
    expect(plan.participant_benefits).to eq([])
    expect(plan.beneficiary_label).to eq('Hosted access')
  end
end
