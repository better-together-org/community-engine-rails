# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the page feature image', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:photo) { Base64.strict_encode64(Rails.root.join('../../app/assets/images/cover_images/default_cover_image_community.jpg').binread) }
  let(:page_record) do
    create(:better_together_page, title: 'Harbour history', slug: 'harbour-history', identifier: 'harbour-history',
                                  platform: host_platform, protected: false, privacy: 'public', published_at: 1.day.ago,
                                  feature_image_data: photo, feature_image_filename: 'harbour.jpg')
  end
  let(:callouts) do
    [{ id: 'feature_image_field', selector: '#feature-image-fields', title: 'Feature image',
       bullets: ['Shown at the top of the page.', 'Also the picture used when the page is shared.'] }]
  end
  let(:narrative) do
    {
      title: 'Page feature image',
      audience: %w[content_editor developer],
      journey_step: 'As an editor, I choose one picture that represents the page.',
      callouts: [{ id: 'feature_image_field', title: 'Feature image',
                   description: 'Replaces the hero block background as the share picture; Clear removes it.' }],
      accessibility_notes: 'The file input is labelled; the preview is announced with the page title as alt text.'
    }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    page_record
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'page_feature_image', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def open_form
    capybara_login_as_platform_manager
    visit better_together.edit_page_path(page_record.slug, locale: I18n.default_locale)
    expect(page).to have_css('#feature-image-fields #feature-image-input, #feature-image-fields .preview-target img',
                             minimum: 2, wait: 10)
    find('#feature-image-fields').scroll_to(:center)
    sleep 0.5
  end

  it 'captures the feature image field with annotations' do
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      'page_feature_image_form', device: :both, metadata: metadata('page_feature_image_form'), callouts:, narrative:
    ) { open_form }

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/page_feature_image_form.png')
  end

  it 'captures the plain feature image field' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'page_feature_image_form_plain', device: :both, metadata: metadata('page_feature_image_form_plain')
    ) { open_form }

    expect(page).to have_css('#feature-image-fields')
  end

  it 'has no accessibility violations in the form' do
    open_form

    expect(page).to be_axe_clean.within('#feature-image-fields').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
