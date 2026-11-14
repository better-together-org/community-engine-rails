# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for portrait video blocks', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) do
    configure_host_platform.tap do |platform|
      platform.update!(privacy: 'public', requires_invitation: false, allow_membership_requests: false)
    end
  end
  let!(:video_page) do
    create(:better_together_page, title: 'Vertical video', slug: 'vertical-video', identifier: 'vertical-video',
                                  platform: host_platform, privacy: 'public', published_at: 1.day.ago,
                                  protected: false).tap do |page_record|
      page_record.page_blocks.create!(block: create(:content_video_block, aspect_ratio: '9x16'), position: 0)
    end
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after { Current.platform = nil }

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'video_block_portrait', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def show_page
    capybara_login_as_platform_manager
    visit better_together.page_path(video_page.slug, locale: I18n.default_locale)
    scroll_to(find('.iframe-block--portrait'), align: :center)
  end

  it 'captures a vertical video narrowed and centred' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'video_block_portrait',
      device: :both,
      metadata: screenshot_metadata(flow: 'video_block_portrait'),
      callouts: [{ id: 'portrait_video', selector: '.iframe-block--portrait', title: 'Vertical video',
                   bullets: ['9:16 frame, centred, at most 360px wide.'] }],
      narrative: {
        title: 'Video block: vertical (9:16) videos',
        audience: %w[member content_editor developer],
        journey_step: 'As an editor, I embed a vertical video and it is not stretched across the page.',
        callouts: [{ id: 'portrait_video', title: 'Vertical video',
                     description: 'The 9x16 ratio keeps a vertical video narrow and centred.' }],
        accessibility_notes: 'Markup is unchanged apart from a modifier class on the figure.'
      }
    ) do
      show_page
      expect(page).to have_css('.iframe-block--portrait .ratio-9x16', wait: 10)
    end
  end

  it 'captures the unannotated vertical video' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'video_block_portrait_plain',
      device: :both,
      metadata: screenshot_metadata(flow: 'video_block_portrait_plain')
    ) do
      show_page
      expect(page).to have_css('.iframe-block--portrait .ratio-9x16', wait: 10)
    end
  end
end
