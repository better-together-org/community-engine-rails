# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/image_gallery_spec.rb'
RSpec.describe 'Documentation screenshots for the image gallery', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers
  include ImageGalleryHelpers

  let(:locale) { I18n.default_locale }
  let(:page_record) { @page_record ||= build_gallery_page } # rubocop:disable RSpec/InstanceVariable
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', host_url: 'http://www.example.com') }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    page_record
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale:, role: 'visitor', feature_set: 'image_gallery', flow:, source_spec: self.class.metadata[:file_path] }
  end

  def visit_gallery(lightbox: false)
    visit better_together.render_page_path(path: page_record.slug, locale:, **gallery_params('grid', lightbox:))
    expect(page).to have_css('.image-gallery__image', minimum: 4)
    page.execute_script("document.querySelector('.image-gallery').scrollIntoView({block: 'center'})")
    wait_for_images
  end

  # Lazy images load only once in view and variants are built on first request; capture only loaded pictures.
  def wait_for_images
    wait_for_script('Array.from(document.querySelectorAll(".image-gallery__image")).every(i => i.complete && i.naturalWidth > 0)')
  end

  def wait_for_script(script)
    Timeout.timeout(60) { sleep 0.3 until page.evaluate_script(script) }
  end

  it 'captures the annotated gallery' do
    bullets = ['Each image is a figure with its own alt text and caption.', 'Lazy loaded, with reserved size.']
    paths = BetterTogether::CapybaraScreenshotEngine.capture(
      'image_gallery', device: :both, metadata: metadata('annotated'),
                       callouts: [{ id: 'gallery', selector: '.image-gallery__list', title: 'Gallery grid', bullets: }],
                       narrative: { title: 'Image gallery', audience: %w[visitor developer],
                                    journey_step: 'As a visitor, I browse the photos on a page.',
                                    callouts: [{ id: 'gallery', title: 'Gallery grid',
                                                 description: bullets.join(' ') }],
                                    accessibility_notes: 'A labelled section holding a list of figures.' }
    ) { visit_gallery }
    expect(paths.values).to all(satisfy { |path| File.exist?(path) })
  end

  it 'captures the plain gallery' do
    paths = BetterTogether::CapybaraScreenshotEngine.capture(
      'image_gallery_plain', device: :both, metadata: metadata('plain')
    ) { visit_gallery }
    expect(paths.values).to all(satisfy { |path| File.exist?(path) })
  end

  it 'captures the lightbox viewer' do
    bullets = ['Opens from any thumbnail; arrow keys, swipe and buttons move between images.',
               'Escape closes it and focus returns to the thumbnail.']
    paths = BetterTogether::CapybaraScreenshotEngine.capture(
      'image_gallery_lightbox', device: :both, metadata: metadata('lightbox'),
                                callouts: [{ id: 'viewer', selector: '.image-gallery__modal-image',
                                             title: 'Lightbox viewer', bullets: }],
                                narrative: { title: 'Image gallery lightbox', audience: %w[visitor developer],
                                             journey_step: 'As a visitor, I view a photo at full size.',
                                             callouts: [{ id: 'viewer', title: 'Lightbox viewer',
                                                          description: bullets.join(' ') }],
                                             accessibility_notes: 'A labelled dialog with a polite live counter.' }
    ) { open_lightbox }
    expect(paths.values).to all(satisfy { |path| File.exist?(path) })
  end

  it 'captures the plain lightbox viewer' do
    paths = BetterTogether::CapybaraScreenshotEngine.capture(
      'image_gallery_lightbox_plain', device: :both, metadata: metadata('lightbox_plain')
    ) { open_lightbox }
    expect(paths.values).to all(satisfy { |path| File.exist?(path) })
  end

  def open_lightbox
    visit_gallery(lightbox: true)
    first('.image-gallery__open').click
    expect(page).to have_css('.image-gallery__modal.show')
    wait_for_script('document.querySelector(".image-gallery__modal-image").naturalWidth > 0')
    # The fade-in and backdrop finish after the show class appears; capture only the settled state.
    wait_for_script('getComputedStyle(document.querySelector(".image-gallery__modal")).opacity === "1"')
    wait_for_script('getComputedStyle(document.querySelector(".modal-backdrop")).opacity === "0.5"')
  end
end
