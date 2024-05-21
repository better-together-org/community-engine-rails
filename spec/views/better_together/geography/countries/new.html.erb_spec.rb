require 'rails_helper'

RSpec.describe "geography/countries/new", type: :view do
  before(:each) do
    assign(:geography_country, Geography::Country.new())
  end

  it "renders new geography_country form" do
    render

    assert_select "form[action=?][method=?]", geography_countries_path, "post" do
    end
  end
end
