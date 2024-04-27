require 'rails_helper'

RSpec.describe "platforms/new", type: :view do
  before(:each) do
    assign(:platform, Platform.new())
  end

  it "renders new platform form" do
    render

    assert_select "form[action=?][method=?]", platforms_path, "post" do
    end
  end
end
