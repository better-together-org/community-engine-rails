require 'rails_helper'

RSpec.describe "geography/region_settlements/index", type: :view do
  before(:each) do
    assign(:geography_region_settlements, build_list(:region_settlement, 3))
  end

  it "renders a list of geography/region_settlements" do
    # render
    # cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
