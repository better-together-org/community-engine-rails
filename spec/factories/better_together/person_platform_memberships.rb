# frozen_string_literal: true

# spec/factories/person_platform_memberships.rb

FactoryBot.define do
  factory :better_together_person_platform_membership,
          class: 'BetterTogether::PersonPlatformMembership',
          aliases: %i[person_platform_membership] do
    id { SecureRandom.uuid }
    association :joinable, factory: :better_together_platform
    association :member, factory: :better_together_person
    association :role, factory: :better_together_role
  end
end
