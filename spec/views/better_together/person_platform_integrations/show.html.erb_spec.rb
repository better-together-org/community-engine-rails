require 'rails_helper'

RSpec.describe "better_together/authorizations/show", type: :view do
  before(:each) do
    assign(:person_platform_integration, BetterTogether::PersonPlatformIntegration.create!(
      provider: "Provider",
      uid: "Uid",
      token: "Token",
      secret: "Secret",
      profile_url: "Profile Url",
      user: nil
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Provider/)
    expect(rendered).to match(/Uid/)
    expect(rendered).to match(/Token/)
    expect(rendered).to match(/Secret/)
    expect(rendered).to match(/Profile Url/)
    expect(rendered).to match(//)
  end
end
