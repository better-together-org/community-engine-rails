require 'rails_helper'

RSpec.describe "resource_permissions/edit", type: :view do
  let(:resource_permission) {
    BetterTogether::ResourcePermission.create!(
      action: "MyString",
      resource_class: "MyString"
    )
  }

  before(:each) do
    assign(:resource_permission, resource_permission)
  end

  it "renders the edit resource_permission form" do
    render

    assert_select "form[action=?][method=?]", resource_permission_path(resource_permission), "post" do

      assert_select "input[name=?]", "resource_permission[action]"

      assert_select "input[name=?]", "resource_permission[resource_class]"
    end
  end
end
