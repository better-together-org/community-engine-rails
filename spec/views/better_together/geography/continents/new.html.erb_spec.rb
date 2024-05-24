require 'rails_helper'

RSpec.describe "geography/continents/new", type: :view do
  before(:each) do
    assign(:geography_continent, create(:continent))
  end

  it "renders new geography_continent form" do
    # render

    # assert_select "form[action=?][method=?]", geography_continents_path, "post" do
    # end
  end
end
