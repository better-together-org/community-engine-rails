# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformScoped, '.friendly_find_in_platform' do
  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let!(:host_event) { create(:better_together_event, platform: host_platform, identifier: 'open-night') }
  let!(:other_event) { create(:better_together_event, platform: other_platform, identifier: 'open-night') }

  it 'finds the record of the given platform', :aggregate_failures do
    expect(BetterTogether::Event.friendly_find_in_platform('open-night', platform: host_platform)).to eq(host_event)
    expect(BetterTogether::Event.friendly_find_in_platform('open-night', platform: other_platform)).to eq(other_event)
  end

  it 'finds by slug history inside the platform only', :aggregate_failures do
    other_event.update!(identifier: 'renamed-night')

    expect(BetterTogether::Event.friendly_find_in_platform('open-night', platform: host_platform)).to eq(host_event)
    expect(BetterTogether::Event.friendly_find_in_platform('renamed-night', platform: other_platform)).to eq(other_event)
    expect { BetterTogether::Event.friendly_find_in_platform('renamed-night', platform: host_platform) }
      .to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'does not find a record of another platform by id' do
    expect { BetterTogether::Event.friendly_find_in_platform(other_event.id, platform: host_platform) }
      .to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'uses the current platform when none is given' do
    Current.platform = other_platform

    expect(BetterTogether::Event.friendly_find_in_platform('open-night')).to eq(other_event)
  ensure
    Current.reset
  end
end
