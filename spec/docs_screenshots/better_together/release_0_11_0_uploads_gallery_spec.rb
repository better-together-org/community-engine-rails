# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for 0.11.0 uploads and image library',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:creator) { BetterTogether::User.find_by!(email: 'manager@example.test').person }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
    seed_release_uploads!
  end

  after do
    Current.platform = nil
  end

  it 'captures uploads gallery and block image library release evidence' do
    capture_uploads_gallery if ENV['CAPTURE_UPLOADS_GALLERY'] == '1'
    capture_block_image_library if ENV['CAPTURE_BLOCK_IMAGE_LIBRARY'] == '1'

    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  private

  def capture_docs_screenshot(slug, feature_set:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set:,
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def login_for_docs_capture
    capybara_login_as_platform_manager
    expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
  end

  def seed_release_uploads!
    create_image_upload('Aurora Banner', created_at: 3.days.ago)
    create_image_upload('Community Garden', created_at: 2.days.ago)
    create_image_upload('Welcome Poster', created_at: 1.day.ago)
  end

  def create_image_upload(name, created_at:)
    create(:better_together_upload, name:, creator:, created_at:).tap do |upload|
      upload.file.attach(
        io: StringIO.new(minimal_png_data),
        filename: "#{name.parameterize}.png",
        content_type: 'image/png'
      )
    end
  end

  def minimal_png_data
    # rubocop:disable Layout/LineLength
    "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\b\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82"
    # rubocop:enable Layout/LineLength
  end

  # rubocop:disable Metrics/AbcSize
  def capture_uploads_gallery
    slug = ENV.fetch('UPLOADS_GALLERY_SLUG', 'release_0_11_0_uploads_gallery')

    result = capture_docs_screenshot(slug, feature_set: 'release_0_11_0_uploads_gallery') do
      login_for_docs_capture
      visit better_together.file_index_path(locale: I18n.default_locale)

      expect(page).to have_field(type: 'search')
      expect(page).to have_text('Copy URL')
      expect(page).to have_text('Insert')
      expect(page).to have_text('Aurora Banner')
      expect(page).to have_text('Welcome Poster')
    end

    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  def capture_block_image_library
    slug = ENV.fetch('BLOCK_IMAGE_LIBRARY_SLUG', 'release_0_11_0_block_image_library')

    result = capture_docs_screenshot(slug, feature_set: 'release_0_11_0_block_image_library') do
      login_for_docs_capture
      visit better_together.new_content_block_path(
        locale: I18n.default_locale,
        block_type: 'BetterTogether::Content::Image'
      )

      click_button 'Choose from library'

      expect(page).to have_css('.modal.show', wait: 10)
      expect(page).to have_text('Choose from library')
      expect(page).to have_css('.modal.show img', minimum: 3)
    end

    expect(result[:desktop]).to end_with("docs/screenshots/desktop/#{slug}.png")
    expect(result[:mobile]).to end_with("docs/screenshots/mobile/#{slug}.png")
  end
  # rubocop:enable Metrics/AbcSize
end
