# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Community, '#address_spec=' do
  include RequestSpecHelper

  before { configure_host_platform }

  let(:spec_json) { { line1: '5 Park Street', city_name: 'Corner Brook', country_name: 'Canada' }.to_json }
  let(:community) { create(:better_together_community) }

  it 'locates the community at a street address', :aggregate_failures do
    community.update!(address_spec: spec_json)

    expect(community.reload.location.location).to have_attributes(line1: '5 Park Street', privacy: 'public')
  end

  it 'clears the location when blank' do
    community.update!(address_spec: spec_json)
    community.update!(address_spec: nil)

    expect(community.reload.location).to be_nil
  end
end
