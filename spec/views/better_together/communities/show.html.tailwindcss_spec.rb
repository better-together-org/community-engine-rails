require 'rails_helper'

RSpec.describe "communities/show", type: :view do
  before(:each) do
    assign(:community, Community.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
