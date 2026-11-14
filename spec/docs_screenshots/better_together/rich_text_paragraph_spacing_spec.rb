# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for rich text paragraph spacing', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:post_record) do
    create(:better_together_post, title: 'Spacing between paragraphs', platform: host_platform,
                                  privacy: 'public', published_at: 1.day.ago, creator: manager.person,
                                  content: '<p>Paragraphs written through the API, an import or a paste.</p>' \
                                           '<p>They are spaced like the blocks the editor writes.</p>' \
                                           '<p>Before this change they ran together.</p>')
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'rich_text_paragraph_spacing', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def show_post
    capybara_login_as_platform_manager
    visit better_together.post_path(post_record, locale: I18n.default_locale)
    scroll_to(find('.post-content'), align: :center)
  end

  it 'captures spaced paragraphs in rendered rich text' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'rich_text_paragraph_spacing',
      device: :both,
      metadata: screenshot_metadata(flow: 'rich_text_paragraph_spacing'),
      callouts: [{ id: 'rich_text', selector: '.post-content', title: 'Rendered rich text',
                   bullets: ['Paragraphs have a line of space between them.'] }],
      narrative: {
        title: 'Rich text: paragraph spacing',
        audience: %w[member content_editor developer],
        journey_step: 'As a reader, I see rich text spaced the way its author saw it in the editor.',
        callouts: [{ id: 'rich_text', title: 'Rendered rich text',
                     description: 'Direct paragraph children get the same 1em spacing as editor blocks.' }],
        accessibility_notes: 'Spacing only; no change to markup or reading order.'
      }
    ) do
      show_post
      expect(page).to have_css('.post-content .trix-content > p', count: 3)
    end
  end

  it 'captures the unannotated rendered rich text' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'rich_text_paragraph_spacing_plain',
      device: :both,
      metadata: screenshot_metadata(flow: 'rich_text_paragraph_spacing_plain')
    ) do
      show_post
      expect(page).to have_css('.post-content .trix-content > p', count: 3)
    end
  end
end
