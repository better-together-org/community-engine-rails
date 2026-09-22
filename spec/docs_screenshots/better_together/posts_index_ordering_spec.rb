# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for posts index ordering', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures desktop and mobile screenshots for posts index ordering evidence' do
    newer_index = nil
    older_index = nil

    create(
      :better_together_post,
      title: 'Evidence Older Post',
      content: 'This post should appear lower after the ordering fix.',
      privacy: 'public',
      published_at: 5.days.ago,
      created_at: 6.days.ago
    )
    create(
      :better_together_post,
      title: 'Evidence Newer Post',
      content: 'This post should appear first after the ordering fix.',
      privacy: 'public',
      published_at: 1.day.ago,
      created_at: 2.days.ago
    )

    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'posts_index_ordering',
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'guest',
        feature_set: 'posts',
        source_spec: self.class.metadata[:file_path]
      }
    ) do
      visit better_together.posts_path(locale: I18n.default_locale)

      expect(page).to have_text('Evidence Older Post')
      expect(page).to have_text('Evidence Newer Post')

      page_text = page.text
      newer_index = page_text.index('Evidence Newer Post')
      older_index = page_text.index('Evidence Older Post')
    end

    if ENV['EXPECT_OLDEST_FIRST'] == '1'
      expect(older_index).to be < newer_index
    else
      expect(newer_index).to be < older_index
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/posts_index_ordering.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/posts_index_ordering.png')
  end
end
