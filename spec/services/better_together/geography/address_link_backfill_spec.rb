# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::AddressLinkBackfill do
  let(:country) { create(:geography_country) }
  let(:state) { create(:geography_state, country:) }
  let(:address) { create(:address) }

  def place(address, record)
    create(:locatable_location, locatable: address, location: record)
  end

  it 'links an address to its resolved placements' do
    place(address, country)
    place(address, state)

    expect { described_class.call }.to change { address.reload.state_id }.from(nil).to(state.id)
    expect(address.reload.country_id).to eq(country.id)
  end

  it 'never overwrites an existing link' do
    chosen = create(:geography_country)
    address.update_columns(country_id: chosen.id) # rubocop:disable Rails/SkipsModelValidations
    place(address, country)

    described_class.call

    expect(address.reload.country_id).to eq(chosen.id)
  end

  it 'is idempotent and skips addresses with nothing resolved' do
    place(address, country)
    described_class.call

    expect(described_class.call).to eq(linked: 0)
  end
end
