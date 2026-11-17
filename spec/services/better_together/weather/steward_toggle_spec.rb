# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::StewardToggle do
  let(:host_platform) { configure_host_platform }
  let(:actor) { create(:better_together_person) }

  before { Current.host_platform = host_platform }

  it 'switches a source off and records who, what, before and after', :aggregate_failures do
    source = create(:weather_source, identifier: 'eccc-nl')

    result = described_class.call(source, enabled: 'false', actor:)

    expect(result).to be_changed
    expect(source.reload.enabled).to be(false)
    activity = BetterTogether::Activity.find_by!(trackable: source)
    expect(activity).to have_attributes(key: 'weather.source.toggled', owner: actor, privacy: 'private',
                                        platform_id: host_platform.id)
    expect(activity.parameters).to include('attribute' => 'enabled', 'before' => true, 'after' => false,
                                           'label' => 'eccc-nl')
  end

  it 'labels a location with its settlement and place code' do
    location = create(:weather_location)

    described_class.call(location, enabled: false, actor:)

    label = BetterTogether::Activity.find_by!(trackable: location).parameters['label']
    expect(label).to eq("#{location.settlement.name} (#{location.external_ref})")
  end

  it 'switches the host feature setting', :aggregate_failures do
    described_class.call(host_platform, enabled: false, actor:)

    expect(host_platform.reload.weather_enabled).to be(false)
    expect(BetterTogether::Activity.where(trackable: host_platform, key: 'weather.feature.toggled')).to exist
  end

  it 'records nothing when the value does not change' do
    source = create(:weather_source)

    expect { described_class.call(source, enabled: true, actor:) }.not_to change(BetterTogether::Activity, :count)
  end
end
