# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/platform_storage_tab_spec.rb
#
# Documents the Storage tab of the platform form and the storage configurations list with its
# health column and test connection button, desktop and mobile.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for platform storage', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }
  let!(:storage_configuration) do
    create(:better_together_storage_configuration, :s3_compatible, platform: host_platform, name: 'Garage bucket',
                                                                   health_status: 'ok', health_checked_at: Time.current)
  end
  let(:health_callouts) do
    [{ selector: '#platform-storage-health', title: 'Connection health', position: 'below',
       bullets: ['Result of the last connection test.'] }]
  end
  let(:list_callouts) do
    [{ selector: 'table', title: 'Health and test connection', position: 'above',
       bullets: ['Each row shows its last connection test.',
                 'Test connection writes, reads and deletes a probe file.'] }]
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    host_platform.update!(storage_configuration_id: storage_configuration.id)
    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def capture_storage(name, flow, callouts, &)
    metadata = { locale:, role: 'platform_manager', feature_set: 'platform_storage', flow:,
                 source_spec: self.class.metadata[:file_path] }
    BetterTogether::CapybaraScreenshotEngine.capture(name, device: :both, metadata:, callouts:, &)
  end

  [false, true].each do |annotated|
    it "captures the storage tab#{'_annotated' if annotated}" do
      capture_storage("platform_storage_tab#{'_annotated' if annotated}", 'platform_storage_tab', annotated ? health_callouts : []) do
        capybara_login_as_platform_manager
        visit edit_platform_path(host_platform, locale:)
        find('#platform-storage-tab').click
        expect(page).to have_css('#platform-storage.show.active', wait: 10)
        find('#platform-storage-summary').scroll_to(:center)
      end
    end

    it "captures the storage configurations list#{'_annotated' if annotated}" do
      capture_storage("platform_storage_configurations#{'_annotated' if annotated}", 'platform_storage_configurations',
                      annotated ? list_callouts : []) do
        capybara_login_as_platform_manager
        visit platform_storage_configurations_path(host_platform, locale:)
        expect(page).to have_css('table')
        find('table').scroll_to(:center)
      end
    end
  end
end
