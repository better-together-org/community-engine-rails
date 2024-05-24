require 'rails_helper'

RSpec.describe "geography/states/index", type: :view do
  before(:each) do
    assign(:geography_states, build_list(:state, 2))
  end

  it "renders a list of geography/states" do
    # render
    # cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
