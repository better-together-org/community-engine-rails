# frozen_string_literal: true

require 'rails_helper'

# The export button on each metrics chart keeps a stable id that styling, tests and screenshots rely on.
RSpec.describe 'Metrics chart toolbar DOM', type: :request do # rubocop:disable RSpec/DescribeClass
  let(:manager) { find_or_create_test_user("chart-toolbar-dom-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }

  before { sign_in manager }

  it 'gives each chart an export button id', :aggregate_failures do
    get "/#{I18n.default_locale}/host/metrics/reports"
    page = Nokogiri::HTML(response.body)

    %w[chart-page-views-by-page chart-daily-page-views].each do |id|
      expect(page.at_css("##{id} button.dropdown-toggle[id$='-export']")).to be_present, "missing export button in ##{id}"
    end
    expect(page.at_css('#page-views-chart-export')).to be_present
  end
end
