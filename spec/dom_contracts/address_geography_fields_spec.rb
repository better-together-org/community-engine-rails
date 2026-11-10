# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the cascading country / state / settlement selects of the address form (rendered here
# through the event form's inline new-address panel). The Stimulus controller, feature specs and docs
# screenshots target these identifiers.
RSpec.describe 'Address geography fields DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  def decoded_body
    CGI.unescapeHTML(response.body)
  end

  it 'renders a select, id field and string field for each level' do # rubocop:disable RSpec/MultipleExpectations
    get "/#{I18n.default_locale}/events/new"

    body = decoded_body
    expect(body).to include('data-controller="better_together--address-geography"')
    %w[country state settlement].each do |level|
      expect(body).to include("data-better_together--address-geography-target=\"#{level}Select\"")
      expect(body).to include("data-better_together--address-geography-target=\"#{level}Id\"")
      expect(body).to include("data-better_together--address-geography-target=\"#{level}Name\"")
      expect(body).to include("_#{level}_select\"")
    end
    expect(body).to match(/name="[^"]*\[country_id\]"/)
  end

  it 'narrows states by the country select and settlements by both' do
    get "/#{I18n.default_locale}/events/new"

    options = CGI.unescapeHTML(response.body.scan(/data-better_together--slim-select-options-value="([^"]+)"/).join)
    expect(options).to include('level=state').and include('level=settlement')
    expect(options).to include('dependsOn')
  end
end
