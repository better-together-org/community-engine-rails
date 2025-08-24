# frozen_string_literal: true

# spec/factories/platforms.rb

FactoryBot.define do
  factory 'better_together/platform',
          class: 'BetterTogether::Platform',
          aliases: %i[better_together_platform platform] do
    id { SecureRandom.uuid }
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    identifier { Faker::Internet.unique.username(specifier: 10..20) }
    url { Faker::Internet.url }
    host { false }
    time_zone { Faker::Address.time_zone }
    privacy { 'private' }
    external { false }
    # community # Assumes a factory for BetterTogether::Community exists

    trait :host do
      host { true }
      protected { true }
    end

    trait :external do
      external { true }
      host { false }
    end

    trait :oauth_provider do
      external { true }
      host { false }
      name { %w[GitHub Facebook Google Twitter].sample }
      url { "https://#{name.downcase}.com" }
    end

    trait :public do
      privacy { 'public' }
    end
  end
end
