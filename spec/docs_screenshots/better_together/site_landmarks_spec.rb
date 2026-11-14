# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for site landmarks',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let!(:static_page) do
    create(:better_together_page, slug: 'landmarks-docs', identifier: 'landmarks-docs', title: 'About the foray',
                                  protected: false, privacy: 'public', published_at: 1.day.ago)
  end
  let(:callouts) do
    [
      { id: 'main_nav', selector: 'nav#header-nav', title: 'Labelled main navigation',
        bullets: ['Inside the header landmark.', 'Named so screen readers can list it.'] },
      { id: 'skip_link', selector: '#skip-to-content', title: 'Skip link',
        bullets: ['First tab stop on every page.', 'Jumps past the header to the main content.'] }
    ]
  end
  let(:narrative) do
    {
      title: 'Site landmarks and skip link',
      audience: %w[content_editor developer],
      journey_step: 'As a keyboard user, I press Tab once to reveal the skip link and jump to the page content.',
      callouts: [
        { id: 'skip_link', title: 'Skip link',
          description: 'Visually hidden until focused; targets main#main-content.' },
        { id: 'main_nav', title: 'Labelled main navigation',
          description: 'nav#header-nav carries an aria-label; the navs are distinguishable landmarks.' }
      ],
      accessibility_notes: 'header, labelled navs, main#main-content; dropdowns expose aria-expanded and aria-haspopup.'
    }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    static_page.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Welcome'), position: 0)
  end

  after { Current.platform = nil }

  it 'captures the skip link in its focused state' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'site_landmarks_skip_link_focused',
      device: :both,
      metadata: screenshot_metadata(flow: 'site_landmarks', role: 'anonymous'),
      callouts:,
      narrative:
    ) do
      visit better_together.render_page_path(path: static_page.slug, locale: I18n.default_locale)
      page.send_keys(:tab)

      expect(page).to have_css('#skip-to-content:focus')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/site_landmarks_skip_link_focused.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/site_landmarks_skip_link_focused.png')
  end

  it 'captures the same view without callouts' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'site_landmarks_skip_link_plain',
      device: :both,
      metadata: screenshot_metadata(flow: 'site_landmarks_plain', role: 'anonymous')
    ) do
      visit better_together.render_page_path(path: static_page.slug, locale: I18n.default_locale)
      page.send_keys(:tab)

      expect(page).to have_css('#skip-to-content:focus')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/site_landmarks_skip_link_plain.png')
  end

  private

  def screenshot_metadata(flow:, role:)
    {
      locale: I18n.default_locale,
      role:,
      feature_set: 'site_landmarks_review',
      flow:,
      source_spec: self.class.metadata[:file_path]
    }
  end
end
