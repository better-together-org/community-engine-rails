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

        # Ensure the platform_manager role exists with the correct resource_type
        platform_manager_role = BetterTogether::Role.find_or_create_by(
          identifier: 'platform_manager',
          resource_type: 'BetterTogether::Platform'
        ) do |role|
          role.name = 'Platform Manager'
          role.protected = true
          role.position = 0
        end

        # Ensure the role has the global manage_platform permission so policy checks pass in tests
        manage_perm = BetterTogether::ResourcePermission.find_or_create_by(
          identifier: 'manage_platform',
          resource_type: 'BetterTogether::Platform'
        ) do |perm|
          perm.action = 'manage'
          perm.target = 'platform'
          perm.protected = true
          perm.position = 6
        end
        unless platform_manager_role.resource_permissions.exists?(id: manage_perm.id)
          platform_manager_role.resource_permissions << manage_perm
        end

        host_platform.person_platform_memberships.create!(
          member: user.person,
          role: platform_manager_role
        )
      end
    end

    before :create do |instance|
      person_attrs = attributes_for(:better_together_person)
      instance.build_person(person_attrs)
    end
  end
end
