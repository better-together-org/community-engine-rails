require 'rails_helper'

RSpec.describe "resource_permissions/show", type: :view do
  before(:each) do
    assign(:resource_permission, BetterTogether::ResourcePermission.create!(
      action: "Action",
      resource_class: "Resource Class"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Action/)
    expect(rendered).to match(/Resource Class/)
  end
end
