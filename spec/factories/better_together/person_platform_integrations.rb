FactoryBot.define do
  factory :person_platform_integration, class: 'BetterTogether::PersonPlatformIntegration' do
    provider { "MyString" }
    uid { "MyString" }
    token { "MyString" }
    secret { "MyString" }
    profile_url { "MyString" }
    user { nil }
  end
end
