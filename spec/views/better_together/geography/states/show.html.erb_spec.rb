require 'rails_helper'

RSpec.describe "geography/states/show", type: :view do
  before(:each) do
    assign(:geography_state, Geography::State.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
