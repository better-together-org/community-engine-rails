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
             platform-theme-preset-foray]
    ids += BetterTogether::PlatformThemeConfig::CONTRAST_PAIRS.map { |fg, _| "platform-theme-contrast-#{fg}" }
    ids.each { |id| expect(doc.at_css("##{id}")).to be_present, "missing ##{id}" }
  end

  it 'shows an AA warning server-side for a low-contrast saved pair' do
    host_platform.update!(theme: { 'primary' => '#ee722a', 'primary_text' => '#ffffff' })
    get edit_path

    expect(parsed_response.at_css('#platform-theme-contrast-primary_text').text).to include('Below AA')
  end
end
