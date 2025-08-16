# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hub/index.html.erb', type: :view do
  it 'renders the page title' do
    assign(:activities, [])
    render

    expect(rendered).to include('Community Hub')
  end
end
