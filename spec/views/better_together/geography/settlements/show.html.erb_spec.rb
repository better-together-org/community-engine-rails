require 'rails_helper'

RSpec.describe "geography/settlements/show", type: :view do
  before(:each) do
    assign(:geography_settlement, Geography::Settlement.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
