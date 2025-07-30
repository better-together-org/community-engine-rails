# frozen_string_literal: true

require 'faker'

FactoryBot.define do
  factory(:better_together_user,
          class: BetterTogether::User,
          aliases: %i[user]) do
    id { Faker::Internet.uuid }
    email { Faker::Internet.unique.email }
    password { Faker::Internet.password(min_length: 12, max_length: 20) }

    after(:build) do |user|
      user.person = build(:better_together_person)
    end

    trait :confirmed do
      confirmed_at { Time.zone.now }
      confirmation_sent_at { Time.zone.now }
      confirmation_token { '12345' }
    end

    trait :platform_manager do
      after(:create) do |user|
        host_platform = BetterTogether::Platform.find_or_create_by(host: true)
        platform_manager_role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        host_platform.person_platform_memberships.create!(
          member: user.person,
          role: platform_manager_role
        )
      end
    end
  end
end
