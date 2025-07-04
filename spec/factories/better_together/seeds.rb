# frozen_string_literal: true

FactoryBot.define do # rubocop:todo Metrics/BlockLength
  factory :better_together_seed, class: 'BetterTogether::Seed' do # rubocop:todo Metrics/BlockLength
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
  end
end
