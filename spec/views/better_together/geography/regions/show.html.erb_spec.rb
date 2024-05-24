require 'rails_helper'

RSpec.describe 'geography/regions/show', type: :view do
  before(:each) do
    assign(:geography_region, create(:region))
  end

  it 'renders attributes in <p>' do
    # render
  end
end
