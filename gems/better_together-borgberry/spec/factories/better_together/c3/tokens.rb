# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/c3/token', class: 'BetterTogether::C3::Token',
                                      aliases: %i[c3_token] do
    association :earner, factory: :better_together_person
    contribution_type { :compute_cpu }
    contribution_type_name { 'compute_cpu' }
    sequence(:source_ref) { |n| "borgberry-task-#{n}" }
    source_system { 'borgberry' }
    c3_millitokens { 1_000 }
    status { 'pending' }

    trait :confirmed do
      status { 'confirmed' }
      confirmed_at { Time.current }
    end

    trait :with_fleet_node_earner do
      association :earner, factory: :better_together_fleet_node
    end

    trait :gpu_contribution do
      contribution_type { :compute_gpu }
      contribution_type_name { 'compute_gpu' }
    end
  end
end
