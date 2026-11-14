# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for block attachments in rich text', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:photo) { Base64.strict_encode64(Rails.root.join('../../app/assets/images/cover_images/default_cover_image_community.jpg').binread) }
  let(:original_scrubber) { ActionText::ContentHelper.scrubber }
  let(:image_block) do
    BetterTogether::Content::Image.create!(platform: host_platform, privacy: 'public', identifier: "docs-att-img-#{SecureRandom.hex(3)}",
                                           creator: create(:better_together_person), media_data: photo,
                                           media_filename: 'harbour.jpg', caption: 'The harbour at dawn',
                                           attribution: 'A. Photographer')
  end
  let(:video_block) { create(:content_video_block, privacy: 'public', aspect_ratio: '9x16') }
  let(:post_record) do
    html = [image_block, video_block].map { |block| ActionText::Attachment.from_attachable(block).to_html }.join
    create(:better_together_post, title: 'Blocks inside a post', platform: host_platform, privacy: 'public',
                                  published_at: 1.day.ago, content: "<p>Photos and videos embed as blocks.</p>#{html}")
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    BetterTogether::ContentSecurity::AttachableRegistry.register('BetterTogether::Content::Image',
                                                                 'BetterTogether::Content::VideoBlock')
    original_scrubber
    ActionText::ContentHelper.scrubber = BetterTogether::ContentSecurity::VideoEmbedScrubber.new
    post_record
  end

  after do
    BetterTogether::ContentSecurity::AttachableRegistry.reset!
    ActionText::ContentHelper.scrubber = original_scrubber
    Current.platform = nil
  end

  def screenshot_metadata(flow:)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'block_attachments', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def wait_for_attached_image
    page.document.synchronize(10) do
      raise Capybara::ExpectationNotMet, 'image not loaded' unless page.evaluate_script(
        "document.querySelector('.post-content .attached-image img').complete"
      )
    end
  end

  def show_post
    capybara_login_as_platform_manager
    visit better_together.post_path(post_record, locale: I18n.default_locale)
    expect(page).to have_css('.post-content .attached-image img, .post-content .attached-video--portrait .ratio-9x16', minimum: 2, wait: 10)
    wait_for_attached_image
    scroll_to(find('.post-content .attached-image'), align: :center)
    sleep 0.5
  end

  it 'captures an image and a vertical video embedded in a post' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'block_attachments',
      device: :both,
      metadata: screenshot_metadata(flow: 'block_attachments'),
      callouts: [{ id: 'attached_image', selector: '.post-content .attached-image figcaption', title: 'Caption and credit',
                   bullets: ['Both come from the image block.'] }],
      narrative: {
        title: 'Rich text: image and video blocks as attachments',
        audience: %w[member content_editor developer],
        journey_step: 'As a reader, I see the photos and videos an author embedded in a post.',
        callouts: [{ id: 'attached_image', title: 'Image block',
                     description: 'The post stores a signed reference to the block, not pasted HTML.' }],
        accessibility_notes: 'Images carry alt text, falling back to the caption; the video iframe has a title.'
      }
    ) do
      show_post
      expect(page).to have_css('.post-content .attached-image')
    end
  end

  it 'captures the unannotated post with its attached blocks' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'block_attachments_plain',
      device: :both,
      metadata: screenshot_metadata(flow: 'block_attachments_plain')
    ) do
      show_post
      expect(page).to have_css('.post-content .attached-video')
    end
  end

  it 'captures the vertical video attachment' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'block_attachments_video',
      device: :both,
      metadata: screenshot_metadata(flow: 'block_attachments_video'),
      callouts: [{ id: 'attached_video', selector: '.post-content .attached-video', title: 'Video block',
                   bullets: ['Privacy-enhanced embed, narrow for a 9:16 video.'] }]
    ) do
      show_post
      scroll_to(find('.post-content .attached-video'), align: :center)
      expect(page).to have_css('.post-content .attached-video--portrait')
    end
  end
end
