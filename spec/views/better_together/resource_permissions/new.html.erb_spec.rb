require 'rails_helper'

RSpec.describe "resource_permissions/new", type: :view do
  before(:each) do
    assign(:resource_permission, BetterTogether::ResourcePermission.new(
      action: "MyString",
      resource_class: "MyString"
    ))
  end

  it "renders new resource_permission form" do
    render

    assert_select "form[action=?][method=?]", resource_permissions_path, "post" do

      assert_select "input[name=?]", "resource_permission[action]"

      assert_select "input[name=?]", "resource_permission[resource_class]"
    end
  end
end
