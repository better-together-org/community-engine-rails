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

    # Use after(:create) to set community after the page is saved
    # This ensures the host community exists and the association is persisted
    after(:create) do |page|
      if page.community_id.blank?
        host_community = BetterTogether::Community.find_by(host: true)
        page.update_column(:community_id, host_community&.id) if host_community
      end
    end

    trait :with_community do
      # This trait is now a no-op since the model auto-assigns the host community
      # Kept for backward compatibility with existing tests
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
