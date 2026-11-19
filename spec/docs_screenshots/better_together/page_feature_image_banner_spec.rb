# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the page feature image banner', # rubocop:disable RSpec/SpecFilePathSuffix
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
  let(:with_feature) do
    create(:better_together_page, title: 'Harbour history', slug: 'harbour-history', identifier: 'harbour-history',
                                  platform: host_platform, protected: false, privacy: 'public', published_at: 1.day.ago,
                                  feature_image_data: photo, feature_image_filename: 'harbour.jpg')
  end
  let(:with_hero) do
    create(:better_together_page, title: 'Harbour hero', slug: 'harbour-hero', identifier: 'harbour-hero',
                                  platform: host_platform, protected: false, privacy: 'public', published_at: 1.day.ago)
  end
  let(:callouts) do
    [{ id: 'feature_banner', selector: '#page-feature-image-title', title: 'Banner title',
       bullets: ['The page title sits on the feature image.', 'Pages that open with a hero use the hero heading.'] }]
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    with_feature.page_blocks.create!(block: create(:content_markdown, markdown_source: '## Why the harbour matters'), position: 0)
    with_hero.page_blocks.create!(block: create(:content_hero, title: 'Harbour hero heading', subtitle: 'Opening block'), position: 0)
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'anonymous', feature_set: 'page_feature_image_banner', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def show_page(record, selector)
    visit better_together.render_page_path(path: record.slug, locale: I18n.default_locale)
    expect(page).to have_css(selector, wait: 10)
    find(selector).scroll_to(:top)
    sleep 0.5
  end

  it 'captures the banner with annotations' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'page_feature_image_banner', device: :both, metadata: metadata('page_feature_image_banner'), callouts:,
                                   narrative: { title: 'Page feature image banner', audience: %w[member content_editor],
                                                journey_step: 'As a reader, I see the page picture with its title.',
                                                callouts: [{ id: 'feature_banner', title: 'Banner title',
                                                             description: 'The title is the single h1 of the page.' }],
                                                accessibility_notes: 'The image is decorative; the heading names the page.' }
    ) do
      show_page(with_feature, '#page-feature-image-title')
      expect(page).to have_css('#page-feature-image-title h1.page-title')
    end
  end

  it 'captures the plain banner' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'page_feature_image_banner_plain', device: :both, metadata: metadata('page_feature_image_banner_plain')
    ) do
      show_page(with_feature, '#page-feature-image')
      expect(page).to have_css('#page-feature-image img')
    end
  end

  it 'captures a page that opens with a hero block' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'page_hero_first_block', device: :both, metadata: metadata('page_hero_first_block')
    ) do
      show_page(with_hero, '.hero-heading')
      expect(page).to have_no_css('h1.page-title')
    end
  end

  it 'has no accessibility violations on the banner' do
    show_page(with_feature, '#page-feature-image')

    expect(page).to be_axe_clean.within('main').according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end
end
