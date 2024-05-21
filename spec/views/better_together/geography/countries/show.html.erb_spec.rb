require 'rails_helper'

RSpec.describe "geography/countries/show", type: :view do
  before(:each) do
    assign(:geography_country, Geography::Country.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
