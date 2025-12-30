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

    # Create or find external OAuth platform based on provider
    platform do
      BetterTogether::Platform.external.find_or_create_by(
        identifier: provider,
        host: false,
        external: true
      ) do |p|
        p.name = BetterTogether::PersonPlatformIntegration::PROVIDERS[provider.to_sym] || provider.titleize
        p.url = case provider
                when 'github' then 'https://github.com'
                when 'facebook' then 'https://facebook.com'
                when 'google_oauth2' then 'https://google.com'
                when 'linkedin' then 'https://linkedin.com'
                else "https://#{provider}.com"
                end
        p.privacy = 'public'
      end
    end

    before :create do |instance|
      instance.person = instance.user&.person if instance.user&.person.present?
    end

    trait :github do
      provider { 'github' }
      profile_url { "https://github.com/#{handle}" }
      platform do
        BetterTogether::Platform.external.find_or_create_by(
          identifier: 'github',
          host: false,
          external: true
        ) do |p|
          p.name = 'GitHub'
          p.url = 'https://github.com'
          p.privacy = 'public'
        end
      end
    end

    trait :facebook do
      provider { 'facebook' }
      profile_url { "https://facebook.com/#{handle}" }
      platform do
        BetterTogether::Platform.external.find_or_create_by(
          identifier: 'facebook',
          host: false,
          external: true
        ) do |p|
          p.name = 'Facebook'
          p.url = 'https://facebook.com'
          p.privacy = 'public'
        end
      end
    end

    trait :google do
      provider { 'google_oauth2' }
      profile_url { "https://plus.google.com/#{uid}" }
      platform do
        BetterTogether::Platform.external.find_or_create_by(
          identifier: 'google',
          host: false,
          external: true
        ) do |p|
          p.name = 'Google'
          p.url = 'https://google.com'
          p.privacy = 'public'
        end
      end
    end

    trait :linkedin do
      provider { 'linkedin' }
      profile_url { "https://linkedin.com/in/#{handle}" }
      platform do
        BetterTogether::Platform.external.find_or_create_by(
          identifier: 'linkedin',
          host: false,
          external: true
        ) do |p|
          p.name = 'LinkedIn'
          p.url = 'https://linkedin.com'
          p.privacy = 'public'
        end
      end
    end

    trait :expired do
      expires_at { 1.hour.ago }
    end

    trait :without_expiration do
      expires_at { nil }
    end
  end
end
