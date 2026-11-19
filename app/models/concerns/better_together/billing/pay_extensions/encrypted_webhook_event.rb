# frozen_string_literal: true

module BetterTogether
  module Billing
    module PayExtensions
      # Encrypts the raw processor event Pay keeps in `pay_webhooks.event`.
      #
      # Pay deletes a row once its event has been processed
      # (`Pay::Webhook#process!`), so only deliveries that failed or were never
      # processed linger; they are pruned by the billing maintenance job. Until then
      # the payload (customer e-mail, address, card brand and last four) must not sit
      # in the database in the clear.
      #
      # Pay reads `event` as a Hash (`event["data"]`, `Stripe::Event.construct_from`),
      # which the JSON attribute type preserves.
      module EncryptedWebhookEvent
        extend ActiveSupport::Concern

        included do
          include BetterTogether::Billing::EncryptedAttributes

          encrypts_billing_attribute :event, json: true
        end
      end
    end
  end
end
