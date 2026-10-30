# frozen_string_literal: true

module BetterTogether
  module Billing
    module PayExtensions
      # Encrypts the JSON columns Pay fills from the processor (card brand and
      # last four, billing details, e-mail, raw objects) using the shared
      # BetterTogether::Billing::EncryptedAttributes macro.
      #
      # Pay reads these columns through `store_accessor` and plain attribute
      # readers, never raw JSON SQL, and `store_accessor` finds its accessor through
      # the attribute type at call time, so an encrypted JSON attribute behaves like
      # the original jsonb column.
      #
      # The tables are created with `text` columns for these attributes (see the
      # pay tables migration).
      module EncryptedBillingData
        extend ActiveSupport::Concern

        ENCRYPTED_COLUMNS = {
          'Pay::Customer' => %i[data object],
          'Pay::Merchant' => %i[data],
          'Pay::PaymentMethod' => %i[data],
          'Pay::Subscription' => %i[data object metadata],
          'Pay::Charge' => %i[data object metadata]
        }.freeze

        included do
          include BetterTogether::Billing::EncryptedAttributes

          ENCRYPTED_COLUMNS.fetch(name).each { |column| encrypts_billing_attribute(column, json: true) }
        end
      end
    end
  end
end
