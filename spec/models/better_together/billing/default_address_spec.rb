# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::DefaultAddress do
  include BetterTogether::BillingAddressHelpers

  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
  let(:person) { create(:better_together_person) }
  let(:address) { create_billing_address_for(person) }

  it 'makes an address the default and replaces it later', :aggregate_failures do
    first = described_class.set!(platform:, person:, address:, kind: 'billing')
    other = create_billing_address_for(person, settlement_name: 'Gander')
    again = described_class.set!(platform:, person:, address: other, kind: 'billing')

    expect(again.id).to eq(first.id)
    expect(person.billing_default_addresses.billing.pluck(:address_id)).to eq([other.id])
  end

  it 'keeps billing and shipping defaults apart' do
    described_class.set!(platform:, person:, address:, kind: 'billing')
    described_class.set!(platform:, person:, address:, kind: 'shipping')

    expect(person.billing_default_addresses.count).to eq(2)
  end

  it 'refuses an address that belongs to someone else' do
    stranger = create(:better_together_person)
    record = described_class.new(platform:, person: stranger, address:, kind: 'billing')

    expect(record).not_to be_valid
  end

  it 'refuses an unknown kind' do
    expect(described_class.new(platform:, person:, address:, kind: 'home')).not_to be_valid
  end
end
