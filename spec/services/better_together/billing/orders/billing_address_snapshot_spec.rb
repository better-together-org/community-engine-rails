# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Orders::BillingAddressSnapshot do
  include BetterTogether::BillingAddressHelpers

  let(:person) { create(:better_together_person) }
  let(:address) { create_billing_address_for(person) }

  it 'keeps the address as text with the ISO codes', :aggregate_failures do
    snapshot = described_class.new(address).to_h

    expect(snapshot).to include('line1' => '1 Main St', 'postal_code' => 'A2H 1A1', 'country_iso' => 'CA', 'region_code' => 'NL')
    expect(snapshot['city_name']).to eq('Corner Brook')
  end

  it 'taxes by the settlement when one is chosen' do
    expect(described_class.new(address).tax_address).to eq(settlement: address.settlement)
  end

  it 'falls back to the ISO codes without a settlement' do
    address.update_columns(settlement_id: nil) # rubocop:disable Rails/SkipsModelValidations

    expect(described_class.new(address.reload).tax_address).to eq(country_iso: 'CA', region_code: 'NL')
  end

  it 'is empty without an address', :aggregate_failures do
    expect(described_class.new(nil).to_h).to eq({})
    expect(described_class.new(nil).tax_address).to eq({})
  end
end
