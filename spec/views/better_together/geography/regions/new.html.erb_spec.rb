require 'rails_helper'

RSpec.describe 'geography/regions/new', type: :view do
  before(:each) do
    assign(:geography_region, create(:region))
  end

  it 'renders new geography_region form' do
    # render

    # assert_select "form[action=?][method=?]", geography_regions_path, "post" do
    # end
  end
end
