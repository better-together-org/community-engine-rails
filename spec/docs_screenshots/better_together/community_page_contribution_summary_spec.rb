# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for community page contribution summary', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for community page contribution and evidence summaries' do
    manager = create(:person, name: 'Community Page Evidence Manager')
    community = create(:better_together_community,
                       name: 'Community Page Evidence',
                       privacy: 'public',
                       creator: manager)

    page_record = create(:better_together_page,
                         community: community,
                         privacy: 'public',
                         published_at: 1.day.ago,
                         slug: "community-page-contribution-summary-#{SecureRandom.hex(4)}",
                         identifier: "community-page-contribution-summary-#{SecureRandom.hex(4)}",
                         protected: false)

    contributor = create(:better_together_person, name: 'Community Doc Maintainer')
    page_record.add_governed_contributor(contributor, role: 'editor')
    page_record.contributions.first.update!(details: {
                                              'github_handle' => 'community-docs',
                                              'github_sources' => [{ 'reference_key' => 'pull_request_1494' }]
                                            })
    create(:claim, claimable: page_record, statement: 'Community pages should show contribution and evidence summaries together.')
    create(:citation, citeable: page_record, reference_key: 'community_page_evidence', title: 'Community Page Evidence Citation')

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'community_page_contribution_summary',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'community_page_contribution_summary',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_path(community.slug, locale: I18n.default_locale)

      find('#pages-tab').click
      expect(page).to have_text(page_record.title, wait: 10)
      expect(page).to have_text('Contributors:')
      expect(page).to have_text('GitHub-linked')
      expect(page).to have_text('GitHub: @community-docs')
      expect(page).to have_text('Evidence:')
      expect(page).to have_link('Governance Bundle')
      expect(page).to have_link('CSL Export')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/community_page_contribution_summary.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/community_page_contribution_summary.png')
  end
end
