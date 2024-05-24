# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'geography/region_settlements/edit', type: :view do
  let(:geography_region_settlement) do
    build(:region_settlement)
  end

  before(:each) do
    assign(:geography_region_settlement, geography_region_settlement)
  end

  it 'renders the edit geography_region_settlement form' do
    # render

    # assert_select "form[action=?][method=?]", geography_region_settlement_path(geography_region_settlement), "post" do
    # end
  end
end
