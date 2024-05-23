require 'rails_helper'

RSpec.describe "geography/settlements/new", type: :view do
  before(:each) do
    assign(:geography_settlement, Geography::Settlement.new())
  end

  it "renders new geography_settlement form" do
    render

    assert_select "form[action=?][method=?]", geography_settlements_path, "post" do
    end
  end
end
