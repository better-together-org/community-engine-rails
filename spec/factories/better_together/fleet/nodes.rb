# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/fleet/node', class: 'BetterTogether::Fleet::Node',
                                        aliases: %i[better_together_fleet_node] do
    sequence(:node_id) { |n| "bts-#{n}" }
    node_category { 'cat1' }
    hardware { {} }
    compute { {} }
    services { {} }
    online { false }

    trait :online do
      online { true }
      last_seen_at { Time.current }
    end

    trait :with_cuda_gpu do
      hardware { { 'gpu_type' => 'cuda' } }
    end

    trait :with_metal_gpu do
      hardware { { 'gpu_type' => 'metal' } }
    end

    trait :cat2 do
      node_category { 'cat2' }
    end

    trait :tier1 do
      safety_tier { 'T1' }
    end
  end
end
