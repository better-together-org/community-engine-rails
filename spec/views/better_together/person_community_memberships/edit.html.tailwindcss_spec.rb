require 'rails_helper'

RSpec.describe "person_community_memberships/edit", type: :view do
  let(:person_community_membership) {
    PersonCommunityMembership.create!()
  }

  before(:each) do
    assign(:person_community_membership, person_community_membership)
  end

  it "renders the edit person_community_membership form" do
    render

    assert_select "form[action=?][method=?]", person_community_membership_path(person_community_membership), "post" do
    end
  end
end
