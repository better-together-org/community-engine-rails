# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationHelper, 'user theme and colour mode' do # rubocop:disable RSpec/SpecFilePathFormat, RSpec/DescribeMethod
  let(:cfg) { BetterTogether::PlatformThemeConfig }
  let(:platform) { build(:better_together_platform) }
  let(:alice) { build_stubbed(:better_together_person, preferences: { 'theme' => 'warm', 'color_mode' => 'dark' }) }
  let(:bob) { build_stubbed(:better_together_person, preferences: {}) }

  after { cfg.reset_registered_themes! }

  def as_person(person)
    allow(helper).to receive(:safe_current_person).and_return(person)
  end

  it 'renders each person only their own theme and mode (no shared state between requests)' do # rubocop:disable RSpec/MultipleExpectations
    as_person(alice)
    alice_css = helper.user_theme_css(platform)
    alice_attrs = helper.html_color_mode_attributes(platform)

    as_person(bob)
    expect(helper.user_theme_css(platform)).to be_nil
    expect(helper.html_color_mode_attributes(platform)).not_to include('data-bts-user-theme', 'data-bts-user-mode')

    as_person(alice)
    expect(helper.user_theme_css(platform)).to eq(alice_css)
    expect(alice_attrs).to include('data-bts-user-theme' => 'warm', 'data-bts-user-mode' => 'dark', 'data-bs-theme' => 'dark')
  end

  it 'renders nothing for an anonymous visitor' do
    as_person(nil)

    expect(helper.user_theme_style_tag(platform)).to be_nil
    expect(helper.user_theme_id(platform)).to be_nil
    expect(helper.user_color_mode).to be_nil
  end

  it 'ignores the theme when the platform disallows personal themes but keeps the colour mode' do # rubocop:disable RSpec/MultipleExpectations
    platform.allow_user_themes = false
    as_person(alice)

    expect(helper.user_theme_id(platform)).to be_nil
    expect(helper.user_color_mode).to eq('dark')
  end

  it 'ignores a stored theme that is no longer in the registry' do
    cfg.register_theme('acme_gone', cfg.builtin_themes['neutral'].except('dark'))
    as_person(build_stubbed(:better_together_person, preferences: { 'theme' => 'acme_gone' }))
    cfg.reset_registered_themes!

    expect(helper.user_theme_id(platform)).to be_nil
  end

  it 'builds a stylesheet with dark tokens for a registered theme' do
    cfg.register_theme('acme_forest', cfg.builtin_themes['neutral'].except('dark').merge('primary' => '#0b3d2e'))
    as_person(build_stubbed(:better_together_person, preferences: { 'theme' => 'acme_forest' }))

    expect(helper.user_theme_css(platform)).to include('--bts-primary: #0b3d2e;', '[data-bs-theme="dark"]')
  end

  it 'mirrors the stored mode into storage in the head script for signed-in people' do
    as_person(alice)

    expect(helper.color_mode_head_script_tag(platform)).to include('data-bts-user-mode', "localStorage.setItem('bts-color-mode'")
  end
end
