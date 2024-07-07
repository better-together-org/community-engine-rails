# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'geography/countries/index', type: :view do
  before(:each) do
    assign(:geography_countries, build_list(:country, 2))
  end

  it 'renders a list of geography/countries' do
    # render
    # cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
