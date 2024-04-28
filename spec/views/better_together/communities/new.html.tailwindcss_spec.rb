require 'rails_helper'

RSpec.describe "communities/new", type: :view do
  before(:each) do
    assign(:community, Community.new())
  end

  it "renders new community form" do
    render

    assert_select "form[action=?][method=?]", communities_path, "post" do
    end
  end
end
