require 'rails_helper'

RSpec.describe "communities/edit", type: :view do
  let(:community) {
    Community.create!()
  }

  before(:each) do
    assign(:community, community)
  end

  it "renders the edit community form" do
    render

    assert_select "form[action=?][method=?]", community_path(community), "post" do
    end
  end
end
