require 'rails_helper'

RSpec.describe "platforms/edit", type: :view do
  let(:platform) {
    Platform.create!()
  }

  before(:each) do
    assign(:platform, platform)
  end

  it "renders the edit platform form" do
    render

    assert_select "form[action=?][method=?]", platform_path(platform), "post" do
    end
  end
end
