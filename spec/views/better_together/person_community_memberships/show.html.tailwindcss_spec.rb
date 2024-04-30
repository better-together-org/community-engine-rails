require 'rails_helper'

RSpec.describe "person_community_memberships/show", type: :view do
  before(:each) do
    assign(:person_community_membership, PersonCommunityMembership.create!())
  end

  it "renders attributes in <p>" do
    render
  end
end
