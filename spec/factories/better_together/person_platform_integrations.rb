# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_person_platform_integration,
          class: 'BetterTogether::PersonPlatformIntegration',
          aliases: %i[person_platform_integration] do
    provider { 'MyString' }
    uid { 'MyString' }
    access_token { 'MyString' }
    access_token_secret { 'MyString' }
    profile_url { 'MyString' }
    user
    person { user.person }

    before :create do |instance|
      person { user.person }
    end
  end
end
