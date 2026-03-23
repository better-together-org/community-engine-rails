# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_person_platform_integration,
          class: 'BetterTogether::PersonPlatformIntegration',
          aliases: %i[person_platform_integration] do
    provider { 'github' }
    uid { Faker::Number.number(digits: 8).to_s }
    access_token { Faker::Crypto.sha256 }
    access_token_secret { Faker::Crypto.sha256 }
    handle { Faker::Internet.username }
    name { Faker::Name.name }
    profile_url { Faker::Internet.url }
    expires_at { 1.hour.from_now }
    user
    person { user&.person }
    platform # Let the spec provide the platform explicitly

    before :create do |instance|
      instance.person = instance.user&.person if instance.user&.person.present?
    end

    trait :github do
      provider { 'github' }
      profile_url { "https://github.com/#{handle}" }
    end

    trait :facebook do
      provider { 'facebook' }
      profile_url { "https://facebook.com/#{handle}" }
    end

    trait :google do
      provider { 'google_oauth2' }
      profile_url { "https://plus.google.com/#{uid}" }
    end

    trait :linkedin do
      provider { 'linkedin' }
      profile_url { "https://linkedin.com/in/#{handle}" }
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :without_expiration do
      expires_at { nil }
    end
  end
end
