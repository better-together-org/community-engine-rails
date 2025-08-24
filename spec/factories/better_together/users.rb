# frozen_string_literal: true

require 'faker'

FactoryBot.define do
  factory(:better_together_user,
          class: BetterTogether::User,
          aliases: %i[user]) do
    id { Faker::Internet.uuid }
    email { Faker::Internet.unique.email }
    password { Faker::Internet.password(min_length: 12, max_length: 20) }

    person

    trait :confirmed do
      confirmed_at { Time.zone.now }
      confirmation_sent_at { Time.zone.now }
      confirmation_token { Faker::Alphanumeric.alphanumeric(number: 20) }
    end

    trait :platform_manager do
      after(:create) do |user|
        # Ensure there's a host platform with a valid community for the manager
        host_platform = BetterTogether::Platform.find_by(host: true) ||
                        create(:better_together_platform, :host, community: user.person.community)
        platform_manager_role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        host_platform.person_platform_memberships.create!(
          member: user.person,
          role: platform_manager_role
        )
      end
    end

    before :create do |user|
      user.build_person_identification(
        agent: user,
        identity: create(:person)
      )
    end
  end
end
