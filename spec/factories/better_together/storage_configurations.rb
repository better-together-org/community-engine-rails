# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/storage_configuration',
          class: 'BetterTogether::StorageConfiguration',
          aliases: %i[better_together_storage_configuration storage_configuration] do
    association :platform, factory: :better_together_platform
    name { 'Default Local Storage' }
    service_type { 'local' }

    trait :amazon do
      name { 'Amazon S3' }
      service_type { 'amazon' }
      bucket { 'my-test-bucket' }
      region { 'us-east-1' }
      access_key_id { 'AKIAIOSFODNN7EXAMPLE' }
      secret_access_key { 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' }
    end

    trait :s3_compatible do
      name { 'Garage S3-Compatible' }
      service_type { 's3_compatible' }
      bucket { 'ce-bucket' }
      region { 'us-east-1' }
      endpoint { 'http://garage.example.test:3900' }
      access_key_id { 'GKtest123456789' }
      secret_access_key { 'supersecretkey0987654321abcdef' }
    end
  end
end
