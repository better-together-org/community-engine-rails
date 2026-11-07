# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/category_color_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/category_color.{png,json,narrative.yml}

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the category colour field',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  it 'captures the colour field on the category form' do
    category = create(:event_category, name: 'Regular Council Meeting', icon: 'fas fa-landmark', color: '#0072B2')
    callouts = [{ id: 'color', selector: '#category_color', title: 'Colour',
                  bullets: ['A six digit hex value such as #0072B2, or empty for none.',
                            'Text on the colour is chosen for readable contrast.'] }]
    narrative = { title: 'Category colour', audience: %w[host_admin],
                  journey_step: 'As a platform manager, I can give a category a colour.',
                  callouts: [{ id: 'color', title: 'Colour', description: 'Used for chips and badges of the category.' }],
                  accessibility_notes: 'Colour is never the only cue, the category name and icon are shown too.' }
    metadata = { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'category_color',
                 flow: 'category_color', source_spec: self.class.metadata[:file_path] }

    BetterTogether::CapybaraScreenshotEngine.capture('category_color', device: :both, metadata:, narrative:, callouts:) do
      capybara_login_as_platform_manager
      visit "/#{I18n.default_locale}/host/categories/#{category.slug}/edit"
      expect(page).to have_css('#category_color')
      page.execute_script("document.querySelector('#category_color').scrollIntoView({block: 'center'})")
    end
  end
end
