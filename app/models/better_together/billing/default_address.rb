# frozen_string_literal: true

module BetterTogether
  module Billing
    # The address a person uses by default when buying on a platform: one for billing, one for shipping.
    # Kept apart from Address#primary_flag, which stays the person's general primary address.
    #
    # The address must be one of the person's own, so a default can never point at someone else's.
    class DefaultAddress < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_default_addresses'

      KINDS = %w[billing shipping].freeze

      belongs_to :person, class_name: 'BetterTogether::Person'
      belongs_to :address, class_name: 'BetterTogether::Address'

      validates :kind, inclusion: { in: KINDS }
      validates :kind, uniqueness: { scope: %i[platform_id person_id] }
      validate :address_is_the_persons

      KINDS.each do |kind|
        scope kind, -> { where(kind:) }
      end

      # Makes `address` the person's default `kind` address on `platform`, replacing the one before it.
      def self.set!(platform:, person:, address:, kind:)
        record = find_or_initialize_by(platform:, person:, kind:)
        record.update!(address:)
        record
      end

      private

      def address_is_the_persons
        return if address.nil? || person.nil?

        errors.add(:address, :invalid) unless address.contact_detail&.contactable == person
      end
    end
  end
end
