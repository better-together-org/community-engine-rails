# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for community event evidence summary', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for community event evidence summaries' do
    manager = create(:person, name: 'Community Evidence Manager')
    community = create(:better_together_community,
                       name: 'Evidence Summary Community',
                       privacy: 'public',
                       creator: manager)

    event = create(:better_together_event,
                   name: 'Evidence Summary Event',
                   starts_at: 2.days.from_now,
                   ends_at: 2.days.from_now + 1.hour,
                   duration_minutes: 60,
                   creator: manager)

    create(:better_together_event_host, event:, host: community)
    create(:claim, claimable: event, statement: 'Community events should show evidence density.')
    create(:citation,
           citeable: event,
           reference_key: 'community_event_evidence',
           title: 'Community Event Evidence Citation',
           metadata: {
             'imported_from_reference_key' => 'review_notes',
             'imported_from_record_label' => 'Consensus Reviewer: Reviewer',
             'imported_from_citation_id' => 'source-citation-id'
           })

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'community_event_evidence_summary',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'community_event_evidence_summary',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.community_path(community.slug, locale: I18n.default_locale)

      find('#events-tab').click
      expect(page).to have_text('Evidence Summary Event', wait: 10)
      expect(page).to have_text('Evidence:')
      expect(page).to have_text('1 claim')
      expect(page).to have_text('1 citation')
      expect(page).to have_text('1 imported')
      expect(page).to have_link('Governance Bundle')
      expect(page).to have_link('CSL Export')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/community_event_evidence_summary.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/community_event_evidence_summary.png')
  end
end
