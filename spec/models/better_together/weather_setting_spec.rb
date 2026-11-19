# frozen_string_literal: true

require 'rails_helper'

# The host-wide weather switch: env kill switch first, then the host platform setting (cached briefly).
RSpec.describe BetterTogether::Weather do
  let(:host_platform) { configure_host_platform }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  around do |example|
    original = BetterTogether.weather_enabled
    example.run
  ensure
    BetterTogether.weather_enabled = original
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_cache)
    host_platform
  end

  it 'is on by default' do
    expect(described_class.feature_enabled?).to be(true)
  end

  it 'follows the host platform setting' do
    host_platform.update!(weather_enabled: false)

    expect(described_class.feature_enabled?).to be(false)
  end

  it 'lets the env kill switch win over a setting that is on' do
    BetterTogether.weather_enabled = false

    expect([described_class.env_forced_off?, described_class.feature_enabled?]).to eq([true, false])
  end

  it 'caches the setting read', :aggregate_failures do
    described_class.feature_enabled?
    expect(memory_cache.exist?(described_class::SETTING_CACHE_KEY)).to be(true)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { described_class.feature_enabled? }
    expect(queries).to be_empty
  end

  it 'expires the cached setting when the host platform setting changes' do
    expect(described_class.feature_enabled?).to be(true)

    host_platform.reload.update!(weather_enabled: false)

    expect(described_class.feature_enabled?).to be(false)
  end

  it 'keeps the cache when another platform changes its own setting' do
    described_class.feature_enabled?
    create(:better_together_platform).update!(weather_enabled: false)

    expect(memory_cache.exist?(described_class::SETTING_CACHE_KEY)).to be(true)
  end

  it 'makes enabled? false while the switch is off even with an active location' do
    create(:weather_location)
    host_platform.update!(weather_enabled: false)

    expect(described_class.enabled?).to be(false)
  end
end
