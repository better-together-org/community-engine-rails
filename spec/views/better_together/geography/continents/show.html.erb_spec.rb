require 'rails_helper'

RSpec.describe 'geography/continents/show', type: :view do
  before(:each) do
    assign(:geography_continent, create(:continent))
  end

  it 'renders attributes in <p>' do
    # render
  end
end
