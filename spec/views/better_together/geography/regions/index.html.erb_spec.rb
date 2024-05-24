require 'rails_helper'

RSpec.describe "geography/regions/index", type: :view do
  before(:each) do
    assign(:geography_regions, build_list(:region, 2))
  end

  it "renders a list of geography/regions" do
    # render
    # cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
