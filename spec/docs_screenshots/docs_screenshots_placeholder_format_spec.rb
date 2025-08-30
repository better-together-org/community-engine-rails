# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Docs screenshots: docs/screenshots/PLACEHOLDER_FORMAT.md', type: :feature do
  include Capybara::DSL

  it 'docs_screenshots_placeholder_format - desktop', :docs_screenshot, screenshot_name: 'docs_screenshots_placeholder_format' do
    BetterTogether::CapybaraScreenshotEngine.capture('docs_screenshots_placeholder_format', device: :desktop) do
      visit '/' # TODO: update to target path for this screenshot
    end
  end

  it 'docs_screenshots_placeholder_format - mobile', :docs_screenshot, screenshot_name: 'docs_screenshots_placeholder_format' do
    BetterTogether::CapybaraScreenshotEngine.capture('docs_screenshots_placeholder_format', device: :mobile) do
      visit '/' # TODO: update to target path for this screenshot
    end
  end
end
