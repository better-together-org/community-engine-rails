require 'rails_helper'

RSpec.describe "geography/continents/edit", type: :view do
  let(:geography_continent) {
   build(:continent)
  }

  before(:each) do
    assign(:geography_continent, geography_continent)
  end

  it "renders the edit geography_continent form" do
    # render

    # assert_select "form[action=?][method=?]", geography_continent_path(geography_continent), "post" do
    # end
  end
end
