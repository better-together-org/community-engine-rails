require 'rails_helper'

RSpec.describe "resource_permissions/index", type: :view do
  before(:each) do
    assign(:resource_permissions, [
      BetterTogether::ResourcePermission.create!(
        action: "Action",
        resource_class: "Resource Class"
      ),
      BetterTogether::ResourcePermission.create!(
        action: "Action",
        resource_class: "Resource Class"
      )
    ])
  end

  it "renders a list of resource_permissions" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    assert_select cell_selector, text: Regexp.new("Action".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Resource Class".to_s), count: 2
  end
end
