require 'rails_helper'

RSpec.describe "person_community_memberships/index", type: :view do
  before(:each) do
    assign(:person_community_memberships, [
      PersonCommunityMembership.create!(),
      PersonCommunityMembership.create!()
    ])
  end

  it "renders a list of person_community_memberships" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
  end
end
