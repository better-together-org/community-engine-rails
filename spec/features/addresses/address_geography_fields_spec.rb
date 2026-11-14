# frozen_string_literal: true

require 'rails_helper'

# The cascading geography selects of the address form, driven through the event form's inline new-address panel.
RSpec.describe 'Address geography fields', :as_platform_manager, :js, retry: 0 do
  include BetterTogether::AddressGeographyHelpers

  let!(:canada) { create(:geography_country, name: 'Canada') }
  let!(:newfoundland) { create(:geography_state, country: canada, name: 'Newfoundland and Labrador') }
  let!(:ontario) { create(:geography_state, country: canada, name: 'Ontario') }
  let!(:other_country) { create(:geography_country, name: 'Elsewhere') }

  it 'sets the id and name fields when a record is picked' do
    open_new_address_panel
    choose_geography(:country, 'Canada')

    expect(geography_hidden(:country, 'Id')).to eq(canada.id)
    expect(geography_hidden(:country, 'Name')).to eq('Canada')
  end

  it 'clears the levels below when the country changes' do
    open_new_address_panel
    choose_geography(:country, 'Canada')
    choose_geography(:state, 'Ontario')
    expect(geography_hidden(:state, 'Id')).to eq(ontario.id)

    choose_geography(:country, 'Elsewhere')

    expect(geography_hidden(:state, 'Id')).to be_blank
    expect(geography_hidden(:state, 'Name')).to be_blank
  end

  it 'keeps typed text in the string column when no record is chosen' do
    open_new_address_panel
    ss_id = open_geography_select(:settlement)
    within("div.ss-content[data-id='#{ss_id}']", visible: :all) { find('.ss-search input').set('Tiny Cove') }
    find("div.ss-content[data-id='#{ss_id}'] .ss-option.ss-create-option--simple", wait: 10).click

    expect(geography_hidden(:settlement, 'Id')).to be_blank
    expect(geography_hidden(:settlement, 'Name')).to eq('Tiny Cove')
  end
end
