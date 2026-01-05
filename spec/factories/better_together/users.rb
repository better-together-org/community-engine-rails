# frozen_string_literal: true

require 'faker'

FactoryBot.define do
  factory(:better_together_user,
          class: BetterTogether::User,
          aliases: %i[user]) do
    id { Faker::Internet.uuid }
    email { Faker::Internet.unique.email }
    password { 'SecureTest123!@#' }

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

        # Use the platform_manager role from RBAC builder (which has all required permissions)
        platform_manager_role = BetterTogether::Role.find_by(identifier: 'platform_manager')

        # If role doesn't exist, run the RBAC builder to ensure proper setup
        unless platform_manager_role
          BetterTogether::AccessControlBuilder.new.build_all
          platform_manager_role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        end

        # Assign platform manager role to the user
        if platform_manager_role
          host_platform.person_platform_memberships.create!(
            member: user.person,
            role: platform_manager_role
          )
        end
      end
    end

    before :create do |instance|
      next if instance.person.present?

      person_attrs = attributes_for(:better_together_person)
      instance.build_person(person_attrs)
    end
  end
end
