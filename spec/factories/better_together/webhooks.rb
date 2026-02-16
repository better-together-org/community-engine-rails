# frozen_string_literal: true

require 'faker'

module BetterTogether
  FactoryBot.define do
    factory :better_together_webhook_endpoint,
            class: WebhookEndpoint,
            aliases: %i[webhook_endpoint] do
      name { "#{Faker::App.name} Webhook" }
      url { "https://#{Faker::Internet.domain_name}/webhooks/receive" }
      secret { SecureRandom.hex(32) }
      active { true }
      events { [] }

      association :person, factory: :better_together_person

      trait :inactive do
        active { false }
      end

      trait :with_events do
        events { %w[community.created community.updated post.created] }
      end

      trait :with_oauth_app do
        association :oauth_application, factory: :better_together_oauth_application
      end

      trait :for_all_events do
        events { [] }
      end
    end

    factory :better_together_webhook_delivery,
            class: WebhookDelivery,
            aliases: %i[webhook_delivery] do
      event { 'community.created' }
      payload do
        {
          event: 'community.created',
          timestamp: Time.current.iso8601,
          data: {
            id: SecureRandom.uuid,
            type: 'BetterTogether::Community',
            attributes: { name: Faker::Company.name }
          }
        }
      end
      status { 'pending' }
      attempts { 0 }

      association :webhook_endpoint, factory: :better_together_webhook_endpoint

      trait :delivered do
        status { 'delivered' }
        response_code { 200 }
        response_body { '{"status":"ok"}' }
        delivered_at { Time.current }
        attempts { 1 }
      end

      trait :failed do
        status { 'failed' }
        response_code { 500 }
        response_body { 'Internal Server Error' }
        attempts { 3 }
      end

      trait :retrying do
        status { 'retrying' }
        attempts { 1 }
      end
    end
  end
end
