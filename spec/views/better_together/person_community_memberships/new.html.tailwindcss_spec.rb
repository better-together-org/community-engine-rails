require 'rails_helper'

RSpec.describe "person_community_memberships/new", type: :view do
  before(:each) do
    assign(:person_community_membership, PersonCommunityMembership.new())
  end

  it "renders new person_community_membership form" do
    render

    assert_select "form[action=?][method=?]", person_community_memberships_path, "post" do
    end
  end
end
