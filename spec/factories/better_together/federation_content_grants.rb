# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/federation_content_grant', class: 'BetterTogether::FederationContentGrant',
                                                      aliases: %i[better_together_federation_content_grant] do
    association :federatable, factory: :better_together_post
    association :platform_connection, factory: :better_together_platform_connection
    status { 'allowed' }

    trait :denied do
      status { 'denied' }
    end
  end
end
