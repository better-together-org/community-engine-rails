# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'geography/settlements/show', type: :view do
  before(:each) do
    assign(:geography_settlement, create(:settlement))
  end

  it 'renders attributes in <p>' do
    # render
  end
end
