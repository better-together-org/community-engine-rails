require 'rails_helper'

RSpec.describe "geography/continents/index", type: :view do
  before(:each) do
    assign(:geography_continents, [
      Geography::Continent.create!(),
      Geography::Continent.create!()
    ])
  end

  it "renders a list of geography/continents" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
