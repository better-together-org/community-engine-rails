# frozen_string_literal: true

# spec/factories/person_community_memberships.rb

FactoryBot.define do
  factory :better_together_person_community_membership,
          class: 'BetterTogether::PersonCommunityMembership',
          aliases: %i[person_community_membership] do
    bt_id { SecureRandom.uuid }
    association :community, factory: :better_together_community
    association :member, factory: :better_together_person
    association :role, factory: :better_together_role # Assuming a 'role' factory exists
  end
end
