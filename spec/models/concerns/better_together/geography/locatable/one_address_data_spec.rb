# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::Locatable::One, '#address_data=' do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:spec_json) do
    { line1: '5 Park Street', city_name: 'Corner Brook', state_province_name: 'Newfoundland and Labrador',
      postal_code: 'A2H 2W9', country_name: 'Canada' }.to_json
  end

  let(:record) { build(:better_together_event, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour) }

  it 'locates the record at a new public address', :aggregate_failures do
    record.address_data = spec_json
    record.save!

    address = record.reload.location.location
    expect(address).to be_a(BetterTogether::Address)
    expect(address).to have_attributes(line1: '5 Park Street', city_name: 'Corner Brook', privacy: 'public')
  end

  it 'names the place when the spec carries a name', :aggregate_failures do
    record.address_data = JSON.parse(spec_json).merge('name' => 'Rotary Arts Centre').to_json
    record.save!

    expect(record.reload.location.name).to eq('Rotary Arts Centre')
    expect(record.location.location).to have_attributes(line1: '5 Park Street')
  end

  it 'reuses an existing address for the next record', :aggregate_failures do
    record.update!(address_data: spec_json)
    other = create(:better_together_event, address_data: spec_json)

    expect(other.reload.location.location).to eq(record.location.location)
    expect(BetterTogether::Address.where(line1: '5 Park Street').count).to eq(1)
  end

  it 'clears the location when blank', :aggregate_failures do
    record.address_data = spec_json
    record.save!

    record.update!(address_data: nil)

    expect(record.reload.location).to be_nil
  end

  it 'rejects an address without line1', :aggregate_failures do
    record.address_data = { city_name: 'Corner Brook' }.to_json

    expect(record).not_to be_valid
    expect(record.errors[:address_data]).to be_present
  end

  it 'rejects invalid JSON', :aggregate_failures do
    record.address_data = '{nope'

    expect(record).not_to be_valid
    expect(record.errors[:address_data]).to be_present
  end
end
