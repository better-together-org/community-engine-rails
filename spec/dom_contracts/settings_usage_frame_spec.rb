# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the settings Usage tab. The lazy frame in settings/index points at
# settings_usage_path, and Turbo shows "Content missing" unless the response carries the same frame id.
RSpec.describe 'Settings usage frame DOM contract', :as_user, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:doc) { Nokogiri::HTML(response.body) }

  it 'declares the lazy frame the settings page points at', :aggregate_failures do
    get better_together.settings_path(locale:)
    frame = Nokogiri::HTML(response.body).at_css('turbo-frame#usage-settings')
    expect(frame['src']).to eq(better_together.settings_usage_path(locale:))

    get better_together.settings_usage_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(doc.at_css('turbo-frame#usage-settings')).to be_present
    expect(doc.at_css('#usage-settings-none')).to be_present
  end
end
