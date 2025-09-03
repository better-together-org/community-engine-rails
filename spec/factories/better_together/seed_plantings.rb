# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_seed_planting, class: 'BetterTogether::SeedPlanting' do
    id { SecureRandom.uuid }
    association :creator, factory: :better_together_person
    association :seed, factory: :better_together_seed, strategy: :build
    
    status { 'pending' }
    planting_type { 'seed' }
    privacy { 'public' }
    
    metadata do
      {
        'source' => 'test',
        'import_options' => {
          'validate' => true,
          'track_progress' => true
        }
      }
    end

    trait :processing do
      status { 'in_progress' }
      started_at { 1.hour.ago }
    end

    trait :completed do
      status { 'completed' }
      started_at { 2.hours.ago }
      completed_at { 1.hour.ago }
    end

    trait :failed do
      status { 'failed' }
      started_at { 2.hours.ago }
      completed_at { 1.hour.ago }
      error_message { 'Test error occurred during processing' }
    end

    trait :with_seed do
      association :seed, factory: :better_together_seed
    end

    trait :with_metadata do
      metadata do
        {
          'file_info' => {
            'name' => 'test_seed.yml',
            'size' => 1024,
            'checksum' => 'abc123def456'
          },
          'import_options' => {
            'validate' => true,
            'track_progress' => true,
            'create_missing' => false
          },
          'timing' => {
            'started_at' => Time.current.iso8601,
            'estimated_duration' => 300
          }
        }
      end
    end
  end
end
