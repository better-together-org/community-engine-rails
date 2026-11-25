# frozen_string_literal: true

require 'rails_helper'

# Stable ids the theme sweep and the docs screenshots use to find the themed surfaces.
RSpec.describe 'Theme chrome DOM contract', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  let!(:platform) { configure_host_platform }
  let(:page_html) { Nokogiri::HTML(response.body) }

  it 'exposes the header, footer and locale switcher', :aggregate_failures do
    get better_together.home_page_path(locale: I18n.default_locale)

    %w[#main-nav #app-footer #locale-switcher].each do |selector|
      expect(page_html.css(selector).size).to eq(1), "expected exactly one #{selector}"
    end
  end
end
