# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/membership_request',
          class: 'BetterTogether::Joatu::MembershipRequest',
          aliases: %i[better_together_joatu_membership_request membership_request] do
    id { SecureRandom.uuid }
    requestor_name { Faker::Name.name }
    requestor_email { Faker::Internet.unique.email }
    referral_source { 'friend' }
    status { 'open' }
    urgency { 'normal' }
    creator { nil }

    # Exchange concern requires name and description
    name { "Membership request from #{Faker::Name.name}" }
    description { Faker::Lorem.paragraph }

    # target must be a community
    association :target, factory: :better_together_community

    trait :with_creator do
      association :creator, factory: :better_together_person
      requestor_name { nil }
      requestor_email { nil }
    end
  end
end
