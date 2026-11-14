# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the theme fields in the platform form Appearance tab.
RSpec.describe 'Platform theme fields DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:edit_path) { better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug) }

  it 'renders a field per token plus font, radius and image fields inside the Appearance pane' do # rubocop:disable RSpec/MultipleExpectations
    get edit_path
    doc = parsed_response

    BetterTogether::PlatformThemeConfig::KEYS.each do |key|
      expect(doc.at_css("#platform-appearance [name='platform[theme][#{key}]']#platform_theme_#{key}"))
        .to be_present, "missing theme field #{key}"
    end
    %w[logo header_banner favicon].each do |field|
      id = ActionView::RecordIdentifier.dom_id(host_platform, field)
      expect(doc.at_css("#platform-appearance input[type=file]##{id}")).to be_present, "missing #{field}"
    end
    expect(doc.at_css('form[enctype="multipart/form-data"]')).to be_present
  end

  it 'renders the contrast rows, preset and reset controls with stable ids' do
    get edit_path
    doc = parsed_response

    ids = %w[platform-theme-settings platform-theme-colors platform-theme-contrast platform-theme-reset
             platform-theme-picker platform-theme-apply platform-theme-clear platform-theme-status
             platform-theme-preview platform-theme-preview-navbar platform-theme-preview-card
             platform-theme-preview-alert platform-theme-preview-footer]
    ids += BetterTogether::PlatformThemeConfig::CONTRAST_PAIRS.map do |fg, bg, _|
      "platform-theme-contrast-#{fg}-#{bg.dasherize}"
    end
    ids.each { |id| expect(doc.at_css("##{id}")).to be_present, "missing ##{id}" }
  end

  it 'shows an AA warning server-side for a low-contrast saved pair' do
    host_platform.update!(theme: { 'primary' => '#ee722a', 'primary_text' => '#ffffff' })
    get edit_path

    expect(parsed_response.at_css('#platform-theme-contrast-primary_text-primary').text).to include('Below AA')
  end

  it 'offers the five built-in themes in a slim-select dropdown with their tokens' do # rubocop:disable RSpec/MultipleExpectations
    get edit_path
    select = parsed_response.at_css('select#platform_theme_picker')

    expect(select['data-controller']).to include('better_together--slim-select')
    options = select.css('option[data-tokens]')
    expect(options.map { |o| o['value'] }).to match_array(BetterTogether::PlatformThemeConfig.themes.keys)
    expect(JSON.parse(options.first['data-tokens'])).to include('primary')
  end

  it 'renders an inert, labelled preview with every themed element and a polite status line' do # rubocop:disable RSpec/MultipleExpectations
    get edit_path
    doc = parsed_response

    expect(doc.at_css('section#platform-theme-preview')['aria-label']).to be_present
    expect(doc.at_css('#platform-theme-preview .bts-preview[inert]')).to be_present
    %w[.bts-nav .bts-btn-primary .bts-btn-secondary .bts-card .bts-input .bts-alert .bts-badge .bts-footer a].each do |selector|
      expect(doc.at_css("#platform-theme-preview #{selector}")).to be_present, "preview lacks #{selector}"
    end
    expect(doc.at_css('#platform-theme-status')['aria-live']).to eq('polite')
    expect(doc.at_css('#platform-theme-apply')['style']).to include('min-height:44px')
  end
end
