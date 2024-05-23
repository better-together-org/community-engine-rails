require 'rails_helper'

RSpec.describe "geography/regions/show", type: :view do
  before(:each) do
    assign(:geography_region, Geography::Region.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
