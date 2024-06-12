require 'rails_helper'

RSpec.describe "better_together/authorizations/index", type: :view do
  before(:each) do
    assign(:person_platform_integrations, [
      BetterTogether::PersonPlatformIntegration.create!(
        provider: "Provider",
        uid: "Uid",
        token: "Token",
        secret: "Secret",
        profile_url: "Profile Url",
        user: nil
      ),
      BetterTogether::PersonPlatformIntegration.create!(
        provider: "Provider",
        uid: "Uid",
        token: "Token",
        secret: "Secret",
        profile_url: "Profile Url",
        user: nil
      )
    ])
  end

  it "renders a list of better_together/authorizations" do
    render
    cell_selector = Rails::VERSION::STRING >= '7' ? 'div>p' : 'tr>td'
    assert_select cell_selector, text: Regexp.new("Provider".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Uid".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Token".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Secret".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Profile Url".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
  end
end
