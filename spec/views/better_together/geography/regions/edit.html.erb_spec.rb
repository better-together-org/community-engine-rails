# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'geography/regions/edit', type: :view do
  let(:geography_region) do
    build(:region)
  end

  before(:each) do
    assign(:geography_region, geography_region)
  end

  it 'renders the edit geography_region form' do
    # render

    # assert_select "form[action=?][method=?]", geography_region_path(geography_region), "post" do
    # end
  end
end
