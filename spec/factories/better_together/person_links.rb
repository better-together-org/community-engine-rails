# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/person_link',
          class: 'BetterTogether::PersonLink',
          aliases: %i[better_together_person_link person_link] do
    platform_connection { association(:better_together_platform_connection, :active, strategy: :create) }
    source_person { association(:better_together_person, strategy: :create) }
    target_person { association(:better_together_person, strategy: :create) }
    status { 'active' }
    remote_target_identifier { target_person.identifier }
    remote_target_name { target_person.name }
    verified_at { Time.current }

    after(:build) do |person_link|
      source_platform = person_link.platform_connection.source_platform
      target_platform = person_link.platform_connection.target_platform

      source_platform.person_platform_memberships.find_or_create_by!(member: person_link.source_person) do |membership|
        membership.role = create(:better_together_role)
        membership.status = 'active'
      end

      next unless person_link.target_person

      target_platform.person_platform_memberships.find_or_create_by!(member: person_link.target_person) do |membership|
        membership.role = create(:better_together_role)
        membership.status = 'active'
      end
    end

    trait :pending do
      status { 'pending' }
      verified_at { nil }
    end
  end
end
