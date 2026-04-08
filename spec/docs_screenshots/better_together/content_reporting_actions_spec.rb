# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for content reporting actions',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let!(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', host_url: 'http://www.example.com')
    end
  end
  let!(:post_record) do
    create(
      :better_together_post,
      title: 'Community Garden Update',
      author: create(:better_together_person),
      platform: host_platform,
      privacy: 'public',
      published_at: 1.day.ago
    )
  end
  let!(:page_record) do
    create(:better_together_page,
           title: 'Shared Kitchen Guide',
           slug: 'shared-kitchen-guide',
           identifier: 'shared-kitchen-guide',
           protected: false,
           published_at: 1.day.ago)
  end
  let!(:page_block_record) do
    create(
      :better_together_content_rich_text,
      content_html: '<h3>Kitchen safety note</h3><p>Keep walkways clear for mobility devices.</p>'
    )
  end
  let!(:community_record) { create(:better_together_community, name: 'Harbour Neighbours', privacy: 'public') }
  let!(:report_record) do
    create(:report, reporter: user.person, reportable: page_record, reason: 'Needs a closer review').tap do |report|
      report.safety_case.notes.create!(
        author: create(:better_together_person, name: 'Safety Reviewer'),
        body: 'Thank you. We are reviewing the report and may ask for more context.',
        visibility: 'participant_visible'
      )
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    page_record.page_blocks.find_or_create_by!(block: page_block_record) do |page_block|
      page_block.position = 0
    end
  end

  after do
    Current.platform = nil
  end

  it 'captures the report action from a published post' do
    result = capture_docs_screenshot(
      'content_reporting_actions_post_menu',
      flow: 'post_content_actions',
      callouts: [
        {
          selector: '.bt-content-actions__menu',
          title: 'Report entry stays within the shared actions surface',
          bullets: [
            'A single accessible menu opens from the ellipsis trigger instead of scattering report buttons across the page.',
            'The safety-report entry can be reused alongside future actions like correction suggestions or citation requests.',
            'The action remains reachable directly from the content surface in no more than a few clicks.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.post_path(post_record, locale:)

      expect(page).to have_text('Community Garden Update')
      open_first_content_actions_menu
      expect(page).to have_link('Report safety issue')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_reporting_actions_post_menu.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_reporting_actions_post_menu.png')
  end

  it 'captures the report action from a community surface' do
    result = capture_docs_screenshot(
      'content_reporting_actions_community_menu',
      flow: 'community_content_actions',
      callouts: [
        {
          selector: '.bt-content-actions__menu',
          title: 'Community reporting uses the same shared interface',
          bullets: [
            'People encounter the same reporting pattern across community and content surfaces.',
            'The shared contract keeps extension points in one predictable place for future governance actions.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.community_path(community_record, locale:)

      expect(page).to have_text('Harbour Neighbours')
      open_first_content_actions_menu
      expect(page).to have_link('Report safety issue')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_reporting_actions_community_menu.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_reporting_actions_community_menu.png')
  end

  it 'captures the report form with contextual record details' do
    result = capture_docs_screenshot(
      'content_reporting_actions_report_form',
      flow: 'report_form_context',
      callouts: [
        {
          selector: '.alert.alert-light.border',
          avoid_container_selector: '.alert.alert-light.border',
          title: 'The report form keeps the record context visible',
          bullets: [
            'The report stays anchored to the specific page, post, or community the person started from.',
            'This context card gives reporters confidence that they are flagging the right record.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.new_report_path(
        locale:,
        reportable_type: 'BetterTogether::Page',
        reportable_id: page_record.id
      )

      expect(page).to have_text('Report a safety concern')
      expect(page).to have_text('Shared Kitchen Guide')
      expect(page).to have_text('Reporting')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_reporting_actions_report_form.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_reporting_actions_report_form.png')
  end

  it 'captures the report action from an individual content block' do
    result = capture_docs_screenshot(
      'content_reporting_actions_block_menu',
      flow: 'block_content_actions',
      callouts: [
        {
          selector: '.bt-content-block__actions',
          avoid_container_selector: '.bt-content-block__actions',
          title: 'Each reportable block can surface its own actions',
          bullets: [
            'The shared block wrapper keeps actions attached to the exact section a person wants reviewed.',
            <<~TEXT.squish,
              Host apps can still add their own block controls through the existing
              extra-block-components seam without replacing the shared CE structure.
            TEXT
            'The same menu can later grow into contribution actions such as correction requests or translation suggestions.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.render_page_path(page_record.slug, locale:)

      expect(page).to have_text('Shared Kitchen Guide')
      expect(page).to have_text('Kitchen safety note')
      open_first_content_actions_menu(within: '.bt-content-block__actions')
      expect(page).to have_link('Report safety issue')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_reporting_actions_block_menu.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_reporting_actions_block_menu.png')
  end

  it 'captures the report detail follow-up and appeal surface' do
    result = capture_docs_screenshot(
      'content_reporting_actions_followup',
      flow: 'report_followup',
      callouts: [
        {
          selector: '#report-followup-help',
          avoid_container_selector: '.card.shadow-sm.border-0.mt-4',
          title: 'People can add follow-up evidence or appeal context in place',
          bullets: [
            'Participant-visible notes preserve the conversation history on the report itself.',
            'Authenticated follow-up gives affected people a supported path to contest or clarify a decision.'
          ]
        }
      ]
    ) do
      capybara_login_as_user
      visit better_together.report_path(report_record, locale:)

      expect(page).to have_text('More information or appeal')
      expect(page).to have_text('Safety Reviewer')
      expect(page).to have_button('Add follow-up')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/content_reporting_actions_followup.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/content_reporting_actions_followup.png')
  end

  private

  def capture_docs_screenshot(name, flow:, callouts: [], &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale:,
        role: 'user',
        feature_set: 'content_reporting_actions',
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      &
    )
  end

  def open_first_content_actions_menu(within: nil)
    scope = within.present? ? find(within) : page

    scope.find('summary.bt-content-actions__trigger', match: :first).click
    expect(page).to have_css('details.bt-content-actions[open]')
  end
end
