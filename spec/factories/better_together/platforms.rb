# frozen_string_literal: true

# spec/factories/platforms.rb

FactoryBot.define do
  factory :better_together_platform,
          class: 'BetterTogether::Platform',
          aliases: %i[platform] do
    id { SecureRandom.uuid }
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    identifier { name.parameterize }
    url { Faker::Internet.url }
    host { false }
    time_zone { Faker::Address.time_zone }
    privacy { BetterTogether::Platform::PRIVACY_LEVELS.keys.sample.to_s }
    # community # Assumes a factory for BetterTogether::Community exists

    trait :host do
      host { true }
    end
  end
end
