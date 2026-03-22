# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/joatu/request', class: 'BetterTogether::Joatu::Request',
                                           aliases: %i[better_together_joatu_request joatu_request request] do
    id { SecureRandom.uuid }
    name { Faker::Commerce.material }
    description { Faker::Lorem.paragraph }
    creator { association :better_together_person }
    status { 'open' }
    urgency { 'normal' }

    trait :with_target do
      target { association :better_together_person }
    end

    trait :with_target_type do
      target_type { 'BetterTogether::Invitation' }
    end

    # Ensure a persisted category and in-memory association are set before validation
    after(:build) do |request|
      next unless request.categories.blank? && request.categorizations.blank?

      category = create(:better_together_joatu_category)
      request.categories << category
    end

    factory 'better_together/joatu/connection_request',
            class: 'BetterTogether::Joatu::ConnectionRequest',
            aliases: %i[better_together_joatu_connection_request joatu_connection_request connection_request] do
      target { association :better_together_platform }
      type { 'BetterTogether::Joatu::ConnectionRequest' }
    end

    factory 'better_together/joatu/person_link_request',
            class: 'BetterTogether::Joatu::PersonLinkRequest',
            aliases: %i[better_together_joatu_person_link_request joatu_person_link_request person_link_request] do
      target { association :better_together_person }
      type { 'BetterTogether::Joatu::PersonLinkRequest' }
    end

    factory 'better_together/joatu/person_access_grant_request',
            class: 'BetterTogether::Joatu::PersonAccessGrantRequest',
            aliases: %i[better_together_joatu_person_access_grant_request joatu_person_access_grant_request person_access_grant_request] do
      target { association :better_together_person }
      type { 'BetterTogether::Joatu::PersonAccessGrantRequest' }
    end
  end
end
