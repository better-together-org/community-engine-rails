# frozen_string_literal: true

module BetterTogether
  module Billing
    # The one place that declares an encrypted billing attribute, so the rules from
    # the Rails Active Record Encryption guide are applied the same way everywhere.
    #
    #   encrypts_billing_attribute :payload, json: true, default: -> { {} }
    #   encrypts_billing_attribute :error_message
    #
    # * Non-deterministic: billing data is never looked up by ciphertext.
    # * `json: true` declares the JSON attribute type BEFORE `encrypts` (the guide
    #   warns the order matters) and needs a `text` column: an encrypted value is
    #   not a JSON document, so a json/jsonb column cannot hold it.
    # * `support_unencrypted_data: false` per attribute, so the test environment's
    #   global `support_unencrypted_data = true` cannot hide a missing `encrypts`
    #   and a plaintext value is never silently accepted.
    # * No database default and no column limit: a stored value equal to the
    #   column default is returned undecrypted, and a limit adds a plaintext length
    #   validation that is wrong for ciphertext. Both are rejected when the schema
    #   loads.
    module EncryptedAttributes
      extend ActiveSupport::Concern

      class ColumnError < StandardError; end

      included do
        class_attribute :encrypted_billing_attributes, instance_writer: false, default: []
      end

      class_methods do
        def encrypts_billing_attribute(name, json: false, default: nil, **)
          name = name.to_sym
          attribute(name, :json, **{ default: }.compact) if json
          encrypts(name, support_unencrypted_data: false, **)
          self.encrypted_billing_attributes = (encrypted_billing_attributes + [name]).uniq
        end

        # Runs when the model's schema loads (first use), never at class-load time,
        # so booting without a database (asset precompile, db:create) still works.
        def load_schema!
          super
          verify_encrypted_billing_columns!
        end

        def verify_encrypted_billing_columns!
          encrypted_billing_attributes.each do |name|
            column = columns_hash[name.to_s]
            problems = column ? EncryptedAttributes.column_problems(column) : []
            next if problems.empty?

            raise ColumnError, "#{self.name}##{name} is encrypted but its column #{problems.join(' and ')}"
          end
        end
      end

      # What is wrong with a column that is meant to hold ciphertext, as phrases.
      def self.column_problems(column)
        [
          ('has a database default' unless column.default.nil?),
          ("has a limit of #{column.limit}" unless column.limit.nil?),
          ("is #{column.type}, not text" unless column.type == :text)
        ].compact
      end
    end
  end
end
