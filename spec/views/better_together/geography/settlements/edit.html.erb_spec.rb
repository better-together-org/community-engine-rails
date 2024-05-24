# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'geography/settlements/edit', type: :view do
  let(:geography_settlement) do
    build(:settlement)
  end

  before(:each) do
    assign(:geography_settlement, geography_settlement)
  end

  it 'renders the edit geography_settlement form' do
    # render

    # assert_select "form[action=?][method=?]", geography_settlement_path(geography_settlement), "post" do
    # end
  end
end
