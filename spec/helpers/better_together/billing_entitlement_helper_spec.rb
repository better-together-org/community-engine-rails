# frozen_string_literal: true

require 'rails_helper'

# Storage amounts read as sizes (the way the usage meters show them), never as raw bytes.
RSpec.describe BetterTogether::BillingEntitlementHelper do
  let(:reading) { BetterTogether::Billing::Entitlements::Meter::Reading.new(limit: 5_368_709_120, used: 1_234_000_000) }

  it 'labels a storage meter in readable units', :aggregate_failures do
    label = helper.billing_meter_label(reading, 'media_storage')

    expect(label).to include('1.23 GB', '5.37 GB')
    expect(label).not_to include('5,368,709,120')
  end

  it 'keeps plain numbers for a quota that is not a size' do
    type = BetterTogether::Quotas::Type.all.find { |candidate| candidate.unit != :bytes }
    skip 'no non-size quota type registered' unless type

    expect(helper.billing_meter_label(reading, type.key)).to include('5,368,709,120')
  end

  it 'says a storage grant in readable units' do
    summary = helper.billing_quota_summary('quota_type' => 'media_storage', 'amount' => 5_368_709_120)

    expect(summary).to include('5.37 GB')
    expect(summary).not_to include('bytes')
  end

  it 'says no limit when there is none' do
    expect(helper.billing_meter_label(BetterTogether::Billing::Entitlements::Meter::Reading.new(limit: nil, used: 5), 'media_storage'))
      .to eq(I18n.t('better_together.billing.entitlements.meter_unlimited'))
  end
end
