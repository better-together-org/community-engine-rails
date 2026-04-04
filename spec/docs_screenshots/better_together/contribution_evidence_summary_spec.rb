# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for contribution evidence summary', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for contribution evidence on a profile' do
    contributor = create(:person, name: 'Evidence Summary Contributor')
    page_record = create(:better_together_page,
                         slug: "contribution-evidence-summary-#{SecureRandom.hex(4)}",
                         identifier: "contribution-evidence-summary-#{SecureRandom.hex(4)}",
                         protected: false)

    BetterTogether::Authorship.create!(
      authorable: page_record,
      author: contributor,
      role: 'reviewer',
      contribution_type: 'documentation'
    )

    create(:claim, claimable: page_record, statement: 'Traceable evidence improves accountable publishing.')
    create(:citation,
           citeable: page_record,
           reference_key: 'local_evidence_summary',
           title: 'Local Evidence Summary Citation',
           metadata: {
             'imported_from_reference_key' => 'review_notes',
             'imported_from_record_label' => 'Consensus Reviewer: Reviewer',
             'imported_from_citation_id' => 'source-citation-id'
           })

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'contribution_evidence_summary',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'contribution_evidence_summary',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.person_path(contributor, locale: I18n.default_locale)

      expect(page).to have_text('Contributions', wait: 10)
      click_link 'Contributions'
      expect(page).to have_text('Evidence:')
      expect(page).to have_text('1 claim')
      expect(page).to have_text('1 citation')
      expect(page).to have_text('1 imported')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/contribution_evidence_summary.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/contribution_evidence_summary.png')
  end
end
