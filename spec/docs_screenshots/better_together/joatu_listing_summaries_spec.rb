# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for JOATU listing summaries', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for JOATU listing contribution and evidence summaries' do
    manager = create(:person, name: 'JOATU Listing Manager')
    request_record = create(:better_together_joatu_request,
                            name: 'Evidence-rich JOATU request',
                            creator: manager,
                            privacy: 'public')
    request_record.add_governed_contributor(manager, role: 'reviewer')
    request_record.contributions.first.update!(details: {
                                                 'github_handle' => 'joatu-listing-reviewer',
                                                 'github_sources' => [{ 'reference_key' => 'pull_request_1494' }]
                                               })
    create(:claim, claimable: request_record, statement: 'JOATU listings should expose contribution and evidence summaries.')
    create(:citation,
           citeable: request_record,
           reference_key: 'joatu_listing_summary',
           title: 'JOATU Listing Summary')

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'joatu_listing_summaries',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'joatu_listing_summaries',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.joatu_requests_path(locale: I18n.default_locale)

      expect(page).to have_text('Evidence-rich JOATU request', wait: 10)
      expect(page).to have_text('Contributors:')
      expect(page).to have_text('GitHub-linked')
      expect(page).to have_text('Evidence:')
      expect(page).to have_link('Governance Bundle')
      expect(page).to have_link('CSL Export')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/joatu_listing_summaries.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/joatu_listing_summaries.png')
  end
end
