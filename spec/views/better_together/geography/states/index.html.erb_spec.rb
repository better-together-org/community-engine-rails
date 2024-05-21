require 'rails_helper'

RSpec.describe "geography/states/index", type: :view do
  before(:each) do
    assign(:geography_states, [
      Geography::State.create!(),
      Geography::State.create!()
    ])
  end

  it "renders a list of geography/states" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
