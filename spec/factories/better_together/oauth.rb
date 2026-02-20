# frozen_string_literal: true

require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_oauth_application,
            class: OauthApplication,
            aliases: %i[oauth_application] do
      name { "#{Faker::App.name} #{SecureRandom.hex(4)}" }
      redirect_uri { 'urn:ietf:wg:oauth:2.0:oob' }
      scopes { 'read' }
      confidential { true }

      association :owner, factory: :better_together_person

      trait :with_write_scope do
        scopes { 'read write' }
      end

      trait :with_mcp_scope do
        scopes { 'read mcp_access' }
      end

      trait :with_admin_scope do
        scopes { 'read write admin' }
      end

      trait :public_client do
        confidential { false }
        redirect_uri { 'https://example.com/callback' }
      end

      trait :with_callback do
        redirect_uri { 'https://example.com/oauth/callback' }
      end
    end

    factory :better_together_oauth_access_token,
            class: OauthAccessToken,
            aliases: %i[oauth_access_token] do
      token { SecureRandom.hex(32) }
      scopes { 'read' }
      expires_in { 7200 }

      association :application, factory: :better_together_oauth_application

      # Doorkeeper uses resource_owner_id as a plain column (not a belongs_to)
      transient do
        resource_owner { create(:better_together_user, :confirmed) }
      end

      after(:build) do |token, evaluator|
        token.resource_owner_id = evaluator.resource_owner&.id if evaluator.resource_owner
      end

      trait :expired do
        created_at { 3.hours.ago }
        expires_in { 7200 }
      end

      trait :revoked do
        revoked_at { 1.hour.ago }
      end

      trait :with_mcp_scope do
        scopes { 'read mcp_access' }
      end

      trait :with_write_scope do
        scopes { 'read write' }
      end

      trait :client_credentials do
        resource_owner { nil }
      end
    end

    factory :better_together_oauth_access_grant,
            class: OauthAccessGrant,
            aliases: %i[oauth_access_grant] do
      token { SecureRandom.hex(32) }
      expires_in { 600 }
      redirect_uri { 'https://example.com/callback' }
      scopes { 'read' }

      association :application, factory: :better_together_oauth_application

      # Doorkeeper uses resource_owner_id as a plain column (not a belongs_to)
      transient do
        resource_owner { create(:better_together_user, :confirmed) }
      end

      after(:build) do |grant, evaluator|
        grant.resource_owner_id = evaluator.resource_owner.id if evaluator.resource_owner
      end
    end
  end
end
