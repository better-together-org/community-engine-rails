# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/address_geography_fields_spec.rb
#
# Assets land in docs/screenshots/{desktop,mobile}/address_geography_*.{png,json,narrative.yml}
#
# See skills/ce-pr-docs/SKILL.md for the full PR documentation workflow.

require 'rails_helper'

# The expectations run inside the capture block.
# rubocop:disable RSpec/NoExpectationExample
RSpec.describe 'Documentation screenshots for the address geography fields',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::AddressGeographyHelpers

  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:canada) { create(:geography_country, name: 'Canada') }
  let!(:newfoundland) { create(:geography_state, country: canada, name: 'Newfoundland and Labrador') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create(:geography_state, country: canada, name: 'Ontario')
    create(:geography_settlement, country: canada, state: newfoundland, name: 'Corner Brook')
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'address_geography', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def narrative(title:, step:, callouts:)
    { title:, audience: %w[platform_manager community_organizer developer], journey_step: step,
      callouts: callouts.map { |callout| callout.slice(:id, :title, :description) },
      accessibility_notes: 'Each select has a visible label and the typed-text row is a normal option, ' \
                           'so the whole form works from the keyboard.' }
  end

  def show_geography_row
    page.scroll_to(find(geography_panel), align: :center)
  end

  it 'captures the three geography selects in the new address panel' do
    callouts = [
      { id: 'geography_selects', selector: '#event_location_new_address .address-geography-fields',
        title: 'Country, state or province, city',
        description: 'Each one searches the geography records; pick one to link the address to it.',
        bullets: ['A chosen record fills the matching text column for you.'] }
    ]
    BetterTogether::CapybaraScreenshotEngine.capture(
      'address_geography_fields', device: :both, metadata: screenshot_metadata(flow: 'address_geography_fields'),
                                  callouts: callouts.map { |callout| callout.except(:description) },
                                  narrative: narrative(title: 'Address form: geography selects', callouts:,
                                                       step: 'I fill in where the address is by searching, not typing.')
    ) do
      capybara_login_as_platform_manager
      open_new_address_panel('124 Water Street')
      show_geography_row
    end
  end

  it 'captures the state list narrowed to the chosen country' do
    callouts = [
      { id: 'state_list', selector: '#event_location_new_address .address-geography-fields',
        title: 'States of the chosen country',
        description: 'After Canada is chosen the state search only offers its provinces.',
        bullets: ['Changing the country clears the state and city below it.'] }
    ]
    BetterTogether::CapybaraScreenshotEngine.capture(
      'address_geography_narrowed', device: :both, metadata: screenshot_metadata(flow: 'address_geography_narrowed'),
                                    callouts: callouts.map { |callout| callout.except(:description) },
                                    narrative: narrative(title: 'Address form: states narrowed by country', callouts:,
                                                         step: 'After choosing Canada I only see Canadian provinces.')
    ) do
      capybara_login_as_platform_manager
      open_new_address_panel('124 Water Street')
      choose_geography(:country, 'Canada')
      show_geography_row
      ss_id = open_geography_select(:state)
      expect(page).to have_css("div.ss-content[data-id='#{ss_id}'] .ss-option", text: 'Ontario', wait: 10)
    end
  end
end
# rubocop:enable RSpec/NoExpectationExample
