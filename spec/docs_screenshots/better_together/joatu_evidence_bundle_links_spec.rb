# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for JOATU evidence bundle links', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'
  end

  it 'captures desktop and mobile screenshots for JOATU evidence export links' do
    request_record = create(:better_together_joatu_request,
                            name: 'Evidence-linked JOATU request',
                            privacy: 'public')

    create(:claim, claimable: request_record, statement: 'Community exchanges need auditable evidence.')
    create(:citation,
           citeable: request_record,
           reference_key: 'joatu_exchange_evidence',
           title: 'JOATU Exchange Evidence',
           source_kind: 'pull_request',
           metadata: {
             'repository_name' => 'better-together-org/community-engine-rails',
             'pull_request_number' => 1494,
             'repository_path' => 'pull/1494'
           })

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'joatu_evidence_bundle_links',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        flow: 'joatu_evidence_bundle_links',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      capybara_login_as_platform_manager
      visit better_together.joatu_request_path(request_record, locale: I18n.default_locale)

      expect(page).to have_text('Evidence-linked JOATU request', wait: 10)
      expect(page).to have_link('Governance Bundle')
      expect(page).to have_link('CSL Export')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/joatu_evidence_bundle_links.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/joatu_evidence_bundle_links.png')
  end
end
