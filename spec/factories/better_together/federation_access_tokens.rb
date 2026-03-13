# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/federation_access_token',
          class: 'BetterTogether::FederationAccessToken',
          aliases: %i[better_together_federation_access_token federation_access_token] do
    association :platform_connection, factory: :better_together_platform_connection
    scopes { 'content.feed.read' }
    expires_at { 15.minutes.from_now }
  end
end
