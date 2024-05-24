require 'rails_helper'

RSpec.describe 'geography/states/new', type: :view do
  before(:each) do
    assign(:geography_state, create(:state))
  end

  it 'renders new geography_state form' do
    # render

    # assert_select "form[action=?][method=?]", geography_states_path, "post" do
    # end
  end
end
