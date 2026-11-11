# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::Locality do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:external_platform) { create(:better_together_platform, :external) }

  it 'treats a local platform as local' do
    expect(described_class.local_owner?(create(:better_together_platform))).to be true
  end

  it 'treats an external platform as not local' do
    expect(described_class.local_owner?(external_platform)).to be false
  end

  it 'treats a person on a local platform as local' do
    expect(described_class.local_owner?(create(:better_together_person))).to be true
  end

  it 'treats a person and a community mirrored from an external platform as not local' do
    person = create(:better_together_person, platform: external_platform)
    community = create(:better_together_community, platform: external_platform)

    expect([described_class.local_owner?(person), described_class.local_owner?(community)]).to eq([false, false])
  end

  it 'treats nil as not local' do
    expect(described_class.local_owner?(nil)).to be false
  end
end
