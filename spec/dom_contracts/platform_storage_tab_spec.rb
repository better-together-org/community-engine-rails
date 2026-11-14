# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the platform form Storage tab and the storage configurations health column.
# Docs screenshot specs target these identifiers.
RSpec.describe 'Platform storage tab DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:edit_path) { better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug) }
  let!(:config) { create(:better_together_storage_configuration, platform: host_platform) }

  it 'renders the storage pill and pane with matching aria wiring' do # rubocop:disable RSpec/MultipleExpectations
    get edit_path
    doc = parsed_response

    expect(doc.at_css('#platform-storage-tab')['aria-controls']).to eq('platform-storage')
    expect(doc.at_css('#platform-storage')['aria-labelledby']).to eq('platform-storage-tab')
    expect(doc.at_css('#platform-storage #platform-storage-manage')).to be_present
  end

  it 'shows the active configuration and its health' do # rubocop:disable RSpec/MultipleExpectations
    host_platform.update!(storage_configuration_id: config.id)
    config.update_columns(health_status: 'ok', health_checked_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    get edit_path
    doc = parsed_response

    expect(doc.at_css('#platform-storage-source').text).to include(config.name)
    expect(doc.at_css('#platform-storage-health .badge')).to be_present
  end

  it 'exposes health cell and test connection button ids on the configurations list' do # rubocop:disable RSpec/MultipleExpectations
    config.update_columns(service_type: 's3_compatible') # rubocop:disable Rails/SkipsModelValidations
    get better_together.platform_storage_configurations_path(host_platform, locale: I18n.default_locale)
    doc = parsed_response
    dom_id = ActionView::RecordIdentifier.dom_id(config, :health)

    expect(doc.at_css("##{dom_id}")).to be_present
    expect(doc.at_css("##{ActionView::RecordIdentifier.dom_id(config, :test_connection)}")).to be_present
  end
end
