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

    trait :oauth_user do
      # Create as OauthUser type (single-table inheritance)
      type { 'BetterTogether::OauthUser' }
      password { Devise.friendly_token[0, 20] }
    end

    trait :platform_steward do
      after(:create) do |user|
        host_platform = BetterTogether::Platform.find_by(host: true) ||
                        create(:better_together_platform, :host, community: user.person.community)

        platform_steward_role = BetterTogether::Role.find_by(identifier: 'platform_steward')

        unless platform_steward_role
          BetterTogether::AccessControlBuilder.seed_data
          platform_steward_role = BetterTogether::Role.find_by(identifier: 'platform_steward') ||
                                  BetterTogether::Role.find_by(identifier: 'platform_manager')
        end

        next unless platform_steward_role

        host_platform.person_platform_memberships.find_or_create_by!(
          member: user.person,
          role: platform_steward_role
        )
      end
    end

    trait :platform_manager do
      # Transitional alias: legacy specs should resolve to the canonical
      # platform-steward role when it exists.
      after(:create) do |user|
        platform_steward_role = BetterTogether::Role.find_by(identifier: 'platform_steward')
        host_platform = BetterTogether::Platform.find_by(host: true) ||
                        create(:better_together_platform, :host, community: user.person.community)

        unless platform_steward_role
          BetterTogether::AccessControlBuilder.seed_data
          platform_steward_role = BetterTogether::Role.find_by(identifier: 'platform_steward')
        end

        role = platform_steward_role || BetterTogether::Role.find_by(identifier: 'platform_manager')
        next unless role

        host_platform.person_platform_memberships.find_or_create_by!(
          member: user.person,
          role: role
        )
      end
    end

    before :create do |instance|
      next if instance.person.present?

      person_attrs = attributes_for(:better_together_person)
      instance.build_person(person_attrs)
    end
  end
end
