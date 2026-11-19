# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/image_gallery_block_spec.rb'
RSpec.describe 'Documentation screenshots for the image gallery block', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:token) { SecureRandom.hex(4) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', host_url: 'http://www.example.com') }
  end
  let(:images) do
    ImageGalleryHelpers::GALLERY_FILES.each_with_index.map do |file, index|
      create(:better_together_content_image, identifier: "gallery-block-shot-#{token}-#{index}", privacy: 'public',
                                             alt_text: "Harbour view #{index + 1}",
                                             caption: "Harbour caption #{index + 1}").tap do |image|
        image.media.attach(io: File.open(BetterTogether::Engine.root.join("app/assets/images/better_together/#{file}")),
                           filename: file, content_type: 'image/jpeg')
        image.media.blob.analyze
      end
    end
  end
  let(:slug) { "gallery-block-#{token}" }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    block = create(:content_image_gallery_block, image_ids: images.map(&:id).to_json, heading_en: 'Harbour photos')
    create(:better_together_page, title: 'Harbour', slug:, privacy: 'public', published_at: 1.day.ago,
                                  platform: host_platform, show_title: true).page_blocks.create!(block:, position: 0)
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'visitor', feature_set: 'image_gallery_block', flow:, source_spec: self.class.metadata[:file_path] }
  end

  def visit_block
    visit better_together.render_page_path(path: slug, locale:)
    expect(page).to have_css('.image-gallery-block .image-gallery__item', count: 4)
    page.execute_script(<<~JS)
      document.querySelectorAll('.image-gallery img').forEach(i => { i.loading = 'eager' })
      document.querySelector('.image-gallery-block').scrollIntoView({block: 'center'})
    JS
    sleep 1
  end

  it 'captures the annotated block' do # rubocop:disable RSpec/NoExpectationExample
    bullets = ['The heading and image order come from the block.', 'Each thumbnail opens the viewer.']
    BetterTogether::CapybaraScreenshotEngine.capture(
      'image_gallery_block', device: :both, metadata: metadata('annotated'),
                             callouts: [{ id: 'gallery', selector: '.image-gallery-block', title: 'Gallery',
                                          bullets: }],
                             narrative: { title: 'Image gallery block', audience: %w[visitor editor],
                                          journey_step: 'As a visitor, I browse a set of photos on a page.',
                                          callouts: [{ id: 'gallery', title: 'Gallery',
                                                       description: bullets.join(' ') }],
                                          accessibility_notes: 'Thumbnails are buttons with labels; the viewer is a dialog.' }
    ) { visit_block }
  end

  it 'captures the plain block' do # rubocop:disable RSpec/NoExpectationExample
    BetterTogether::CapybaraScreenshotEngine.capture(
      'image_gallery_block_plain', device: :both, metadata: metadata('plain')
    ) { visit_block }
  end
end
