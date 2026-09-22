# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_seed, class: 'BetterTogether::Seed' do
    id { SecureRandom.uuid }
    version { '1.0' }
    created_by { 'Better Together Solutions' }
    seeded_at { Time.current }
    description { 'This is a generic seed for testing purposes.' }

    origin do
      {
        'contributors' => [
          { 'name' => 'Test Contributor', 'role' => 'Tester', 'contact' => 'test@example.com',
            'organization' => 'Test Org' }
        ],
        'platforms' => [
          { 'name' => 'Community Engine', 'version' => '1.0', 'url' => 'https://bebettertogether.ca' }
        ],
        'license' => 'LGPLv3',
        'usage_notes' => 'This seed is for test purposes only.'
      }
    end

    payload do
      {
        version: '1.0',
        generic_data: {
          name: 'Generic Seed',
          description: 'This is a placeholder seed.'
        }
      }
    end

    # Seed owned by a specific person via creator_id.
    # Usage: create(:better_together_seed, :created_by_person, creator: some_person)
    trait :created_by_person do
      transient do
        creator { create(:better_together_person) }
      end
      creator_id { creator.id }
    end

    # Seed representing a personal data export (seedable = a Person).
    # Usage: create(:better_together_seed, :owned_as_seedable, person: some_person)
    trait :owned_as_seedable do
      transient do
        person { create(:better_together_person) }
      end
      seedable_type { 'BetterTogether::Person' }
      seedable_id { person.id }
    end

    trait :personal_export do
      transient do
        person { create(:better_together_person) }
      end
      creator_id { person.id }
      seedable_type { 'BetterTogether::Person' }
      seedable_id { person.id }
    end
  end
end
