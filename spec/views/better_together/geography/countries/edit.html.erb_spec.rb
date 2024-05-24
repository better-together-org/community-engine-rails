require 'rails_helper'

RSpec.describe 'geography/countries/edit', type: :view do
  let(:geography_country) do
    build(:country)
  end

  before(:each) do
    assign(:geography_country, geography_country)
  end

  it 'renders the edit geography_country form' do
    # render

    # assert_select "form[action=?][method=?]", geography_country_path(geography_country), "post" do
    # end
  end
end
