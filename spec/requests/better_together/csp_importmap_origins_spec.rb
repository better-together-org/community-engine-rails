# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Content-Security-Policy script origins', :no_auth do
  it 'allows the origins of the importmap pins in script-src', :aggregate_failures do
    get better_together.home_page_path(locale: I18n.default_locale)

    script_src = response.headers['Content-Security-Policy'].to_s.split(';').map(&:strip).find { |d| d.start_with?('script-src') }

    expect(script_src).to include('https://cdn.jsdelivr.net', 'https://ga.jspm.io')
    expect(script_src).not_to include('unsafe-inline')
  end
end
