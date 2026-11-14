# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for page breadcrumbs',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:callouts) do
    [
      { id: 'breadcrumb_trail', selector: '#breadcrumbs-list', title: 'Breadcrumb trail',
        bullets: ['Home, navigation group, then the current page.', 'Current page is plain text with aria-current.'] }
    ]
  end
  let(:narrative) do
    {
      title: 'Page breadcrumbs',
      audience: %w[content_editor developer],
      journey_step: 'As a visitor on a nested page, I see where it sits in the site and can step back up.',
      callouts: [
        { id: 'breadcrumb_trail', title: 'Breadcrumb trail',
          description: 'Built from the navigation hierarchy; also emitted as BreadcrumbList JSON-LD.' }
      ],
      accessibility_notes: 'nav with aria-label, ordered list, aria-current on the last item.'
    }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  it 'captures a page below a navigation group' do
    page_record = create(:better_together_page, slug: 'crumbs-docs', identifier: 'crumbs-docs', title: 'Our mission',
                                                protected: false, privacy: 'public', published_at: 1.day.ago)
    page_record.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Why we exist'), position: 0)
    area = BetterTogether::NavigationArea.find_by(identifier: 'platform-header') ||
           create(:better_together_navigation_area, identifier: 'platform-header', visible: true)
    group = create(:better_together_navigation_item, navigation_area: area, title: 'About the foray',
                                                     item_type: 'dropdown', url: '#about', linkable: nil,
                                                     visible: true, privacy: 'public', protected: false, position: 1)
    create(:better_together_navigation_item, navigation_area: area, title: 'Our mission', parent: group,
                                             linkable: page_record.reload, url: nil, visible: true,
                                             privacy: 'public', protected: false, position: 1)

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'page_breadcrumbs_nested', device: :both,
                                 metadata: screenshot_metadata(flow: 'page_breadcrumbs', role: 'anonymous'), callouts:, narrative:
    ) do
      visit better_together.render_page_path(path: 'crumbs-docs', locale: I18n.default_locale)

      expect(page).to have_css('#breadcrumbs-list li', count: 3)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/page_breadcrumbs_nested.png')
  end

  private

  def screenshot_metadata(flow:, role:)
    { locale: I18n.default_locale, role:, feature_set: 'page_breadcrumbs_review', flow:,
      source_spec: self.class.metadata[:file_path] }
  end
end
