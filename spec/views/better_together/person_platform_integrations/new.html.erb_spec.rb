require 'rails_helper'

RSpec.describe "better_together/authorizations/new", type: :view do
  before(:each) do
    assign(:person_platform_integration, BetterTogether::PersonPlatformIntegration.new(
      provider: "MyString",
      uid: "MyString",
      token: "MyString",
      secret: "MyString",
      profile_url: "MyString",
      user: nil
    ))
  end

  it "renders new person_platform_integration form" do
    render

    assert_select "form[action=?][method=?]", person_platform_integrations_path, "post" do

      assert_select "input[name=?]", "person_platform_integration[provider]"

      assert_select "input[name=?]", "person_platform_integration[uid]"

      assert_select "input[name=?]", "person_platform_integration[token]"

      assert_select "input[name=?]", "person_platform_integration[secret]"

      assert_select "input[name=?]", "person_platform_integration[profile_url]"

      assert_select "input[name=?]", "person_platform_integration[user_id]"
    end
  end
end
