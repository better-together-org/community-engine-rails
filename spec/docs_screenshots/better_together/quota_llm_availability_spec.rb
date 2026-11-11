# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for LLM usage token availability',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:locale) { I18n.default_locale }
  let(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    BetterTogether::Robot.update_all(active: false) # rubocop:disable Rails/SkipsModelValidations
    Current.platform = host_platform
  end

  after { Current.platform = nil }

  it 'captures the defaults form without the LLM token block when no AI provider is configured' do
    allow(RubyLLM.config).to receive(:openai_api_key).and_return(nil)

    result = capture_docs_screenshot(
      'platform_quota_defaults_no_ai_provider',
      flow: 'platform_edit_no_ai_provider',
      callouts: [
        { selector: "##{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults)}",
          title: 'No AI provider', bullets: ['LLM token quotas stay hidden.'] }
      ]
    ) do
      capybara_login_as_platform_manager
      visit edit_platform_path(host_platform, locale:)

      find("##{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults)}").scroll_to(:center)
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults_media_storage)}")
      expect(page).to have_no_css("##{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults_ai_translation_tokens)}")
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/platform_quota_defaults_no_ai_provider.png')
  end

  it 'captures the grants overview with the generalized LLM usage tokens label' do
    allow(RubyLLM.config).to receive(:openai_api_key).and_return('sk-docs-screenshot')
    person = create(:better_together_person, name: 'Sample Member')
    storage = BetterTogether::Quota.create!(owner: person, quota_type: 'media_storage', limit: 262_144_000,
                                            period: 'cumulative')
    tokens = BetterTogether::Quota.create!(owner: person, quota_type: 'ai_translation_tokens', limit: 50_000,
                                           period: 'monthly')

    result = capture_docs_screenshot(
      'quota_grants_llm_usage_tokens',
      flow: 'quota_grants_overview',
      callouts: [
        { selector: "##{ActionView::RecordIdentifier.dom_id(tokens)}", title: 'LLM usage tokens',
          bullets: ['Shown because an AI provider is set up.'] }
      ]
    ) do
      capybara_login_as_platform_manager
      visit better_together.platform_quota_grants_path(host_platform, locale:)

      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(storage)}")
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(tokens)}", text: 'AI LLM usage tokens')
      find("##{ActionView::RecordIdentifier.dom_id(tokens)}").scroll_to(:center)
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/quota_grants_llm_usage_tokens.png')
  end

  private

  def capture_docs_screenshot(name, flow:, callouts: [], &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale, role: 'platform_manager', feature_set: 'quota_llm_availability',
        flow:, source_spec: self.class.metadata[:file_path]
      },
      callouts:,
      &
    )
  end
end
