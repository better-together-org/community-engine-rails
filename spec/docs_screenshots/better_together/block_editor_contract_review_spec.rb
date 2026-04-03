# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for block editor contract review',
               :docs_screenshot, :js, :skip_host_setup, retry: 0, type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:checklist) { create(:better_together_checklist, title: 'PR 1490 Documentation Checklist') }
  let!(:hero_page) do
    create(
      :better_together_page,
      title: 'PR 1490 Hero Docs Page',
      slug: 'pr-1490-hero-docs-page',
      identifier: 'pr-1490-hero-docs-page',
      protected: false,
      published_at: 1.day.ago
    )
  end
  let!(:hero_block) do
    create(
      :content_hero,
      title: 'PR 1490 Hero Heading',
      subtitle: 'PR 1490 Hero paragraph',
      heading_color: '#ff6600',
      paragraph_color: '#336699',
      cta_text: 'Learn more',
      cta_url: 'https://example.test/learn-more'
    )
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = configure_host_platform
    hero_page.page_blocks.find_or_create_by!(block: hero_block) do |page_block|
      page_block.position = 0
    end
  end

  after do
    Current.platform = nil
  end

  it 'captures checklist and hero block evidence for PR review' do
    capture_checklist_form if ENV['CAPTURE_CHECKLIST_FORM'] == '1'
    capture_hero_form if ENV['CAPTURE_HERO_FORM'] == '1'
    capture_hero_render if ENV['CAPTURE_HERO_RENDER'] == '1'
    expect(ENV.fetch('RUN_DOCS_SCREENSHOTS', nil)).to eq('1')
  end

  private

  def capture_docs_screenshot(slug, flow:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      slug,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'block_editor_contract_review',
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def login_for_docs_capture
    capybara_login_as_platform_manager
    expect(page).to have_no_current_path(new_user_session_path(locale: I18n.default_locale), wait: 10)
  end

  def capture_checklist_form
    slug = ENV.fetch('CHECKLIST_FORM_SLUG', 'pr_1490_checklist_form_after')
    expect_fields = ENV['EXPECT_CHECKLIST_FIELDS'] == '1'
    expect_runtime_error = ENV['EXPECT_CHECKLIST_RUNTIME_ERROR'] == '1'

    capture_docs_screenshot(slug, flow: 'checklist_block_editor') do
      login_for_docs_capture
      visit_checklist_editor
      assert_checklist_page_state(expect_runtime_error:, expect_fields:)
    end
  end

  def capture_hero_form
    slug = ENV.fetch('HERO_FORM_SLUG', 'pr_1490_hero_form_after')
    expect_color_fields = ENV['EXPECT_HERO_COLOR_FIELDS'] == '1'

    capture_docs_screenshot(slug, flow: 'hero_block_editor') do
      login_for_docs_capture
      visit_hero_editor
      assert_hero_form_state(expect_color_fields)
    end
  end

  def capture_hero_render
    slug = ENV.fetch('HERO_RENDER_SLUG', 'pr_1490_hero_render_after')
    expect_custom_colors = ENV['EXPECT_HERO_RENDER_COLORS'] == '1'

    capture_docs_screenshot(slug, flow: 'hero_block_render') do
      login_for_docs_capture
      visit better_together.page_path(hero_page.slug, locale: I18n.default_locale)

      assert_hero_render_state(expect_custom_colors)
    end
  end

  def visit_checklist_editor
    visit better_together.new_content_block_path(
      locale: I18n.default_locale,
      block_type: 'BetterTogether::Content::ChecklistBlock'
    )
  end

  def assert_checklist_page_state(expect_runtime_error:, expect_fields:)
    return expect(page).to have_text('Puma caught this error') if expect_runtime_error

    expect(page).to have_text(expect_fields ? 'Checklist' : 'New Block: checklist_block - new')
    assert_checklist_fields if expect_fields
  end

  def assert_checklist_fields
    expect(page).to have_css('[name="block[display_style]"]', visible: :all)
    expect(page).to have_css('[name="block[item_limit]"]', visible: :all)
    expect(page).to have_css('[name="block[checklist_id]"]', visible: :all)
    expect(page).to have_css(
      '[name="block[checklist_id]"] option',
      text: 'PR 1490 Documentation Checklist',
      visible: :all
    )
  end

  def visit_hero_editor
    visit better_together.new_content_block_path(
      locale: I18n.default_locale,
      block_type: 'BetterTogether::Content::Hero'
    )
  end

  def assert_hero_form_state(expect_color_fields)
    expect(page).to have_css('.hero-fields', wait: 10)
    expect(page).to have_text('CTA Button')
    assert_text_visibility('Heading Color', expect_color_fields)
    assert_text_visibility('Paragraph Color', expect_color_fields)
  end

  def assert_hero_render_state(expect_custom_colors)
    expect(page).to have_text('PR 1490 Hero Heading')
    expect(page).to have_text('PR 1490 Hero paragraph')
    assert_css_visibility('.hero-heading[style*="color: #ff6600"]', expect_custom_colors)
    assert_css_visibility('.hero-paragraph[style*="color: #336699"]', expect_custom_colors)
  end

  def assert_text_visibility(text, present)
    matcher = present ? :have_text : :have_no_text
    expect(page).to public_send(matcher, text)
  end

  def assert_css_visibility(selector, present)
    matcher = present ? :have_css : :have_no_css
    expect(page).to public_send(matcher, selector)
  end
end
