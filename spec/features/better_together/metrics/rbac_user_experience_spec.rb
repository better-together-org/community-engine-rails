# frozen_string_literal: true

require 'rails_helper'

# NOTE: Most authorization, route protection, and file download testing has been migrated
# to faster, more reliable request specs for better performance:
# - spec/requests/better_together/metrics/rbac_simple_spec.rb
# - spec/requests/better_together/metrics/rbac_authorization_spec.rb
# - spec/requests/better_together/metrics/rbac_access_spec.rb
# - spec/requests/better_together/metrics/file_downloads_spec.rb
# - spec/requests/better_together/metrics/route_protection_spec.rb
#
# This feature spec now focuses ONLY on JavaScript-dependent functionality
# that requires actual browser simulation.

RSpec.describe 'Metrics RBAC JavaScript Workflows', :js do
  include BetterTogether::CapybaraFeatureHelpers

  let(:platform) { BetterTogether::Platform.find_by(host: true) }

  describe 'Interactive Form Workflows', :as_platform_manager do
    scenario 'Platform manager can interact with dynamic report generation forms' do
      visit better_together.new_metrics_page_view_report_path(locale: I18n.default_locale)

      expect(page).to have_content('New Page View Report')

      # Test complex form interactions requiring JavaScript/browser simulation
      within('div.container form') do
        # Test any dropdown selections, date pickers, or other form interactions
        click_button 'Create Report'
      end

      # Verify the complete workflow with redirects and success messages
      expect(page).to have_content('Report was successfully created')
    end
  end

  describe 'Complex Navigation Workflows', :as_platform_manager do
    scenario 'Platform manager can navigate between different report types through complex UI' do
      # Test complex navigation between different report types that might involve JavaScript
      visit better_together.metrics_link_click_reports_path(locale: I18n.default_locale)
      expect(page).to have_content('Link Click Reports')
      expect(page).to have_link('New Report')

      visit better_together.metrics_link_checker_reports_path(locale: I18n.default_locale)
      expect(page).to have_content('Link checker reports')
      expect(page).to have_link('New Report')
    end
  end
end
