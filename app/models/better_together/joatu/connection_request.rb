# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request subtype used to propose a platform-to-platform connection.
    class ConnectionRequest < Request
      validates :target_type, inclusion: { in: ['BetterTogether::Platform'] }
      validate :target_platform_must_exist

      def after_agreement_acceptance!(offer:)
        source_platform = source_platform_from_offer(offer)
        target_platform = target

        unless source_platform && target_platform
          errors.add(:base, :missing_platforms_for_connection_agreement)
          raise ActiveRecord::RecordInvalid, self
        end

        connection = ::BetterTogether::PlatformConnection.find_or_initialize_by(
          source_platform:,
          target_platform:
        )
        connection.status = :active
        connection.connection_kind ||= :peer
        connection.save!
      end

      def source_platform_from_offer(offer)
        offer.target if offer.target.is_a?(::BetterTogether::Platform)
      end

      private

      def target_platform_must_exist
        return if target.is_a?(::BetterTogether::Platform)

        errors.add(:target, 'must be a platform')
      end
    end
  end
end
