# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform, :platform_settings do
  let(:host) { described_class.find_by(host: true) || create(:better_together_platform, :host) }
  let(:other) { create(:better_together_platform) }

  it 'stores registered settings per platform and drops unregistered keys' do # rubocop:disable RSpec/MultipleExpectations
    host.integration_settings = { 'sample_analytics' => { 'measurement_id' => 'G-HOST1', 'evil' => 'x' },
                                  'unknown' => { 'a' => 'b' } }
    other.integration_settings = { 'sample_analytics' => { 'measurement_id' => 'G-OTHER2' } }

    expect(host.integration_setting('sample_analytics.measurement_id')).to eq('G-HOST1')
    expect(other.integration_setting('sample_analytics.measurement_id')).to eq('G-OTHER2')
    expect(host.integration_settings.keys).to eq(['sample_analytics'])
    expect(host.integration_settings['sample_analytics'].keys).to eq(['measurement_id'])
  end

  it 'casts booleans and falls back to the declared default' do # rubocop:disable RSpec/MultipleExpectations
    expect(other.integration_setting('sample_analytics.anonymize_ip')).to be(true)

    other.integration_settings = { 'sample_analytics' => { 'anonymize_ip' => '0' } }

    expect(other.integration_setting('sample_analytics.anonymize_ip')).to be(false)
  end

  it 'adds validation errors for invalid values' do
    other.integration_settings = { 'sample_analytics' => { 'measurement_id' => 'bad id' } }

    expect(other).not_to be_valid
    expect(other.errors[:integration_settings].join).to include('Measurement ID')
  end

  describe 'environment fallback' do
    around do |example|
      ENV['SAMPLE_ANALYTICS_ID'] = 'G-FROMENV'
      example.run
    ensure
      ENV.delete('SAMPLE_ANALYTICS_ID')
    end

    it 'applies to the host platform only' do # rubocop:disable RSpec/MultipleExpectations
      expect(host.integration_setting('sample_analytics.measurement_id')).to eq('G-FROMENV')
      expect(host.integration_setting_source('sample_analytics.measurement_id')).to eq(:env)
      expect(other.integration_setting('sample_analytics.measurement_id')).to be_nil
      expect(other.integration_setting_source('sample_analytics.measurement_id')).to eq(:default)
    end

    it 'lets a stored host value win' do # rubocop:disable RSpec/MultipleExpectations
      host.integration_settings = { 'sample_analytics' => { 'measurement_id' => 'G-STORED' } }

      expect(host.integration_setting('sample_analytics.measurement_id')).to eq('G-STORED')
      expect(host.integration_setting_source('sample_analytics.measurement_id')).to eq(:platform)
    end
  end

  it 'keeps a stored secret when the submitted value is blank' do
    other.integration_settings = { 'sample_analytics' => { 'api_secret' => 's3cret' } }
    other.integration_settings = { 'sample_analytics' => { 'api_secret' => '' } }

    expect(other.integration_setting('sample_analytics.api_secret')).to eq('s3cret')
  end
end
