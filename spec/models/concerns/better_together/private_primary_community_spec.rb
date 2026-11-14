# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PrivatePrimaryCommunity do
  let(:probe_class) do
    Class.new(BetterTogether::Geography::Continent) do
      self.inheritance_column = nil

      def self.name = 'PrivatePrimaryCommunityProbe'

      include BetterTogether::PrivatePrimaryCommunity
    end
  end

  it 'leaves the primary community of a record without the concern at the record privacy' do
    continent = create(:better_together_geography_continent, privacy: 'public')

    expect(continent.community).to be_privacy_public
  end

  it 'sets the auto-created primary community private even when the record is public', :aggregate_failures do
    record = probe_class.create!(name: 'Probe land', identifier: 'probe-land', privacy: 'public')

    expect(record.privacy).to eq('public')
    expect(record.reload.community).to be_privacy_private
  end

  it 'keeps the community private across later saves' do
    record = probe_class.create!(name: 'Probe land', identifier: 'probe-land-2', privacy: 'public')
    record.update!(name: 'Probe land renamed')

    expect(record.reload.community).to be_privacy_private
  end
end
