require 'rails_helper'

RSpec.describe "geography/region_settlements/show", type: :view do
  before(:each) do
    assign(:geography_region_settlement, Geography::RegionSettlement.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
