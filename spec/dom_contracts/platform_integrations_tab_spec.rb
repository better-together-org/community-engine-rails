# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the Integrations tab of the platform form.
RSpec.describe 'Platform integrations tab DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:edit_path) { better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug) }
  let(:update_path) { better_together.platform_path(locale: I18n.default_locale, id: host_platform.slug) }
  let(:dom_id) { ActionView::RecordIdentifier.dom_id(host_platform) }

  context 'without registered settings' do
    it 'does not render the tab' do
      with_registered_platform_settings do
        BetterTogether::PlatformSettingsRegistry.reset!
        get edit_path

        expect(parsed_response.at_css('#platform-integrations-tab')).to be_nil
      end
    end
  end

  context 'with registered settings', :platform_settings do
    it 'renders the tab, its pane and one stable id per field' do # rubocop:disable RSpec/MultipleExpectations
      get edit_path
      doc = parsed_response

      expect(doc.at_css('#platform-integrations-tab')['aria-controls']).to eq('platform-integrations')
      expect(doc.at_css('#platform-integrations')['aria-labelledby']).to eq('platform-integrations-tab')
      %w[measurement_id anonymize_ip api_secret].each do |field|
        expect(doc.at_css("#platform-integrations ##{dom_id}_integration_sample_analytics_#{field}"))
          .to be_present, "missing #{field}"
      end
      expect(doc.at_css("##{dom_id}_integration_sample_analytics_api_secret")['type']).to eq('password')
    end

    it 'saves values, then shows them without echoing secrets' do # rubocop:disable RSpec/MultipleExpectations
      patch update_path, params: { platform: { integration_settings: { sample_analytics: {
        measurement_id: 'G-ABC123', anonymize_ip: '0', api_secret: 'hunter2'
      } } } }

      expect(response).to have_http_status(:see_other)
      host_platform.reload
      expect(host_platform.integration_setting('sample_analytics.measurement_id')).to eq('G-ABC123')
      expect(host_platform.integration_setting('sample_analytics.anonymize_ip')).to be(false)

      get edit_path
      expect(response.body).to include('G-ABC123')
      expect(response.body).not_to include('hunter2')
    end

    it 'rejects an invalid value and opens the Integrations tab with an error count' do # rubocop:disable RSpec/MultipleExpectations
      patch update_path, params: { platform: { integration_settings: { sample_analytics: { measurement_id: 'nope' } } } }
      doc = parsed_response

      expect(response).to have_http_status(:unprocessable_content)
      expect(doc.at_css('#platform-integrations-tab')['aria-selected']).to eq('true')
      expect(doc.at_css('#platform-integrations-tab-errors').text).to match(/\d/)
    end

    it 'names the environment variable when the host platform uses its fallback' do
      ENV['SAMPLE_ANALYTICS_ID'] = 'G-ENV9'
      get edit_path

      expect(parsed_response.at_css("##{dom_id}_integration_sample_analytics_measurement_id_env_note").text)
        .to include('SAMPLE_ANALYTICS_ID')
    ensure
      ENV.delete('SAMPLE_ANALYTICS_ID')
    end
  end
end
