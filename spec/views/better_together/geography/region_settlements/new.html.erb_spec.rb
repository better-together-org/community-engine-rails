require 'rails_helper'

RSpec.describe "geography/region_settlements/new", type: :view do
  before(:each) do
    assign(:geography_region_settlement, Geography::RegionSettlement.new())
  end

  it "renders new geography_region_settlement form" do
    render

    assert_select "form[action=?][method=?]", geography_region_settlements_path, "post" do
    end
  end
end
