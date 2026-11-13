# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform page content fields DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  it 'renders a textarea per key and locale inside the Appearance pane' do
    get better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)
    doc = parsed_response

    expect(doc.at_css('#platform-appearance #platform-page-content-settings')).to be_present
    BetterTogether::PlatformContentConfig::KEYS.each do |key|
      I18n.available_locales.each do |locale|
        selector = "textarea#platform_page_content_#{key}_#{locale}[name='platform[page_content][#{key}][#{locale}]']"
        expect(doc.at_css(selector)).to be_present, "missing #{selector}"
      end
    end
  end
end
