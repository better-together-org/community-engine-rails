# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'geography/states/edit', type: :view do
  let(:geography_state) do
    build(:state)
  end

  before(:each) do
    assign(:geography_state, geography_state)
  end

  it 'renders the edit geography_state form' do
    # render

    # assert_select "form[action=?][method=?]", geography_state_path(geography_state), "post" do
    # end
  end
end
