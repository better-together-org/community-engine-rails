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

  def visit_gallery
    visit better_together.render_page_path(path: page_record.slug, locale:, **gallery_params)
    expect(page).to have_css('.image-gallery__image', minimum: 4)
    page.execute_script("document.querySelector('.image-gallery').scrollIntoView({block: 'center'})")
    wait_for_images
  end

  # Lazy images load only once in view and variants are built on first request; capture only loaded pictures.
  def wait_for_images
    loaded = 'Array.from(document.querySelectorAll(".image-gallery__image")).every(i => i.complete && i.naturalWidth > 0)'
    Timeout.timeout(60) { sleep 0.5 until page.evaluate_script(loaded) }
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
end
