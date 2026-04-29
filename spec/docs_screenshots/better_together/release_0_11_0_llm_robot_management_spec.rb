# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Documentation screenshots for platform LLM robot management',
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let!(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let!(:host_platform) { configure_host_platform }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
  end

  after do
    Current.platform = nil
  end

  it 'captures the platform profile with translation readiness enabled' do
    translation_robot = create(:robot,
                               platform: host_platform,
                               identifier: 'translation',
                               name: 'Host Translation Robot',
                               robot_type: 'translation',
                               provider: 'openai',
                               default_model: 'gpt-4o-mini-2024-07-18')

    allow(BetterTogether).to receive(:openai_credentials_present?).and_return(true)
    allow(BetterTogether).to receive(:translation_available?).with(platform: host_platform).and_return(true)
    allow(BetterTogether::Robot).to receive(:resolve)
      .with(identifier: 'translation', platform: host_platform)
      .and_return(translation_robot)

    result = capture_docs_screenshot('release_0_11_0_llm_robot_platform_ready', flow: 'platform_ready') do
      capybara_login_as_platform_manager
      visit better_together.platform_path(host_platform, locale: I18n.default_locale)

      expect(page).to have_text('Manage LLM robots')
      expect(page).to have_text('Configured')
      expect(page).to have_text('Ready')
      expect(page).to have_text('Shown')
      expect(page).to have_text('Host Translation Robot')
      scroll_to_text!('OPENAI CREDENTIALS')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/release_0_11_0_llm_robot_platform_ready.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/release_0_11_0_llm_robot_platform_ready.png')
  end

  it 'captures the robot index with fallback and platform override rows' do
    create(:robot,
           :global,
           identifier: 'translation',
           name: 'Global Translation Robot',
           robot_type: 'translation',
           provider: 'openai',
           default_model: 'gpt-4o-mini-2024-07-18')
    create(:robot,
           platform: host_platform,
           identifier: 'assistant',
           name: 'Platform Assistant Robot',
           robot_type: 'assistant',
           provider: 'ollama',
           settings: { assume_model_exists: true })

    allow(BetterTogether).to receive(:openai_credentials_present?).and_return(true)
    allow(BetterTogether).to receive(:translation_available?).with(platform: host_platform).and_return(true)

    result = capture_docs_screenshot('release_0_11_0_llm_robot_management_index', flow: 'robot_index') do
      capybara_login_as_platform_manager
      visit better_together.platform_robots_path(host_platform, locale: I18n.default_locale)

      expect(page).to have_text(host_platform.name)
      expect(page).to have_text('Global Translation Robot')
      expect(page).to have_text('Platform Assistant Robot')
      expect(page).to have_text('Global fallback')
      expect(page).to have_text('Platform override')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/release_0_11_0_llm_robot_management_index.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/release_0_11_0_llm_robot_management_index.png')
  end

  it 'captures the robot form for a platform translation override' do
    translation_robot = create(:robot,
                               platform: host_platform,
                               identifier: 'translation',
                               name: 'Platform Translation Override',
                               robot_type: 'translation',
                               provider: 'openai',
                               settings: { assume_model_exists: true },
                               system_prompt: 'Translate with concise language.')

    result = capture_docs_screenshot('release_0_11_0_llm_robot_management_form', flow: 'robot_form') do
      capybara_login_as_platform_manager
      visit better_together.edit_platform_robot_path(host_platform, translation_robot, locale: I18n.default_locale)

      expect(page).to have_field('robot[name]', with: 'Platform Translation Override')
      expect(page).to have_field('robot[identifier]', with: 'translation')
      expect(page).to have_select('robot[provider]', selected: 'openai')
      expect(page).to have_checked_field('robot_settings_assume_model_exists')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/release_0_11_0_llm_robot_management_form.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/release_0_11_0_llm_robot_management_form.png')
  end

  it 'captures the platform profile with translation readiness unavailable' do
    translation_robot = create(:robot,
                               platform: host_platform,
                               identifier: 'translation',
                               name: 'Offline Translation Robot',
                               robot_type: 'translation',
                               provider: 'openai')

    allow(BetterTogether).to receive(:openai_credentials_present?).and_return(false)
    allow(BetterTogether).to receive(:translation_available?).with(platform: host_platform).and_return(false)
    allow(BetterTogether::Robot).to receive(:resolve)
      .with(identifier: 'translation', platform: host_platform)
      .and_return(translation_robot)

    result = capture_docs_screenshot('release_0_11_0_llm_robot_platform_unavailable', flow: 'platform_unavailable') do
      capybara_login_as_platform_manager
      visit better_together.platform_path(host_platform, locale: I18n.default_locale)

      expect(page).to have_text('Missing')
      expect(page).to have_text('Unavailable')
      expect(page).to have_text('Hidden')
      expect(page).to have_text('Offline Translation Robot')
      scroll_to_text!('OPENAI CREDENTIALS')
    end

    expect(result[:desktop]).to end_with('docs/screenshots/desktop/release_0_11_0_llm_robot_platform_unavailable.png')
    expect(result[:mobile]).to end_with('docs/screenshots/mobile/release_0_11_0_llm_robot_platform_unavailable.png')
  end

  private

  def capture_docs_screenshot(name, flow:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name,
      device: :both,
      metadata: {
        locale: I18n.default_locale,
        role: 'platform_manager',
        feature_set: 'release_0_11_0_llm_robot_management',
        flow:,
        source_spec: self.class.metadata[:file_path]
      },
      &
    )
  end

  def scroll_to_text!(text)
    element = find('*', text:, exact_text: true, wait: 10)
    page.execute_script('arguments[0].scrollIntoView({ block: "start", behavior: "instant" });', element.native)
    expect(element).to be_visible
  end
end
