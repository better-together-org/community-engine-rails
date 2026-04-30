# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NoExpectationExample
RSpec.describe 'Documentation screenshots for built-in static pages', :docs_screenshot, :js, retry: 0, type: :feature do
  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    configure_host_platform
  end

  it 'captures the Better Together seed page' do
    capture_static_page(
      slug: 'better-together',
      screenshot_name: 'seed_better_together',
      expected_text: 'Better Together'
    )
  end

  it 'captures the Community Engine seed page' do
    capture_static_page(
      slug: 'better-together/community-engine',
      screenshot_name: 'seed_community_engine',
      expected_text: 'Community Engine'
    )
  end

  it 'captures the FAQ page' do
    capture_static_page(
      slug: 'faq',
      screenshot_name: 'seed_faq',
      expected_text: 'Frequently Asked Questions'
    )
  end

  it 'captures the privacy policy page' do
    capture_static_page(
      slug: 'privacy-policy',
      screenshot_name: 'seed_privacy_policy',
      expected_text: 'Privacy Information'
    )
  end

  it 'captures the cookie policy page' do
    capture_static_page(
      slug: 'cookie-policy',
      screenshot_name: 'seed_cookie_policy',
      expected_text: 'Cookie Policy'
    )
  end

  it 'captures the subprocessors page' do
    capture_static_page(
      slug: 'subprocessors',
      screenshot_name: 'seed_subprocessors',
      expected_text: 'Subprocessors'
    )
  end

  it 'captures the terms of service page' do
    capture_static_page(
      slug: 'terms-of-service',
      screenshot_name: 'seed_terms_of_service',
      expected_text: 'Terms of Service'
    )
  end

  it 'captures the code of conduct page' do
    capture_static_page(
      slug: 'code-of-conduct',
      screenshot_name: 'seed_code_of_conduct',
      expected_text: 'Code of Conduct'
    )
  end

  it 'captures the accessibility page' do
    capture_static_page(
      slug: 'accessibility',
      screenshot_name: 'seed_accessibility',
      expected_text: 'Accessibility Statement'
    )
  end

  it 'captures the code contributor agreement page' do
    capture_static_page(
      slug: 'code-contributor-agreement',
      screenshot_name: 'seed_code_contributor_agreement',
      expected_text: 'Contributor License Agreement'
    )
  end

  it 'captures the content contributor agreement page' do
    capture_static_page(
      slug: 'content-contributor-agreement',
      screenshot_name: 'seed_content_contributor_agreement',
      expected_text: 'Content Contributor Agreement'
    )
  end

  private

  # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
  def capture_static_page(slug:, screenshot_name:, expected_text:)
    result = BetterTogether::CapybaraScreenshotEngine.capture(
      screenshot_name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'public',
        source_spec: self.class.metadata[:file_path],
        page_slug: slug
      }
    ) do
      visit better_together.render_page_path(slug, locale: I18n.default_locale)

      expect(page).to have_text(expected_text, wait: 10)
    end

    expect(result[:desktop]).to include("/docs/screenshots/desktop/#{screenshot_name}.png")
    expect(result[:mobile]).to include("/docs/screenshots/mobile/#{screenshot_name}.png")
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
# rubocop:enable RSpec/NoExpectationExample
