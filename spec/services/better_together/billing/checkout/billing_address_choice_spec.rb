# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Checkout::BillingAddressChoice do
  include BetterTogether::BillingAddressHelpers

  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, host: true) }
  let(:person) { create(:better_together_person) }
  let(:country) { create(:geography_country, iso_code: 'CA') }
  let(:state) { create(:geography_state, country:, iso_code: 'CA-NL') }

  def choose(**) = described_class.call(platform:, person:, **)

  it 'uses one of the person\'s own addresses' do
    address = create_billing_address_for(person)

    expect(choose(address_id: address.id).address).to eq(address)
  end

  it 'refuses someone else\'s address as not found', :aggregate_failures do
    other = create_billing_address_for(create(:better_together_person))
    result = choose(address_id: other.id)

    expect(result.address).to be_nil
    expect(result.error).to eq(:not_found)
  end

  it 'asks for an address when none is given' do
    expect(choose.error).to eq(:missing)
  end

  it 'refuses an address with no chosen country or state' do
    bare = person.contact_detail.addresses.create!(label: 'billing', physical: false, postal: true, privacy: 'private',
                                                   line1: '2 Elm', country_name: 'Canada', state_province_name: 'NL')

    expect(choose(address_id: bare.id).error).to eq(:incomplete)
  end

  it 'saves a new address with a chosen country and state, and can make it the default', :aggregate_failures do
    result = choose(address_id: 'new', make_default: true,
                    new_address: { line1: '3 Oak', postal_code: 'A1A 1A1', country_id: country.id, state_id: state.id })

    expect(result).to be_ok
    expect(result.address).to be_persisted
    expect(person.billing_default_addresses.billing.first.address).to eq(result.address)
  end

  it 'does not save a new address without a chosen state' do
    result = choose(address_id: 'new', new_address: { line1: '3 Oak', country_id: country.id })

    expect(result.error).to eq(:incomplete)
    expect(person.addresses.count).to eq(0)
  end

  it 'does not set a default when the address is refused' do
    choose(address_id: 'new', make_default: true, new_address: { line1: '3 Oak' })

    expect(person.billing_default_addresses.count).to eq(0)
  end
end
