# frozen_string_literal: true

# spec/factories/pages.rb

FactoryBot.define do
  factory :better_together_page,
          class: 'BetterTogether::Page',
          aliases: %i[page] do
    id { SecureRandom.uuid }
    title { Faker::Lorem.unique.sentence(word_count: 3) }
    content { Faker::Lorem.paragraph }
    meta_description { Faker::Lorem.sentence }
    keywords { Faker::Lorem.words(number: 4).join(', ') }
    published_at { Faker::Date.backward(days: 30) }
    privacy { 'public' } # Default to public so tests work for non-managers
    protected { Faker::Boolean.boolean }
    show_title { true }
    platform do
      Current.platform&.internal? ? Current.platform : create(:better_together_platform)
    end
    community { platform.primary_community }

    trait :with_community do
      community { platform.primary_community }
    end

    trait :published_public do
      published_at { Faker::Date.backward(days: 30) }
      privacy { 'public' }
    end

    trait :unpublished do
      published_at { nil }
    end

    trait :private do
      privacy { 'private' }
    end
  end
end
